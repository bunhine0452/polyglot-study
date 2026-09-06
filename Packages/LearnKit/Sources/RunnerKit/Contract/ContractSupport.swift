public import LanguageKit
internal import LearnCore

/// 백엔드가 계약의 어느 부분을 실제로 지킬 수 있는지.
///
/// `RunnerCapabilities` 와 다르다 — 저쪽은 UI 가 물어보는 **기능**(stdin·네트워크)이고,
/// 이쪽은 계약 스위트가 물어보는 **책임**(타임아웃을 지키는가·출력을 자르는가)이다.
/// 지원하지 않는다고 선언한 케이스는 실패가 아니라 skip 이 된다.
public struct ContractSupport: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// 벽시계 데드라인을 초과하면 `RunFailure.wallClockExceeded` 를 낸다.
    public static let wallClockTimeout = ContractSupport(rawValue: 1 << 0)
    /// 무한 루프를 데드라인 안에 반드시 멈춘다.
    public static let infiniteLoopTermination = ContractSupport(rawValue: 1 << 1)
    /// `ResourceLimits.outputBytes` 를 넘으면 자르고 `.truncated` 를 한 번 낸다.
    public static let outputTruncation = ContractSupport(rawValue: 1 << 2)
    /// 개행 없는 거대 단일행을 잃지 않고 전달한다.
    public static let hugeSingleLine = ContractSupport(rawValue: 1 << 3)
    /// UTF-8 이 아닌 바이트를 손대지 않고 전달한다.
    public static let nonUTF8Output = ContractSupport(rawValue: 1 << 4)
    /// Task 취소에 즉시 반응한다.
    public static let cancellation = ContractSupport(rawValue: 1 << 5)
    /// 종료코드를 그대로 보고한다.
    public static let exitCodes = ContractSupport(rawValue: 1 << 6)
    /// stdin 을 프로그램에 연결한다.
    public static let standardInput = ContractSupport(rawValue: 1 << 7)
    /// `Diagnostic` 을 행·열까지 채워 낸다.
    public static let diagnostics = ContractSupport(rawValue: 1 << 8)
    /// 프로세스를 띄우는 백엔드다 — fork bomb·손자 프로세스 케이스가 의미를 가진다.
    public static let processIsolation = ContractSupport(rawValue: 1 << 9)

    /// 프로세스를 안 띄우는 백엔드까지 포함해 **모두가 지켜야 하는** 최소 집합.
    public static let baseline: ContractSupport = [
        .wallClockTimeout, .infiniteLoopTermination, .outputTruncation,
        .hugeSingleLine, .nonUTF8Output, .cancellation, .exitCodes,
    ]

    public static let all: ContractSupport = [
        .baseline, .standardInput, .diagnostics, .processIsolation,
    ]

    /// `RunnerCapabilities` 에서 유도할 수 있는 것만 얹은 기본값.
    ///
    /// 타임아웃·취소·절단은 능력이 아니라 **의무**라 baseline 에 항상 들어간다.
    /// 백엔드가 못 지키면 계약을 어긴 것이지 skip 할 일이 아니다.
    public static func inferred(from capabilities: RunnerCapabilities) -> ContractSupport {
        var support: ContractSupport = .baseline
        if capabilities.contains(.standardInput) { support.insert(.standardInput) }
        if capabilities.contains(.compileDiagnostics) { support.insert(.diagnostics) }
        return support
    }
}

/// 계약 케이스 식별자.
public struct ContractCaseID: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let timeout = ContractCaseID("timeout")
    public static let infiniteLoop = ContractCaseID("infinite-loop")
    public static let outputFlood = ContractCaseID("output-flood")
    public static let hugeSingleLine = ContractCaseID("huge-single-line")
    public static let nonUTF8Output = ContractCaseID("non-utf8-output")
    public static let cancellation = ContractCaseID("cancellation")
    public static let exitCode = ContractCaseID("exit-code")
    public static let standardInput = ContractCaseID("standard-input")
    public static let forkBomb = ContractCaseID("fork-bomb")
    public static let grandchildProcess = ContractCaseID("grandchild-process")
}

/// 케이스 하나의 정의. 프로그램(픽스처)과 분리돼 있어서 언어가 늘어도 이 목록은 안 늘어난다.
public struct ContractCase: Hashable, Sendable {
    public var id: ContractCaseID
    public var title: String
    public var requires: ContractSupport

    public init(id: ContractCaseID, title: String, requires: ContractSupport) {
        self.id = id
        self.title = title
        self.requires = requires
    }
}

/// 계약 실패의 종류. `RunFailure` 를 계약 스위트가 비교할 수 있는 형태로 접은 것.
public enum ContractFailureKind: String, Hashable, Sendable {
    case wallClockExceeded
    /// `RLIMIT_CPU` 초과. `wallClockExceeded` 와 접으면 안 된다 — `RunFailure` 가 둘을
    /// 나눈 이유(멈춘 코드 vs 느린 코드)가 계약 스위트에서도 그대로 유효하다.
    case cpuExceeded
    case memoryExceeded
    case cancelled
    case toolchainMissing
    case backend
    case other

    public init(_ error: any Error) {
        if let failure = error as? RunFailure {
            switch failure {
            case .wallClockExceeded: self = .wallClockExceeded
            case .cpuExceeded: self = .cpuExceeded
            case .memoryExceeded: self = .memoryExceeded
            case .cancelled: self = .cancelled
            case .toolchainMissing: self = .toolchainMissing
            case .backend: self = .backend
            }
            return
        }
        self = error is CancellationError ? .cancelled : .other
    }
}

/// 한 케이스에 걸린 기대. 하나의 실행에 여러 개를 걸 수 있다.
public enum ContractExpectation: Hashable, Sendable {
    /// 정상 종료. 종료코드까지 볼지는 선택.
    case finishes(exitCode: Int32?)
    /// 지정한 종류로 실패한다.
    case fails(ContractFailureKind)
    /// 취소가 제한 시간 안에 먹힌다.
    case cancelsWithin(milliseconds: Int)
    /// 출력이 잘리고 `.truncated` 가 온다.
    case truncatesOutput
    /// stdout 에 UTF-8 로 디코드되지 않는 바이트가 있다.
    case emitsNonUTF8Output
    /// 개행으로 끊기지 않은 줄이 최소 이만큼은 온다.
    case emitsLine(atLeastBytes: Int)
    /// stdout 에 이 문자열이 있다.
    case stdoutContains(String)
    /// severity=error 인 진단이 하나 이상 오고, 있으면 이 문자열을 담는다.
    case emitsErrorDiagnostic(containing: String?)
    /// 전체 실행이 이 시간 안에 끝난다.
    case completesWithin(milliseconds: Int)
}
