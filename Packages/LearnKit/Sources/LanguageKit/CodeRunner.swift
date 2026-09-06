public import LearnCore
public import struct Foundation.Data
public import struct Foundation.URL

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
    /// `RunEvent.resultSet` 으로 구조화된 표를 낸다 — `Presenter.table` 이 그릴 재료.
    public static let structuredResults = RunnerCapabilities(rawValue: 1 << 4)
    /// 이 러너의 메모리 상한은 **프로세스 전역**이다.
    ///
    /// 인프로세스 SQLite 가 그렇다 — `sqlite3_hard_heap_limit64` 에는 연결별 상한이 없어서
    /// 상한을 거는 동안 **같은 프로세스의 다른 코드**(앱 자신의 DB 접근 포함)도 함께 조인다.
    /// 호스트가 이 러너를 언제 돌릴지 정할 때 알아야 하는 사실이라 능력으로 노출한다.
    public static let processGlobalMemoryLimit = RunnerCapabilities(rawValue: 1 << 5)
}

/// 러너가 **실제로 강제할 수 있는** 상한.
///
/// `ResourceLimits` 는 호출자의 요구고 이쪽은 백엔드의 능력이다. 둘을 나누지 않으면
/// 인프로세스 러너처럼 `cpuSeconds`·`maxProcesses` 를 걸 수단이 아예 없는 백엔드가
/// 조용히 상한을 무시하게 되고, 계약 스위트는 그걸 실패로 잡아 잡음을 만든다.
/// 선언한 것만 검사하고 나머지는 skip 한다.
public struct EnforcedLimits: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// `ResourceLimits.wallClockSeconds` 를 지킨다.
    public static let wallClock = EnforcedLimits(rawValue: 1 << 0)
    /// `ResourceLimits.cpuSeconds` 를 지킨다 (`RLIMIT_CPU` 등).
    public static let cpuTime = EnforcedLimits(rawValue: 1 << 1)
    /// `ResourceLimits.memoryMegabytes` 를 지킨다.
    public static let memory = EnforcedLimits(rawValue: 1 << 2)
    /// `ResourceLimits.outputBytes` 를 넘으면 자르고 `.truncated` 를 낸다.
    public static let outputBytes = EnforcedLimits(rawValue: 1 << 3)
    /// `ResourceLimits.fileSizeBytes` 를 지킨다 (`RLIMIT_FSIZE` 등).
    public static let fileSize = EnforcedLimits(rawValue: 1 << 4)
    /// `ResourceLimits.maxProcesses` 를 지킨다 (`RLIMIT_NPROC` 등).
    public static let processCount = EnforcedLimits(rawValue: 1 << 5)

    /// 아무 상한도 강제하지 못한다 — 신뢰된 코드 전용 러너.
    public static let none: EnforcedLimits = []
    /// 여섯 축 전부. 서브프로세스·컨테이너 백엔드가 목표로 하는 집합이다.
    public static let all: EnforcedLimits = [
        .wallClock, .cpuTime, .memory, .outputBytes, .fileSize, .processCount,
    ]
}

/// 사용자 코드에 거는 상한.
///
/// - Important: macOS 는 `RLIMIT_AS` / `RLIMIT_DATA` 를 지원하지 않는다(설정 시 EINVAL).
///   따라서 `memoryMegabytes` 는 rlimit 이 아니라 `proc_pid_rusage()` 폴링으로 강제된다.
///   서브프로세스 백엔드는 `RLIMIT_CPU` / `RLIMIT_NPROC` / `RLIMIT_FSIZE` 만 rlimit 으로 걸고,
///   벽시계 초과는 프로세스 그룹 전체에 `killpg` 로 처리한다.
///
/// 여기 적힌 것을 러너가 전부 지킬 수 있는 것은 아니다 — 무엇을 실제로 강제하는지는
/// `CodeRunner.enforcedLimits` 가 선언한다.
public struct ResourceLimits: Hashable, Sendable {
    public var wallClockSeconds: Int
    public var cpuSeconds: Int
    public var memoryMegabytes: Int
    /// 출력 폭주 방어. 초과분은 잘리고 `RunEvent.truncated` 가 한 번 온다.
    public var outputBytes: Int
    /// 디스크에 쓸 수 있는 파일 하나의 최대 크기 (`RLIMIT_FSIZE`).
    ///
    /// `outputBytes` 와 다르다 — 저쪽은 stdout/stderr 스트림 상한이고 이쪽은 파일이다.
    /// 초과하면 SIGXFSZ 를 맞고 `RunFailure.fileSizeExceeded` 가 된다.
    public var fileSizeBytes: Int
    /// fork bomb 방어 (`RLIMIT_NPROC`).
    public var maxProcesses: Int

