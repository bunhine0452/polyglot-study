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
    /// 종료 상태를 그대로 보고한다.
    public static let terminationStatus = ContractSupport(rawValue: 1 << 6)
    /// stdin 을 프로그램에 연결한다.
    public static let standardInput = ContractSupport(rawValue: 1 << 7)
    /// `Diagnostic` 을 행·열까지 채워 낸다.
    public static let diagnostics = ContractSupport(rawValue: 1 << 8)
    /// 프로세스를 띄우는 백엔드다 — fork bomb·손자 프로세스 케이스가 의미를 가진다.
    public static let processIsolation = ContractSupport(rawValue: 1 << 9)
    /// `ResourceLimits.cpuSeconds` 초과를 `RunFailure.cpuExceeded` 로 낸다.
    public static let cpuTimeLimit = ContractSupport(rawValue: 1 << 10)
    /// `ResourceLimits.memoryMegabytes` 초과를 `RunFailure.memoryExceeded` 로 낸다.
    public static let memoryLimit = ContractSupport(rawValue: 1 << 11)
    /// `ResourceLimits.fileSizeBytes` 초과를 `RunFailure.fileSizeExceeded` 로 낸다.
    public static let fileSizeLimit = ContractSupport(rawValue: 1 << 12)

    /// 상한과 무관하게 **모두가 지켜야 하는** 최소 집합.
    ///
    /// 여기 있는 넷은 자원 상한이 아니라 **바이트 파이프라인과 수명의 정확성**이다.
    /// 어떤 백엔드든 이걸 못 지키면 계약을 어긴 것이지 skip 할 일이 아니다.
    /// 상한 계열(벽시계·CPU·메모리·출력·파일·프로세스)은 `EnforcedLimits` 에서 유도된다.
    public static let baseline: ContractSupport = [
        .hugeSingleLine, .nonUTF8Output, .cancellation, .terminationStatus,
    ]

    public static let all: ContractSupport = [
        .baseline, .wallClockTimeout, .infiniteLoopTermination, .outputTruncation,
        .standardInput, .diagnostics, .processIsolation,
        .cpuTimeLimit, .memoryLimit, .fileSizeLimit,
    ]

    /// 러너가 스스로 선언한 것에서 유도한다.
    ///
    /// 상한 계열은 **`enforcedLimits` 가 유일한 출처**다. 예전에는 벽시계·절단을
    /// baseline 에 박아두고 fork bomb 케이스만 하드코딩으로 영영 skip 했는데,
    /// 그러면 "이 백엔드가 무엇을 못 막는지"가 하네스 안에 숨는다. 이제는 러너가
    /// 선언하고 하네스는 그걸 읽기만 한다.
    public static func inferred(from runner: any CodeRunner) -> ContractSupport {
        inferred(capabilities: runner.capabilities, enforcedLimits: runner.enforcedLimits)
    }

    public static func inferred(
        capabilities: RunnerCapabilities,
        enforcedLimits: EnforcedLimits
    ) -> ContractSupport {
        var support: ContractSupport = .baseline
        if enforcedLimits.contains(.wallClock) {
            support.insert(.wallClockTimeout)
            support.insert(.infiniteLoopTermination)
        }
        if enforcedLimits.contains(.outputBytes) { support.insert(.outputTruncation) }
        if enforcedLimits.contains(.cpuTime) { support.insert(.cpuTimeLimit) }
        if enforcedLimits.contains(.memory) { support.insert(.memoryLimit) }
        if enforcedLimits.contains(.fileSize) { support.insert(.fileSizeLimit) }
        if enforcedLimits.contains(.processCount) { support.insert(.processIsolation) }
        if capabilities.contains(.standardInput) { support.insert(.standardInput) }
        if capabilities.contains(.compileDiagnostics) { support.insert(.diagnostics) }
        return support
    }

    /// 사람이 읽는 이름. skip 사유를 찍을 때 쓴다.
    public var names: [String] {
        let table: [(ContractSupport, String)] = [
            (.wallClockTimeout, "wallClockTimeout"), (.infiniteLoopTermination, "infiniteLoopTermination"),
            (.outputTruncation, "outputTruncation"), (.hugeSingleLine, "hugeSingleLine"),
            (.nonUTF8Output, "nonUTF8Output"), (.cancellation, "cancellation"),
            (.terminationStatus, "terminationStatus"), (.standardInput, "standardInput"),
            (.diagnostics, "diagnostics"), (.processIsolation, "processIsolation"),
            (.cpuTimeLimit, "cpuTimeLimit"), (.memoryLimit, "memoryLimit"),
            (.fileSizeLimit, "fileSizeLimit"),
        ]
        return table.filter { contains($0.0) }.map(\.1)
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
    public static let cpuExhaustion = ContractCaseID("cpu-exhaustion")
    public static let memoryExhaustion = ContractCaseID("memory-exhaustion")
    public static let fileSizeFlood = ContractCaseID("file-size-flood")
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
    /// `RLIMIT_FSIZE` 초과. "출력 파일이 너무 크다"는 나머지 셋과 조언이 다르다.
    case fileSizeExceeded
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
            case .fileSizeExceeded: self = .fileSizeExceeded
            case .cancelled: self = .cancelled
            case .toolchainMissing: self = .toolchainMissing
            case .backend: self = .backend
            }
            return
        }
        self = error is CancellationError ? .cancelled : .other
    }
}

/// 종료 상태에 거는 기대.
public enum TerminationExpectation: Hashable, Sendable {
    case succeeded
    /// 실패로 끝난다. `code` 가 nil 이면 종료 코드는 따지지 않는다 — 종료 코드라는
    /// 개념이 없는 백엔드(인프로세스)도 이 기대를 만족해야 하기 때문이다.
    case failed(code: Int32?)
}

/// 한 케이스에 걸린 기대. 하나의 실행에 여러 개를 걸 수 있다.
public enum ContractExpectation: Hashable, Sendable {
    /// 스트림이 `finished` 로 끝나고 종료 상태가 이것이다.
    case finishes(TerminationExpectation)
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
    /// `RunEvent.resultSet` 으로 이 모양의 표가 하나 온다.
    case emitsResultSet(rows: Int, columns: Int)
    /// 전체 실행이 이 시간 안에 끝난다.
    case completesWithin(milliseconds: Int)
}
