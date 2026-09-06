public import LearnCore

/// 앱 조립 지점에서 한 번 만들어지는 정적 레지스트리.
///
/// 구체 언어 모듈을 아는 곳은 여기 하나뿐이다. Feature 계층은 `LanguageID` 만 들고 다닌다.
public struct LanguageRegistry: Sendable {
    private let modules: [LanguageID: any LanguageModule]

    public init(_ modules: [any LanguageModule]) {
        self.modules = Dictionary(
            modules.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public subscript(id: LanguageID) -> (any LanguageModule)? { modules[id] }

    public var all: [any LanguageModule] {
        modules.values.sorted { $0.displayName < $1.displayName }
    }
}
