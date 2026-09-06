internal import Foundation

/// 런처 호출 하나에 `sandbox-exec` 를 끼워 넣는다.
///
/// ## 왜 C 런처를 고치지 않았나
///
/// 체인은 argv 조립만으로 끝난다.
///
/// ```
/// learn-launcher --cpu 5 --wall 10 --status-fd 3 --cwd WS
///   -- /usr/bin/sandbox-exec -D ... -p <프로파일> -- /path/to/python3 main.py
/// ```
///
/// `sandbox-exec` 는 `sandbox_init` 후 **같은 프로세스에서** `execv` 한다. 그래서
/// 런처가 fork 직후 자식에 건 것들이 전부 그대로 살아남는다 —
/// `setsid` 로 만든 프로세스 그룹(그래서 `killpg` 가 여전히 손자까지 잡는다),
/// `RLIMIT_CPU`/`NPROC`/`FSIZE`, `chdir`, 그리고 status fd 의 `FD_CLOEXEC`.
/// 실측으로 확인했다 — 체인 후에도 `SPAWNED pid==pgid`, 벽시계 초과 시 `TIMEOUT`+`SIGNAL 9`,
/// CPU 초과 시 `SIGNAL 24`(SIGXCPU), 종료코드 투명 전달이 모두 그대로다.
///
/// C 쪽에 조건 분기를 넣지 않는 편이 낫다. 런처는 "rlimit 을 걸고 execv 한다"는 한 가지
/// 일만 하고, 무엇을 exec 하는지는 호출자가 정한다.
public enum SandboxedInvocation {
    /// `sandbox-exec` 를 앞단에 끼운 새 호출을 만든다. 원본은 바뀌지 않는다.
    public static func wrap(_ invocation: LauncherInvocation, profile: SandboxProfile) -> LauncherInvocation {
        var wrapped = invocation
        wrapped.executablePath = SandboxProfile.executablePath
        wrapped.arguments = profile.argumentPrefix + [invocation.executablePath] + invocation.arguments
        return wrapped
    }

    /// 판정 결과를 그대로 적용한다. 강등이면 원본을 손대지 않는다.
    public static func apply(_ decision: SandboxDecision, to invocation: LauncherInvocation) -> LauncherInvocation {
        guard let profile = decision.profile else { return invocation }
        return wrap(invocation, profile: profile)
    }
}

/// `sandbox-exec` **자신**이 실패한 경우.
///
/// 사용자 코드의 실패와 구별해야 한다. 체인을 끼우면 런처의 `ERR exec` 경로가 가려지기
/// 때문이다 — 대상 프로그램이 없어도 `sandbox-exec` 는 정상 exec 되므로 런처는
/// `EXIT 71` 만 보고하고, 진짜 원인은 `sandbox-exec` 의 stderr 한 줄에만 남는다.
public struct SandboxExecFailure: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: String, Hashable, Sendable {
        /// 프로파일 컴파일 실패 (EX_DATAERR).
        case profileRejected
        /// 대상 프로그램을 exec 하지 못했다 (EX_OSERR).
        case executionFailed
    }

    /// `sandbox-exec` 가 stderr 첫 줄에 항상 붙이는 접두사.
    public static let messagePrefix = "sandbox-exec:"
    /// 프로파일 거부. `sysexits.h` 의 `EX_DATAERR`.
    public static let profileRejectedExitCode: Int32 = 65
    /// exec 실패. `sysexits.h` 의 `EX_OSERR`.
    public static let executionFailedExitCode: Int32 = 71

    public var kind: Kind
    public var exitCode: Int32
    public var message: String

    public init(kind: Kind, exitCode: Int32, message: String) {
        self.kind = kind
        self.exitCode = exitCode
        self.message = message
    }

    public var description: String {
        switch kind {
        case .profileRejected: "샌드박스 프로파일이 거부됐다: \(message)"
        case .executionFailed: "샌드박스가 대상 프로그램을 실행하지 못했다: \(message)"
        }
    }

    /// 종료코드와 stderr 로 `sandbox-exec` 자신의 실패를 가려낸다.
    ///
    /// - Important: 종료코드 **하나만으로는 판정하지 않는다.** 사용자 코드도 65 나 71 로
    ///   끝날 수 있다. 반대로 사용자 코드가 `sandbox-exec:` 로 시작하는 줄을 stderr 에
    ///   찍고 65 로 종료하면 이 판정을 속일 수 있다 — status fd 는 자식에게 닫혀 있어
    ///   위조가 불가능하지만 stderr 는 그렇지 않다. 오판의 결과는 "강등됐다고 잘못
    ///   보고"뿐이라 감수한다.
    public static func classify(exitCode: Int32, standardError: String) -> SandboxExecFailure? {
        guard let line = standardError
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first(where: { $0.hasPrefix(messagePrefix) })
        else { return nil }

        let message = line
            .dropFirst(messagePrefix.count)
            .trimmingCharacters(in: .whitespaces)

        switch exitCode {
        case profileRejectedExitCode:
            return SandboxExecFailure(kind: .profileRejected, exitCode: exitCode, message: message)
        case executionFailedExitCode:
            return SandboxExecFailure(kind: .executionFailed, exitCode: exitCode, message: message)
        default:
            return nil
        }
    }
}

