import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("mistake_note — FTS5 trigram 검색")
struct MistakeNoteSearchTests {
    /// `{#fts-tokenizer}` — trigram 을 고른 이유가 이 두 케이스다.
    @Test("한국어 부분어를 잡는다", arguments: DatabaseFlavor.allCases)
    func matchesKoreanSubstring(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        try await store.save(Fixture.note(
            title: "클로저 캡처 리스트",
            body: "클로저가 self 를 강하게 캡처하면 순환 참조가 생깁니다"
        ))
        try await store.save(Fixture.note(title: "전혀 다른 노트", body: "리스트 컴프리헨션"))

        // 어절 "캡처하면" 의 **가운데 조각**으로 찾는다. unicode61 은 어절 전체를 하나의 토큰으로
        // 보므로 이 질의를 놓친다. trigram 은 3자 슬라이딩 윈도우라 잡는다.
        let hits = try await store.search("처하면", limit: 10)
        #expect(hits.count == 1)
        #expect(hits.first?.title == "클로저 캡처 리스트")

        // 어절 시작과 끝 조각도 잡힌다.
        #expect(try await store.search("강하게", limit: 10).count == 1)
        #expect(try await store.search("순환 참", limit: 10).count == 1)
    }

    /// trigram 의 대가 — 2자 한국어 단어는 구조적으로 못 찾는다. 알고 쓰는 제약이라 테스트로 못박는다.
    @Test("2자 한국어 단어는 잡히지 않는다 (trigram 의 알려진 한계)", arguments: DatabaseFlavor.allCases)
    func twoSyllableKoreanIsNotSearchable(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await harness.database.mistakeNoteStore.save(Fixture.note(
            title: "캡처 정리",
            body: "클로저가 self 를 캡처 한다"
        ))
        #expect(try await harness.database.mistakeNoteStore.search("캡처", limit: 10).isEmpty)
        #expect(MistakeNoteSearch.minimumQueryLength == 3)
    }

    @Test("snake_case 식별자 조각을 잡는다", arguments: DatabaseFlavor.allCases)
    func matchesSnakeCaseFragment(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        try await store.save(Fixture.note(
            title: "쿼리 실수",
            body: "SELECT * FROM user_account_summary WHERE id = 1"
        ))

        // 토큰 경계가 아닌 중간 조각. unicode61 은 `user_account_summary` 를 통째 토큰으로 본다.
        let hits = try await store.search("account_sum", limit: 10)
        #expect(hits.count == 1)
        #expect(hits.first?.title == "쿼리 실수")
    }

    @Test("3자 미만 질의는 빈 결과다 — trigram 의 구조적 하한", arguments: DatabaseFlavor.allCases)
    func shortQueriesReturnEmpty(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await harness.database.mistakeNoteStore.save(
            Fixture.note(title: "가나다라", body: "가나다라마바사")
        )
        #expect(try await harness.database.mistakeNoteStore.search("가", limit: 10).isEmpty)
        #expect(try await harness.database.mistakeNoteStore.search("가나", limit: 10).isEmpty)
        #expect(try await harness.database.mistakeNoteStore.search("가나다", limit: 10).count == 1)
    }

    /// `{#m004-mistake-note}` — 삽입·수정·삭제 후 검색 결과가 즉시 일관.
    @Test("삽입·수정·삭제 후 검색이 즉시 일관된다", arguments: DatabaseFlavor.allCases)
    func indexStaysConsistent(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore

        let id = try await store.save(Fixture.note(title: "처음 제목", body: "처음 본문 텍스트"))
        #expect(try await store.search("처음 본문", limit: 10).count == 1)

        // 수정 — 옛 본문으로는 더 이상 안 나오고 새 본문으로 나와야 한다.
        var note = try #require(await store.note(id: id))
        note.body = "고쳐 쓴 본문 텍스트"
        note.updatedAt = Fixture.days(1)
        try await store.update(note)

        #expect(try await store.search("처음 본문", limit: 10).isEmpty, "옛 본문이 인덱스에 남아 있다")
        #expect(try await store.search("고쳐 쓴", limit: 10).count == 1)

        // 삭제 — 인덱스에서도 사라져야 한다.
        try await store.delete(id: id)
        #expect(try await store.search("고쳐 쓴", limit: 10).isEmpty)
        #expect(try await store.count() == 0)
        // external content 라 섀도 테이블에도 잔여가 없어야 한다.
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM mistake_note_fts") == 0)
    }

