public import LearnCore

/// 툴체인이 실제로 쓸 수 있는 상태인지.
///
/// - Note: `stub` 이 별도 케이스인 이유는 실측 때문이다. macOS 의 `/usr/bin/java` 는
///   파일로 존재하지만 실행하면 `Unable to locate a Java Runtime` 을 낸다.
///   `command -v` 만으로 판정하면 오탐하므로, 감지는 `--version` 을 실제로 실행해
///   종료코드까지 확인해야 한다.
public enum ModuleAvailability: Hashable, Sendable {
    case ready(version: String, executablePath: String)
    /// 실행 파일이 아예 없다. `installHint` 는 사용자가 복사해 붙일 수 있는 한 줄.
    case missing(installHint: String)
    /// 실행 파일은 있으나 동작하지 않는다 (CLT 스텁 등).
    case stub(path: String, reason: String)
    case unsupported(reason: String)

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

/// 한 언어를 앱에 붙이는 계약.
///
/// 동적 플러그인이 아니라 **컴파일 타임 정적 등록**이다. `dlopen` 은 코드사이닝·공증·
/// 샌드박스 셋 다에서 비용을 치른다. 언어 추가는 앱 재배포로 하되, 레슨 콘텐츠는
/// 콘텐츠 팩으로 동적으로 늘어난다.
public protocol LanguageModule: Sendable {
    static var id: LanguageID { get }
    var displayName: String { get }
    var fileExtensions: Set<String> { get }
    /// 이 언어의 채점 결과를 무엇으로 보여줄지.
    var presenter: GradeResult.Presenter { get }

    /// 툴체인 진단. 온보딩 화면과 레슨 진입 게이트가 이걸 부른다.
    func probe() async -> ModuleAvailability

    /// 실행기는 호스트가 만들어 준다 — 같은 모듈이 백엔드를 갈아끼워도 동작한다.
    func makeRunner() throws -> any CodeRunner
}

extension LanguageModule {
    public var id: LanguageID { Self.id }
}
