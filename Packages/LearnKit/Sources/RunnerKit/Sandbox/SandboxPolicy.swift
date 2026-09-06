public import Foundation
private import os

/// 격리가 한 단계 내려간 이유.
///
/// 이 타입이 존재하는 이유는 하나다 — **강등을 조용히 하지 않기 위해서.**
/// `sandbox-exec` 가 없거나 프로파일이 거부되면 실행은 계속되지만(런처 단독 격리),
/// 그 사실이 값으로 남고 로그로 나가야 한다. 격리가 약해진 걸 아무도 모르는 상태가
/// 격리가 없는 것보다 나쁘다.
public enum SandboxDegradationReason: Hashable, Sendable {
    /// `/usr/bin/sandbox-exec` 가 없거나 실행할 수 없다.
    case executableMissing(path: String)
    /// 환경변수로 껐다. 디버깅·CI 용 스위치.
    case disabledByEnvironment(key: String, value: String)
    /// `sandbox-exec` 가 프로파일을 컴파일하지 못했다 (EX_DATAERR = 65).
    case profileRejected(exitCode: Int32, message: String)
    /// 프로파일 조립 자체가 실패했다 — 경로 해석 불가 등.
    case profileUnbuildable(message: String)
    /// 검증 프로브가 예상 밖으로 실패했다 (타임아웃, 실행 실패).
    case probeFailed(message: String)
}

public struct SandboxDegradation: Hashable, Sendable, CustomStringConvertible {
    public var reason: SandboxDegradationReason

    public init(_ reason: SandboxDegradationReason) {
        self.reason = reason
    }

    /// 사람이 읽을 한 줄. UI 배지와 로그가 같은 문장을 쓴다.
    public var korean: String {
        switch reason {
        case let .executableMissing(path):
            "sandbox-exec 를 찾을 수 없어(\(path)) 런처 단독 격리로 강등했다."
        case let .disabledByEnvironment(key, value):
            "\(key)=\(value) 로 샌드박스를 껐다 — 런처 단독 격리로 동작한다."
        case let .profileRejected(exitCode, message):
            "sandbox-exec 가 프로파일을 거부해(종료코드 \(exitCode)) 런처 단독 격리로 강등했다: \(message)"
        case let .profileUnbuildable(message):
            "샌드박스 프로파일을 만들 수 없어 런처 단독 격리로 강등했다: \(message)"
        case let .probeFailed(message):
            "샌드박스 검증 프로브가 실패해 런처 단독 격리로 강등했다: \(message)"
        }
    }

    public var description: String { korean }

    /// 강등 상태에서도 **여전히 유효한** 격리. 사용자에게 "무방비"라고 말하지 않기 위해.
    public var remainingIsolation: String {
        "프로세스 그룹 분리(setsid) · CPU/프로세스수/파일크기 rlimit · 벽시계 killpg · 메모리 폴링"
    }
}

/// 이번 실행에 적용할 격리.
public enum SandboxDecision: Hashable, Sendable {
    case enforced(SandboxProfile)
    case degraded(SandboxDegradation)

    public var isEnforced: Bool {
        if case .enforced = self { return true }
        return false
    }

    public var profile: SandboxProfile? {
        if case let .enforced(profile) = self { return profile }
        return nil
    }

    public var degradation: SandboxDegradation? {
        if case let .degraded(degradation) = self { return degradation }
        return nil
    }
}

/// `sandbox-exec` 를 쓸지 말지 정한다.
public enum SandboxPolicy {
    /// 명시적으로 끄는 스위치. `1`·`true`·`yes` 만 인정한다 — 오타로 격리가 풀리면 안 된다.
    public static let disableEnvironmentKey = "LEARN_SANDBOX_DISABLED"

    fileprivate static let logger = Logger(subsystem: "com.learnkit.runnerkit", category: "sandbox")

