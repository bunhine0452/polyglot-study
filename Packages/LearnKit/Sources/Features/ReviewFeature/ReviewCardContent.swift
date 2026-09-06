public import LearnCore

/// 복습 카드 한 장의 표시용 콘텐츠 — 질문·답·트랙 라벨.
///
/// `ReviewFeature` 는 `ContentKit`(레슨 파서·팩 로더)을 임포트하지 않는다. 이유는 둘이다:
/// 이 타깃의 의존성은 `LearnCore`·`LearnScheduling`·`LearnPersistence`·`DesignSystem` 으로
/// 이미 확정돼 있고(`Package.swift`), 콘텐츠 파이프라인 자체가 아직 끝나지 않았다
/// (`polyglot-surface` 의 `{#pack-installer}`·`{#lesson-renderer}` 미완). 그래서 카드
/// 앞/뒤 텍스트는 `ReviewCardContentProvider` 뒤에 완전히 숨긴다 — 파이프라인이 끝나면
/// 앱이 그 프로토콜을 구현하는 어댑터(ContentKit 레슨 → 이 타입)를 꽂기만 하면 된다.
///
/// **FSRS 계산과는 무관하다.** 여기 있는 것은 순수 표시 문구이고, 다음 복습 간격은
/// 언제나 `ReviewScheduler.preview(_:at:)` 가 실시간으로 계산한다 — 이 타입에는 간격을
/// 표현할 필드가 아예 없다.
public struct ReviewCardContent: Hashable, Sendable {
    /// "Swift · 레슨 07 값 타입과 참조 타입" 같은 트랙·레슨 라벨.
    public var contextLabel: String
    public var question: String
    public var answer: String
    /// 답 카드 안의 코드 예시. 없으면 그 자리를 그리지 않는다.
    public var codeExample: String?

    public init(
        contextLabel: String,
        question: String,
        answer: String,
        codeExample: String? = nil
    ) {
        self.contextLabel = contextLabel
        self.question = question
        self.answer = answer
        self.codeExample = codeExample
    }
}

/// 카드 콘텐츠 공급자. `ReviewModel` 은 이 프로토콜로만 콘텐츠를 받는다 — 실물 구현은
/// 앱(또는 나중의 ContentKit 어댑터)이 꽂는다.
public protocol ReviewCardContentProvider: Sendable {
    func content(for cardID: CardID) async throws -> ReviewCardContent
}

/// 정적 매핑 기반 구현. 콘텐츠 파이프라인이 없는 지금 프리뷰·테스트·최초 배선에 쓴다.
///
/// 여기서 "정적"인 것은 카드에 붙는 설명 문구뿐이다 — 목 데이터 금지 규칙은 FSRS 스케줄러와
/// 저장소에 적용되는 것이고, 그 둘은 이 타입이 전혀 건드리지 않는다.
public struct StaticReviewCardContentProvider: ReviewCardContentProvider {
    /// 콘텐츠가 없는 카드에 대신 보여줄 안내문. 크래시 대신 이걸 보여준다.
    public static let fallback = ReviewCardContent(
        contextLabel: "카드",
        question: "이 카드의 콘텐츠를 아직 불러오지 못했습니다.",
        answer: "콘텐츠 팩이 연결되면 이 카드의 실제 질문과 답이 표시됩니다."
    )

    private let contents: [CardID: ReviewCardContent]
    private let fallback: ReviewCardContent

    public init(
        contents: [CardID: ReviewCardContent] = [:],
        fallback: ReviewCardContent = StaticReviewCardContentProvider.fallback
    ) {
        self.contents = contents
        self.fallback = fallback
    }

    public func content(for cardID: CardID) async throws -> ReviewCardContent {
        contents[cardID] ?? fallback
    }
}