    public init(
        wallClockSeconds: Int = 10,
        cpuSeconds: Int = 5,
        memoryMegabytes: Int = 512,
        outputBytes: Int = 1 << 20,
        fileSizeBytes: Int = 64 << 20,
        maxProcesses: Int = 16
    ) {
        self.wallClockSeconds = wallClockSeconds
        self.cpuSeconds = cpuSeconds
        self.memoryMegabytes = memoryMegabytes
        self.outputBytes = outputBytes
        self.fileSizeBytes = fileSizeBytes
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
    /// 잘 알려진 `resources` 키. 백엔드마다 자유롭게 늘리되, 여러 백엔드가 공유하는 것은 여기 모은다.
    public enum Resource {
        /// 읽기 전용 샘플 데이터베이스 — SQL 트랙이 레슨마다 다른 `.db` 를 여기로 준다.
        public static let database = "database"
        /// 프로젝트 템플릿 디렉터리 — 컨테이너 백엔드의 Next.js 스캐폴드 같은 것.
        public static let projectTemplate = "projectTemplate"
    }

    public var files: [SourceFile]
    public var entryPoint: String?
    public var arguments: [String]
    public var standardInput: Data?
    public var limits: ResourceLimits
    /// 이 실행이 대상으로 삼는 읽기 전용 자원. 소스가 아니라 "무엇에 대해 실행하는가".
    ///
    /// SQL 은 레슨별 샘플 DB, 나중에 Next.js 는 프로젝트 템플릿이 여기 온다. 러너를
    /// 자원마다 새로 만들지 않아도 되게 하려고 요청에 실었다 — 러너는 재사용 가능한
    /// 무상태 값이고, 레슨마다 달라지는 것은 요청이다.
    public var resources: [String: URL]

    public init(
        files: [SourceFile],
        entryPoint: String? = nil,
        arguments: [String] = [],
        standardInput: Data? = nil,
        limits: ResourceLimits = .lesson,
        resources: [String: URL] = [:]
    ) {
        self.files = files
        self.entryPoint = entryPoint
        self.arguments = arguments
        self.standardInput = standardInput
        self.limits = limits
        self.resources = resources
    }
}

public enum RunPhase: String, Hashable, Sendable {
    case preparing, compiling, running
}

/// 실행이 어떻게 끝났는가.
///
/// 종료 코드를 계약의 중심에 두지 않는 이유는 **인프로세스 러너에는 그런 개념이 없기**
/// 때문이다. SQL 오류를 임의로 1 에 매핑하면 "종료코드 1"이 두 가지 뜻을 갖게 되고,
/// 컨테이너 백엔드가 붙으면 오케스트레이터의 종료 이유까지 여기에 욱여넣게 된다.
public struct RunTermination: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case succeeded
        /// 실패로 끝났다. `code` 가 nil 이면 **종료 코드라는 개념이 없는 백엔드**다.
        case failed(code: Int32?)
    }

    public var status: Status
    public var durationMilliseconds: Int

    public init(status: Status, durationMilliseconds: Int) {
        self.status = status
        self.durationMilliseconds = durationMilliseconds
    }

    /// 종료 코드로 만든 종료. 0 이면 성공, 아니면 그 코드로 실패.
    public static func exitCode(_ code: Int32, durationMilliseconds: Int) -> RunTermination {
        RunTermination(
            status: code == 0 ? .succeeded : .failed(code: code),
            durationMilliseconds: durationMilliseconds
        )
    }

    public var succeeded: Bool { status == .succeeded }

    /// 백엔드가 종료 코드를 아는 경우에만 그 값.
    public var exitCode: Int32? {
        switch status {
        case .succeeded: 0
        case .failed(let code): code
        }
    }
}

/// 실행 중 흘러나오는 사건. 스트림이라 UI 가 완료를 기다리지 않고 그릴 수 있다.
public enum RunEvent: Sendable {
    case phase(RunPhase)
    case standardOutput(Data)
    case standardError(Data)
    case diagnostic(Diagnostic)
    /// 구조화된 결과 표. 바이트 스트림과 **나란히** 흐른다 — 콘솔 프리젠터는 stdout 을
    /// 그리고 표 프리젠터는 이걸 그린다. 둘 중 하나만 있어도 UI 는 동작해야 한다.
    case resultSet(ResultSet)
    /// 출력이 `ResourceLimits.outputBytes` 를 넘어 잘렸다.
    case truncated
    case finished(RunTermination)
}

public enum RunFailure: Error, Equatable, Sendable {
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
    /// `RLIMIT_FSIZE` 초과로 SIGXFSZ 를 맞았다.
    ///
    /// "출력 파일이 너무 크다"는 "코드가 멈췄다"와 완전히 다른 조언이다 — 상한을 늘릴
    /// 문제가 아니라 무엇을 쓰고 있는지 볼 문제다.
    case fileSizeExceeded(bytes: Int)
    case cancelled
    case backend(String)
}

/// 코드 실행의 유일한 경계.
///
/// 구현은 넷이다 — 인프로세스(SQLite), 웹뷰(Pyodide), 서브프로세스(swiftc·rustc·go),
/// 에뮬레이터(Assembly). 넷 다 `RunnerContractTests` 라는 하나의 계약 스위트를 통과해야 한다.
public protocol CodeRunner: Sendable {
    var capabilities: RunnerCapabilities { get }
    /// 이 러너가 실제로 강제할 수 있는 상한. 계약 스위트가 검사 범위를 여기서 정한다.
    ///
    /// 기본 구현을 일부러 두지 않았다 — 새 백엔드가 "무엇을 못 막는지"를 조용히
    /// 넘어가지 못하게 하는 것이 이 속성의 존재 이유다.
    var enforcedLimits: EnforcedLimits { get }
    func run(_ request: RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
}
