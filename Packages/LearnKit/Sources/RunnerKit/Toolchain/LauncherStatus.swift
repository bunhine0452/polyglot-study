public import LanguageKit
private import Darwin

/// `learn-launcher` 가 `--status-fd` 로 흘리는 한 줄.
///
/// 이 채널이 있어야 **벽시계 초과**와 **사용자 코드가 스스로 SIGKILL 을 맞은 것**을
/// 구별할 수 있다. 둘 다 종료 상태로는 똑같이 "signal 9" 로 보인다.
public enum LauncherStatus: Hashable, Sendable {
    /// execv 성공 직후 한 번. `processGroup` 은 자식이 `setsid` 로 만든 새 그룹이며
    /// 메모리 폴러와 강제 종료가 이 값을 쓴다.
    case spawned(processIdentifier: Int32, processGroup: Int32)
    /// `--wall` 초과로 런처가 그룹을 죽였다.
    case timeout
    case exited(code: Int32)
    case signalled(number: Int32)
    /// 런처 **자신**의 실패. 사용자 코드는 시작조차 못 했다.
    case launcherError(stage: String, errorNumber: Int32)

    public static func parse(line: String) -> LauncherStatus? {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let tag = fields.first else { return nil }
        switch tag {
        case "SPAWNED":
            guard fields.count == 3, let pid = Int32(fields[1]), let group = Int32(fields[2]) else { return nil }
            return .spawned(processIdentifier: pid, processGroup: group)
        case "TIMEOUT":
            return .timeout
        case "EXIT":
            guard fields.count == 2, let code = Int32(fields[1]) else { return nil }
            return .exited(code: code)
        case "SIGNAL":
            guard fields.count == 2, let number = Int32(fields[1]) else { return nil }
            return .signalled(number: number)
        case "ERR":
            guard fields.count == 3, let number = Int32(fields[2]) else { return nil }
            return .launcherError(stage: fields[1], errorNumber: number)
        default:
            return nil
        }
    }

    /// 부분 수신에도 견디도록 완결된 줄만 해석한다 — 마지막 개행 뒤 조각은 버린다.
    public static func parse(stream: String) -> [LauncherStatus] {
        stream.split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parse(line: String($0)) }
    }
}

/// 런처 실패 한 건.
public struct LauncherFailureReport: Hashable, Sendable {
    public var stage: String
    public var errorNumber: Int32

    public init(stage: String, errorNumber: Int32) {
        self.stage = stage
        self.errorNumber = errorNumber
    }
}

public enum LauncherTermination: Hashable, Sendable {
    case exited(code: Int32)
    case signalled(number: Int32)
}

/// status fd 전체를 읽고 나서의 결론.
public struct LauncherOutcome: Hashable, Sendable {
    public var processIdentifier: Int32?
    public var processGroup: Int32?
    /// `TIMEOUT` 을 봤는가. 이게 참이면 뒤따르는 `SIGNAL 9` 는 런처가 때린 것이다.
    public var wallClockExceeded: Bool
    public var termination: LauncherTermination?
    public var launcherFailure: LauncherFailureReport?

    public init(
        processIdentifier: Int32? = nil,
        processGroup: Int32? = nil,
        wallClockExceeded: Bool = false,
        termination: LauncherTermination? = nil,
        launcherFailure: LauncherFailureReport? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.processGroup = processGroup
        self.wallClockExceeded = wallClockExceeded
        self.termination = termination
        self.launcherFailure = launcherFailure
    }

    public init(statuses: [LauncherStatus]) {
        self.init()
        for status in statuses {
            switch status {
            case let .spawned(pid, group):
                processIdentifier = pid
                processGroup = group
            case .timeout:
                wallClockExceeded = true
            case let .exited(code):
                termination = .exited(code: code)
            case let .signalled(number):
                termination = .signalled(number: number)
            case let .launcherError(stage, number):
                launcherFailure = LauncherFailureReport(stage: stage, errorNumber: number)
            }
        }
    }

    /// `RLIMIT_CPU` 소프트 상한에 걸려 SIGXCPU 로 죽었다 — "코드가 느리다".
    /// 벽시계 초과("코드가 멈췄다")와는 사용자에게 완전히 다른 의미다.
    public var cpuExceeded: Bool {
        termination == .signalled(number: SIGXCPU)
    }

    /// `RLIMIT_FSIZE` 초과.
    public var fileSizeExceeded: Bool {
        termination == .signalled(number: SIGXFSZ)
    }

    /// 성공적으로 종료했다면 그 코드.
    public var exitCode: Int32? {
        if case let .exited(code) = termination { return code }
        return nil
    }

    /// 런처 계약을 `RunFailure` 로 번역한다.
    ///
    /// - Parameter memoryKilled: 메모리 폴러가 그룹을 죽였는지. 폴러가 SIGKILL 했다면
    ///   런처는 `SIGNAL 9` 만 보고하므로 호출자만이 사인을 안다.
    public func failure(limits: ResourceLimits, memoryKilled: Bool = false) -> RunFailure? {
        if let launcherFailure {
            return .backend("launcher \(launcherFailure.stage) failed: errno \(launcherFailure.errorNumber)")
        }
        if memoryKilled {
            return .memoryExceeded(megabytes: limits.memoryMegabytes)
        }
        if wallClockExceeded {
            return .wallClockExceeded(seconds: limits.wallClockSeconds)
        }
        if cpuExceeded {
            return .cpuExceeded(seconds: limits.cpuSeconds)
        }
        if fileSizeExceeded {
            return .fileSizeExceeded(bytes: limits.fileSizeBytes)
        }
        return nil
    }
}
