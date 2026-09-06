/// 오답 노트 한 건. 본문은 사용자가 쓴 산문이고, 검색은 FTS5 섀도 테이블이 담당한다.
public struct MistakeNote: Hashable, Sendable, Codable {
    public var id: MistakeNoteID?
    /// 복습 카드와 이어진 노트. 카드 없이 자유롭게 쓴 노트는 nil.
    public var cardID: CardID?
    public var languageID: LanguageID
    public var packID: PackID?
    public var lessonID: LessonID?
    public var title: String
    public var body: String
    public var createdAt: EpochMilliseconds
    public var updatedAt: EpochMilliseconds

    public init(
        id: MistakeNoteID? = nil,
        cardID: CardID? = nil,
        languageID: LanguageID,
        packID: PackID? = nil,
        lessonID: LessonID? = nil,
        title: String,
        body: String,
        createdAt: EpochMilliseconds,
        updatedAt: EpochMilliseconds
    ) {
        self.id = id
        self.cardID = cardID
        self.languageID = languageID
        self.packID = packID
        self.lessonID = lessonID
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 검색 결과 한 건.
///
/// GRDB `Row` 는 `read` 클로저 밖으로 나가지 못하므로 스토어가 클로저 안에서 이 값 타입으로 옮긴다.
public struct MistakeNoteSearchHit: Hashable, Sendable {
    public var noteID: MistakeNoteID
    public var title: String
    /// `snippet()` 이 만든 하이라이트 조각. 매치 구간이 `MistakeNoteSearch.highlightOpen`/`Close` 로 감싸진다.
    public var snippet: String
    /// SQLite `bm25()` 점수. **작을수록(더 음수일수록) 관련도가 높다** — 부호 규약이 뒤집혀 있다.
    public var rank: Double

    public init(noteID: MistakeNoteID, title: String, snippet: String, rank: Double) {
        self.noteID = noteID
        self.title = title
        self.snippet = snippet
        self.rank = rank
    }
}

/// 검색 표면의 상수. UI 가 하이라이트를 파싱해야 하므로 계약으로 고정한다.
public enum MistakeNoteSearch {
    public static let highlightOpen = "\u{2039}"   // ‹
    public static let highlightClose = "\u{203A}"  // ›
    public static let ellipsis = "\u{2026}"        // …

    /// trigram 토크나이저의 하한. 2자 이하 질의는 FTS5 가 아무것도 매치하지 못한다.
    ///
    /// trigram 을 고른 이유는 한국어 부분어("하세요")와 `snake_case` 조각("case_id")을 **둘 다**
    /// 잡아야 하기 때문이다. unicode61 은 공백·구두점으로만 끊어 둘 다 놓친다.
    /// 대가가 이 하한이다 — 스토어는 짧은 질의를 빈 결과로 조기 반환한다.
    public static let minimumQueryLength = 3
}
