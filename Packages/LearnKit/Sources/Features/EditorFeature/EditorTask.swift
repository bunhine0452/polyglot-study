public import Foundation
public import LearnCore
public import RunnerKit

/// 에디터 화면 하나가 그릴 과제. 레슨 콘텐츠(팩)에서 조립돼 들어오는 값이고, 화면은
/// 이 타입만 본다.
///
/// **콘텐츠 팩 로더가 여기 없다.** 팩 매니페스트에 SQL 샘플 DB 를 싣는 자원 카테고리
/// (`{#pack-format-spec}`)가 아직 확정 전이라, `TaskBlock` → `EditorTask` 변환은 그
/// 스펙이 정해진 뒤 앱 계층이 맡는다. 지금 이 타입은 화면과 채점기가 실제로 필요로
/// 하는 필드만 든 평범한 값 타입이다 — 목 데이터를 만드는 자리가 아니라, 아직 없는
/// 로더를 앞질러 짓지 않는 경계선이다.
///
/// `nonisolated` — 이 값은 `EditorGraderFactory`·`EditorRunFactory`(둘 다 `@Sendable`)
/// 로 건너간다. 모듈 기본 격리가 `MainActor` 라 이 표시가 없으면 그 클로저 안에서
/// 필드 하나 읽는 것조차 격리 경계를 넘지 못한다(`LessonContent` 가 같은 이유로
/// `nonisolated` 다).
public nonisolated struct EditorTask: Sendable {
    /// 헤더의 `Swift · 레슨 07 / 24`.
    public var trackCaption: String
    public var lessonTitle: String
    /// 헤더 오른쪽의 `블록 4 / 6 · 테스트 과제`.
    public var blockCaption: String
    /// 과제 바의 `04 테스트 과제`.
    public var taskOrdinalLabel: String
    /// 과제 바의 설명. 인라인 마크다운(``·강조)만 기대한다 — 블록 서식은 없다.
    public var prose: String
    public var language: LanguageID
    /// 워크스페이스 안에서 이 소스가 갖는 파일 이름 (`main.swift`, `query.sql`).
    public var entryFileName: String
    public var starterSource: String

    /// Swift·Python: 숨은 테스트 소스. SQL 은 결과셋 비교로 채점하므로 쓰지 않는다.
    public var testSource: String?
    /// SQL: 참조 해답. 다른 언어는 숨은 테스트로 채점하므로 쓰지 않는다.
    public var solutionSource: String?
    /// SQL: 채점 대상이 되는 읽기 전용 샘플 DB. 다른 언어는 nil.
    public var database: URL?
    /// SQL: 열 매칭·순서 요구 등 채점 기준.
    public var criteria: SQLGradingCriteria
    /// "테스트 N개 통과 시 완료" 라벨의 N. 0이면 그 라벨을 그리지 않는다.
    public var testCount: Int
    /// SQL 결과 화면 하단, 고정 캡션 위에 붙는 문제별 해설. 콘텐츠 팩이 아직 이
    /// 필드를 채울 경로가 없어 지금은 항상 nil 이지만, 화면은 이미 자리를 갖고 있다.
    public var resultHint: String?

    public init(
        trackCaption: String,
        lessonTitle: String,
        blockCaption: String,
        taskOrdinalLabel: String,
        prose: String,
        language: LanguageID,
        entryFileName: String,
        starterSource: String,
        testSource: String? = nil,
        solutionSource: String? = nil,
        database: URL? = nil,
        criteria: SQLGradingCriteria = .unordered,
        testCount: Int = 0,
        resultHint: String? = nil
    ) {
        self.trackCaption = trackCaption
        self.lessonTitle = lessonTitle
        self.blockCaption = blockCaption
        self.taskOrdinalLabel = taskOrdinalLabel
        self.prose = prose
        self.language = language
        self.entryFileName = entryFileName
        self.starterSource = starterSource
        self.testSource = testSource
        self.solutionSource = solutionSource
        self.database = database
        self.criteria = criteria
        self.testCount = testCount
        self.resultHint = resultHint
    }
}