    /// `{#fts-search-api}`
    @Test("bm25 순위 오름차순 = 관련도 내림차순", arguments: DatabaseFlavor.allCases)
    func resultsAreRankedByBM25(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        try await store.save(Fixture.note(
            title: "옵셔널 언래핑",
            body: "옵셔널 옵셔널 옵셔널 옵셔널 을 강제 언래핑하면 크래시"
        ))
        try await store.save(Fixture.note(
            title: "다른 주제",
            body: "여기 어딘가에 옵셔널 이 한 번 나온다"
        ))

        let hits = try await store.search("옵셔널", limit: 10)
        #expect(hits.count == 2)
        // bm25 는 음수이고 작을수록 관련도가 높다.
        #expect(hits[0].rank <= hits[1].rank)
        #expect(hits[0].title == "옵셔널 언래핑")
    }

    @Test("snippet 이 매치 구간을 하이라이트한다", arguments: DatabaseFlavor.allCases)
    func snippetHighlightsMatch(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await harness.database.mistakeNoteStore.save(Fixture.note(
            title: "제네릭 제약",
            body: "where 절에 associatedtype 제약을 붙이는 법을 헷갈렸다"
        ))

        let hit = try #require(await harness.database.mistakeNoteStore
            .search("associatedtype", limit: 1).first)
        #expect(hit.snippet.contains(MistakeNoteSearch.highlightOpen))
        #expect(hit.snippet.contains(MistakeNoteSearch.highlightClose))
        // trigram 토큰 경계라 하이라이트가 질의 전체가 아니라 그 접두 조각을 감쌀 수 있다.
        // UI 가 필요로 하는 것은 "어디쯤인지" 이므로 조각으로 충분하다.
        let highlighted = hit.snippet
            .components(separatedBy: MistakeNoteSearch.highlightOpen)[1]
            .components(separatedBy: MistakeNoteSearch.highlightClose)[0]
        #expect(!highlighted.isEmpty)
        #expect("associatedtype".contains(highlighted), "하이라이트가 질의와 무관하다: \(highlighted)")
        #expect(hit.snippet.contains("where 절"), "주변 문맥이 함께 나와야 한다")
    }

    @Test("FTS5 연산자처럼 보이는 질의도 평문으로 다룬다", arguments: DatabaseFlavor.allCases)
    func queryOperatorsAreEscaped(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        try await store.save(Fixture.note(title: "따옴표", body: #"print("hello") AND NEAR"#))

        // 감싸지 않으면 FTS5 문법 오류로 던진다. 감싸므로 그냥 찾아진다.
        #expect(try await store.search(#""hello""#, limit: 10).count == 1)
        #expect(try await store.search("AND NEAR", limit: 10).count == 1)
        #expect(try await store.search("존재하지 않는 문자열 xyz", limit: 10).isEmpty)
    }

    @Test("구 패턴은 큰따옴표를 이스케이프한다")
    func phrasePatternEscapesQuotes() {
        #expect(GRDBMistakeNoteStore.phrasePattern("plain") == "\"plain\"")
        #expect(GRDBMistakeNoteStore.phrasePattern(#"say "hi""#) == #""say ""hi""""#)
    }

    @Test("검색 결과 개수 상한이 지켜진다", arguments: DatabaseFlavor.allCases)
    func limitIsRespected(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        for index in 0..<10 {
            try await store.save(Fixture.note(title: "노트 \(index)", body: "공통 키워드 반복문"))
        }
        #expect(try await store.search("반복문", limit: 3).count == 3)
        #expect(try await store.search("반복문", limit: 100).count == 10)
    }

    @Test("빈 제목은 CHECK 가 거부한다")
    func emptyTitleIsRejected() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO mistake_note (language_id, title, body, created_at, updated_at)
                VALUES ('python', '', 'body', 1, 1)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    @Test("존재하지 않는 노트 수정은 notFound 다", arguments: DatabaseFlavor.allCases)
    func updatingMissingNoteThrows(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var note = Fixture.note(title: "유령", body: "없는 노트")
        note.id = MistakeNoteID(9_999)
        await #expect(throws: StoreError.self) {
            try await harness.database.mistakeNoteStore.update(note)
        }
    }
}
