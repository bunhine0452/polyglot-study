/// 채점 결과. **언어 어댑터가 넘는 마지막 경계**다.
///
/// SQL 은 결과셋을 비교하고, Python 은 pytest 출력을 파싱하고, Swift 는 Swift Testing 을
/// 돌리고, Assembly 는 레지스터 상태를 단언한다 — 전부 다른 일이지만 결과는 이 하나로 모인다.
/// 이 타입이 언어 중립을 유지하는 한 UI 는 언어를 몰라도 된다.
public struct GradeResult: Hashable, Sendable {
    public struct TestOutcome: Hashable, Sendable {
        public var name: String
        public var passed: Bool
        /// 실패한 경우의 설명. 통과한 테스트는 보통 nil.
        public var message: String?
        public var durationMilliseconds: Int?

        public init(name: String, passed: Bool, message: String? = nil, durationMilliseconds: Int? = nil) {
            self.name = name
            self.passed = passed
            self.message = message
            self.durationMilliseconds = durationMilliseconds
        }
    }

    /// 결과를 무엇으로 보여줄지. 이질성을 데이터 모델이 아니라 여기 가둔다.
    public enum Presenter: String, Hashable, Sendable, CaseIterable {
        /// stdout/stderr 를 흘려보내는 콘솔 — 대부분의 언어.
        case console
        /// 행·열 diff 가 있는 결과 그리드 — SQL.
        case table
        /// localhost dev 서버를 띄우는 웹뷰 — Next.js.
        case browser
        /// 레지스터·스택·메모리 패널 — Assembly.
        case registers
    }

    public var passed: Bool
    public var tests: [TestOutcome]
    public var diagnostics: [Diagnostic]
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32?
    public var durationMilliseconds: Int
    public var presenter: Presenter

    public init(
        passed: Bool,
        tests: [TestOutcome] = [],
        diagnostics: [Diagnostic] = [],
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32? = nil,
        durationMilliseconds: Int,
        presenter: Presenter
    ) {
        self.passed = passed
        self.tests = tests
        self.diagnostics = diagnostics
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationMilliseconds = durationMilliseconds
        self.presenter = presenter
    }

    public var failedTests: [TestOutcome] { tests.filter { !$0.passed } }
    public var hasErrors: Bool { diagnostics.contains { $0.severity == .error } }
}
