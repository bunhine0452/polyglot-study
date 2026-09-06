public import LearnCore
public import struct Foundation.Data

/// 실행기 하나가 할 수 있는 일. 백엔드마다 다르므로 UI 가 런타임에 물어본다.
public struct RunnerCapabilities: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// stdin 을 받을 수 있다 — Python `input()` 실습 가능 여부.
    public static let standardInput = RunnerCapabilities(rawValue: 1 << 0)
    /// 프로그램이 네트워크에 나갈 수 있다. 기본은 차단.
    public static let network = RunnerCapabilities(rawValue: 1 << 1)
    /// 실행 중 상호작용(REPL, 스텝 디버깅)이 가능하다.
    public static let interactive = RunnerCapabilities(rawValue: 1 << 2)
    /// 컴파일 단계가 따로 있어 진단을 별도로 낼 수 있다.
    public static let compileDiagnostics = RunnerCapabilities(rawValue: 1 << 3)
}

/// 사용자 코드에 거는 상한.
///
/// - Important: macOS 는 `RLIMIT_AS` / `RLIMIT_DATA` 를 지원하지 않는다(설정 시 EINVAL).
///   따라서 `memoryMegabytes` 는 rlimit 이 아니라 `proc_pid_rusage()` 폴링으로 강제된다.
///   서브프로세스 백엔드는 `RLIMIT_CPU` / `RLIMIT_NPROC` / `RLIMIT_FSIZE` 만 rlimit 으로 걸고,
///   벽시계 초과는 프로세스 그룹 전체에 `killpg` 로 처리한다.
public struct ResourceLimits: Hashable, Sendable {
    public var wallClockSeconds: Int
    public var cpuSeconds: Int
    public var memoryMegabytes: Int
    /// 출력 폭주 방어. 초과분은 잘리고 `RunEvent.truncated` 가 한 번 온다.
    public var outputBytes: Int
    /// fork bomb 방어 (`RLIMIT_NPROC`).
    public var maxProcesses: Int

    public init(
        wallClockSeconds: Int = 10,
        cpuSeconds: Int = 5,
        memoryMegabytes: Int = 512,
        outputBytes: Int = 1 << 20,
        maxProcesses: Int = 16
    ) {
        self.wallClockSeconds = wallClockSeconds
        self.cpuSeconds = cpuSeconds
        self.memoryMegabytes = memoryMegabytes
        self.outputBytes = outputBytes
        self.maxProcesses = maxProcesses
    }

    public static let lesson = ResourceLimits()
}

public struct SourceFile: Hashable, Sendable {
    /// 워크스페이스 기준 상대 경로.
    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

public struct RunRequest: Sendable {
    public var files: [SourceFile]
    public var entryPoint: String?
    public var arguments: [String]
    public var standardInput: Data?
    public var limits: ResourceLimits

    public init(
        files: [SourceFile],
        entryPoint: String? = nil,
        arguments: [String] = [],
        standardInput: Data? = nil,
        limits: ResourceLimits = .lesson
    ) {
        self.files = files
        self.entryPoint = entryPoint
        self.arguments = arguments
        self.standardInput = standardInput
        self.limits = limits
    }
}

public enum RunPhase: String, Hashable, Sendable {
    case preparing, compiling, running
}

/// 실행 중 흘러나오는 사건. 스트림이라 UI 가 완료를 기다리지 않고 그릴 수 있다.
public enum RunEvent: Sendable {
    case phase(RunPhase)
    case standardOutput(Data)
    case standardError(Data)
    case diagnostic(Diagnostic)
    /// 출력이 `ResourceLimits.outputBytes` 를 넘어 잘렸다.
    case truncated
    case finished(exitCode: Int32, durationMilliseconds: Int)
}

public enum RunFailure: Error, Sendable {
    case toolchainMissing(hint: String)
    case wallClockExceeded(seconds: Int)
    /// `RLIMIT_CPU` 초과로 SIGXCPU 를 맞았다.
    ///
    /// - Important: `wallClockExceeded` 와 반드시 구별해야 한다. 벽시계 초과는
    ///   "코드가 멈췄다"(입력 대기·데드락)이고 CPU 초과는 "코드가 느리다"(비효율 알고리즘)라서
    ///   학습자에게 줄 조언이 정반대다. 서브프로세스 백엔드는 런처 status fd 의
    ///   `TIMEOUT` 유무로 둘을 가른다 — 둘 다 종료 상태만 보면 구별되지 않는다.
    case cpuExceeded(seconds: Int)
    case memoryExceeded(megabytes: Int)
    case cancelled
    case backend(String)
}

/// 코드 실행의 유일한 경계.
///
/// 구현은 넷이다 — 인프로세스(SQLite), 웹뷰(Pyodide), 서브프로세스(swiftc·rustc·go),
/// 에뮬레이터(Assembly). 넷 다 `RunnerContractTests` 라는 하나의 계약 스위트를 통과해야 한다.
public protocol CodeRunner: Sendable {
    var capabilities: RunnerCapabilities { get }
    func run(_ request: RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
}