/// 프로파일이 정확히 동작하는데도 사용자 경험을 해치는 조합. 막을 수는 없고 알려 줄 수는 있다.
public enum SandboxAdvisory: Hashable, Sendable, CustomStringConvertible {
    /// 대상이 `/usr/bin` 의 xcrun 셰이더(shim)다.
    ///
    /// `/usr/bin/swiftc`·`/usr/bin/python3` 은 진짜 툴이 아니라 `xcrun` 이 경로를 찾아
    /// 재실행하는 스텁이고, 그 과정에서 `<DARWIN_USER_TEMP_DIR>/xcrun_db-XXXX` 에 캐시를
    /// 쓴다. 샌드박스는 그 쓰기를 거부한다 — **거부가 맞다.** xcrun 캐시를 쓸 수 있으면
    /// 사용자 코드가 "샌드박스 밖에서 나중에 `xcrun swiftc` 를 부르는 프로세스"의
    /// 도구 해석을 바꿔치기할 수 있다. 샌드박스 탈출과 다름없다.
    ///
    /// 실행 자체는 성공하지만(실측 rc=0) stderr 에
    /// `swiftc: error: couldn't create cache file ...` 이 섞여 학습자의 컴파일 진단이
    /// 오염된다. 해법은 프로파일을 여는 게 아니라 **샌드박스 밖에서 `xcrun --find` 로
    /// 실제 경로를 해석해 그쪽을 실행하는 것**이다. `ToolchainProbe` 가 이미 `xcrun --find`
    /// 후보를 열거하므로 그 결과를 쓰면 된다. 실측: 해석된 경로로 부르면 stderr 가 깨끗하고
    /// 진단도 정상이다.
    case xcrunShimTarget(path: String)

    public var description: String {
        switch self {
        case let .xcrunShimTarget(path):
            "\(path) 는 xcrun 셰이더라 샌드박스 안에서 xcrun 캐시를 쓰지 못해 stderr 가 오염된다. "
                + "xcrun --find 로 해석한 실제 툴체인 경로를 쓰는 편이 낫다."
        }
    }

    /// stderr 에서 이 문자열이 보이면 위 사례다. 러너가 진단에서 걸러 낼 때 쓴다.
    public static let xcrunCacheDenialMarker = "couldn't create cache file"

    /// xcrun 셰이더가 사는 디렉터리.
    public static let xcrunShimDirectory = "/usr/bin"

    /// 이 실행 대상에 붙는 주의사항.
    public static func advisories(forExecutable path: String) -> [SandboxAdvisory] {
        let directory = (path as NSString).deletingLastPathComponent
        guard directory == xcrunShimDirectory else { return [] }
        return [.xcrunShimTarget(path: path)]
    }
}