    /// 프로세스를 하나도 띄우지 않는 판정. 순수 함수라 그대로 단위 테스트한다.
    ///
    /// 여기서 잡히는 것은 둘뿐이다 — 실행 파일 부재와 환경변수 스위치.
    /// 프로파일이 실제로 컴파일되는지는 `verify(_:)` 가 확인한다.
    public static func decide(
        profile: SandboxProfile,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> SandboxDecision {
        if let raw = environment[disableEnvironmentKey], isTruthy(raw) {
            return .degraded(SandboxDegradation(.disabledByEnvironment(key: disableEnvironmentKey, value: raw)))
        }
        guard isExecutable(SandboxProfile.executablePath) else {
            return .degraded(SandboxDegradation(.executableMissing(path: SandboxProfile.executablePath)))
        }
        return .enforced(profile)
    }

    /// 프로파일이 이 커널에서 실제로 컴파일되는지까지 확인한다.
    ///
    /// `/usr/bin/true` 를 대상으로 한 번 돌려 본다. SBPL 문법 오류든 파라미터 누락이든
    /// **사용자 코드가 뜨기 전에** 걸리게 하려는 것이다. 실측 종료코드는
    /// 프로파일 거부 65(EX_DATAERR), exec 실패 71(EX_OSERR).
    ///
    /// 비용은 프로세스 하나(수 ms)다. 워크스페이스 경로가 실행마다 달라 캐싱이
    /// 의미가 없으므로 호출자가 필요할 때만 부르면 된다 — 앱 시작 시 한 번이면 충분하고,
    /// 매 실행마다 부를 필요는 없다.
    ///
    /// - Parameter sandboxExecutablePath: 프로브가 부를 실행 파일. 테스트가 실패를 흉내 낼 때만
    ///   바꾼다 — 실제 실행 경로는 `SandboxedInvocation.wrap` 이 항상 표준 경로를 쓴다.
    public static func verify(
        _ decision: SandboxDecision,
        sandboxExecutablePath: String = SandboxProfile.executablePath,
        timeout: Duration = .seconds(5)
    ) async -> SandboxDecision {
        guard let profile = decision.profile else {
            if let degradation = decision.degradation { log(degradation) }
            return decision
        }

        let result = await BoundedCommand.run(
            executable: sandboxExecutablePath,
            arguments: profile.argumentPrefix + ["/usr/bin/true"],
            timeout: timeout
        )

        if result.succeeded { return decision }

        let message = result.combinedOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .first
            .map(String.init) ?? "(출력 없음)"

        let degradation: SandboxDegradation
        if let failure = result.launchFailure {
            degradation = SandboxDegradation(.probeFailed(message: failure))
        } else if result.timedOut {
            degradation = SandboxDegradation(.probeFailed(message: "프로브가 \(timeout) 안에 끝나지 않았다"))
        } else {
            degradation = SandboxDegradation(.profileRejected(exitCode: result.exitCode, message: message))
        }
        log(degradation)
        return .degraded(degradation)
    }

    /// 프로파일 조립 실패까지 포함한 한 번의 호출. 호출자가 `try` 를 다루지 않아도 되게.
    public static func decide(
        workspaceRoot: URL,
        temporaryDirectory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SandboxDecision {
        do {
            let profile = try SandboxProfile(
                workspaceRoot: workspaceRoot,
                temporaryDirectory: temporaryDirectory
            )
            return decide(profile: profile, environment: environment)
        } catch {
            let degradation = SandboxDegradation(.profileUnbuildable(message: "\(error)"))
            log(degradation)
            return .degraded(degradation)
        }
    }

    /// 강등을 시스템 로그에 남긴다. 값으로만 돌려주면 호출자가 흘리는 순간 관측이 끊긴다.
    ///
    /// 로그를 내보내는 지점은 `verify(_:)` 하나로 모아 뒀다 — 판정 함수들이 저마다 찍으면
    /// 같은 강등이 두세 줄로 늘어난다. `verify` 를 건너뛰는 호출자는 이걸 직접 부르면 된다.
    public static func log(_ degradation: SandboxDegradation) {
        logger.warning(
            "샌드박스 강등: \(degradation.korean, privacy: .public) (남은 격리: \(degradation.remainingIsolation, privacy: .public))"
        )
    }

    static func isTruthy(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespaces).lowercased() {
        case "1", "true", "yes", "on": true
        default: false
        }
    }
}
