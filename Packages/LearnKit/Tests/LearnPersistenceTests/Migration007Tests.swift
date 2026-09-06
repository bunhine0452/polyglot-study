import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// 마이그레이션 007 — `card_state` 테이블 재생성.
///
/// ## 이 스위트가 실제로 지키는 것
///
/// 재생성은 **빠뜨리기 쉬운 변경**이다. 새 `CREATE TABLE` 을 손으로 베끼는 동안 컬럼 하나,
/// 인덱스 하나, `DEFAULT` 하나가 조용히 사라져도 앱은 한동안 멀쩡히 돌고, 그 사이 사용자
/// DB 는 이미 갈라져 있다. 그래서 "눈으로 확인했다" 로는 부족하고, **006 직후와 007 직후의
/// 스키마를 실제로 뽑아 비교**한다.
///
/// 비교는 두 각도에서 한다.
///
/// 1. **card_state 밖은 바이트로.** 스키마 덤프에서 `card_state` 테이블 정의만 도려낸 나머지가
///    한 글자도 다르지 않아야 한다 — 인덱스 둘과 `card_state_stale` 뷰가 원문 그대로
///    되살아났는지, 다른 테이블·트리거가 유탄을 맞지 않았는지가 여기서 잡힌다.
/// 2. **card_state 안은 구조로.** 테이블 본문은 텍스트가 다를 수밖에 없다 — 006 은
///    `ALTER TABLE ADD COLUMN` 이 이어붙인 한 줄이고 007 은 손으로 쓴 여러 줄이다. 그래서
///    `PRAGMA table_info`·`index_list`·`index_xinfo`·`foreign_key_list` 로 **구조**를 뽑아
///    비교하고, CHECK 제약은 이름→식 사전으로 비교한다. 달라도 되는 것은 `difficulty` 의
///    CHECK 하나뿐이다.
@Suite("마이그레이션 007 — 신규 카드의 난이도 센티널")
struct Migration007Tests {
    private static let before = "006-card-state-scheduling"

    /// 006 까지만 적용된 DB 와, 거기에 007 을 마저 적용하는 클로저.
    private func at006() throws -> LearnDatabase {
        try LearnDatabase.inMemory(upTo: Self.before)
    }

    // MARK: - 스키마 동일성

    @Test("재생성이 card_state 밖의 스키마를 한 글자도 바꾸지 않는다")
    func everythingOutsideCardStateIsByteIdentical() throws {
        let database = try at006()
        let dumpBefore = try database.schemaDump()
        try database.applyRemainingMigrations()
        let dumpAfter = try database.schemaDump()

        // 인덱스 둘과 뷰 하나는 002·006 의 원문을 그대로 되살렸으므로 바이트로 남아 있어야 한다.
        #expect(dumpBefore.contains("CREATE INDEX idx_card_state_due"))
        #expect(dumpAfter.contains("CREATE VIEW card_state_stale AS"))

        #expect(
            Self.excisingCardStateTable(dumpAfter) == Self.excisingCardStateTable(dumpBefore),
            """
            card_state 테이블 정의 말고 다른 것이 바뀌었다. 재생성이 인덱스·뷰·다른 테이블을 \
            건드렸다는 뜻이다.
            """
        )
    }

    @Test("재생성 전후로 컬럼 정의가 완전히 같다")
    func columnsSurviveRecreation() throws {
        let database = try at006()
        let columnsBefore = try database.rawRowStrings("PRAGMA table_info(card_state)")
        try database.applyRemainingMigrations()
        let columnsAfter = try database.rawRowStrings("PRAGMA table_info(card_state)")

        // cid·name·type·notnull·dflt_value·pk 가 전부 들어 있다 — 순서와 DEFAULT 까지 같아야 한다.
        #expect(columnsAfter == columnsBefore)
        #expect(columnsBefore.count == 15, "컬럼 수가 15개가 아니다: \(columnsBefore.count)")
    }

    @Test("재생성 전후로 인덱스가 이름·컬럼·유일성까지 같다")
    func indexesSurviveRecreation() throws {
        let database = try at006()
        let before = try Self.indexShape(of: database)
        try database.applyRemainingMigrations()
        let after = try Self.indexShape(of: database)

        #expect(after == before)
        #expect(before.contains { $0.contains("idx_card_state_due") })
        #expect(before.contains { $0.contains("idx_card_state_queue") })
    }

    @Test("재생성 전후로 외래키가 같다 — 대상 테이블·컬럼·ON DELETE 까지")
    func foreignKeysSurviveRecreation() throws {
        let database = try at006()
        let before = try database.rawRowStrings("PRAGMA foreign_key_list(card_state)")
        try database.applyRemainingMigrations()
        let after = try database.rawRowStrings("PRAGMA foreign_key_list(card_state)")

        #expect(after == before)
        #expect(before.count == 2, "review_log 와 scheduler_parameters 두 개여야 한다: \(before)")
        #expect(before.allSatisfy { $0.contains("on_delete=\"RESTRICT\"") }, "\(before)")
    }

    @Test("STRICT 가 유지된다")
    func tableStaysStrict() throws {
        let database = try at006()
        try database.applyRemainingMigrations()
        #expect(try Self.cardStateSQL(of: database).hasSuffix(") STRICT"))

        // 실측 — STRICT 가 아니면 SQLite 가 문자열을 REAL 컬럼에 넣어 준다.
        #expect(throws: RawSQLFailure.self) {
            try database.executeRaw("""
                INSERT INTO card_state
                    (card_id, language_id, stability, difficulty, due_at, state,
                     reps, lapses, scheduled_days, parameter_set_id, rebuilt_at)
                VALUES ('c', 'python', 1.0, 'not-a-number', 1, 'review', 0, 0, 0, 'fsrs6-default', 1)
                """)
        }
    }

    @Test("CHECK 은 difficulty 하나만 넓어지고 나머지 넷은 글자까지 그대로다")
    func onlyTheDifficultyCheckChanges() throws {
        let database = try at006()
        let before = try Self.checkConstraints(of: database)
        try database.applyRemainingMigrations()
        let after = try Self.checkConstraints(of: database)

        #expect(before.count == after.count, "제약 개수가 달라졌다: \(before.keys) → \(after.keys)")

        // 002·006 의 나머지 제약은 이름도 식도 그대로다.
        for name in [
            "chk_card_state_state",
            "chk_card_state_stability",
            "chk_card_state_counters",
            "chk_card_state_last_reviewed",
            "chk_card_state_elapsed_days",
            "chk_card_state_learning_step",
        ] {
            #expect(after[name] == before[name], "\(name) 이 바뀌었다: \(before[name] ?? "없음") → \(after[name] ?? "없음")")
            #expect(before[name] != nil, "\(name) 이 006 에 없다")
        }

        // 바뀐 것은 정확히 하나다.
        #expect(before["chk_card_state_difficulty"] == "(difficulty >= 1.0 AND difficulty <= 10.0)")
        #expect(after["chk_card_state_difficulty"] == nil, "옛 이름이 남아 있다")
        #expect(
            after["chk_card_state_difficulty_unrated_or_1_to_10"]
                == "(difficulty = 0.0 OR (difficulty >= 1.0 AND difficulty <= 10.0))"
        )

        // 센티널의 뜻이 스키마만 봐도 읽혀야 한다 — 주석은 sqlite_master 에 원문 그대로 남는다.
        #expect(try Self.cardStateSQL(of: database).contains("센티널"))
    }

    // MARK: - 데이터

    @Test("재생성이 기존 행을 값 그대로 옮긴다")
    func rowsSurviveRecreation() throws {
        let database = try at006()
        try database.executeRaw("""
            INSERT INTO card_state
                (card_id, language_id, stability, difficulty, due_at, last_reviewed_at, state,
                 reps, lapses, scheduled_days, derived_from_log_id, parameter_set_id, rebuilt_at,
                 elapsed_days, learning_step_index)
            VALUES
                ('py-1', 'python', 3.5, 5.25, 100, 50, 'review', 2, 0, 3, NULL, 'fsrs6-default', 7, 3, 0),
                ('sql-1', 'sql', 0.0, 1.0, 200, NULL, 'learning', 1, 1, 0, NULL, 'fsrs6-default', 8, 0, 2)
            """)
        let before = try database.rawRowStrings("SELECT * FROM card_state ORDER BY card_id")

        try database.applyRemainingMigrations()

        #expect(try database.rawRowStrings("SELECT * FROM card_state ORDER BY card_id") == before)
        #expect(try database.scalarInt("SELECT COUNT(*) FROM card_state") == 2)
    }

    @Test("재생성이 review_log 를 건드리지 않는다")
    func reviewLogIsUntouched() throws {
        let database = try at006()
        try database.executeRaw("""
            INSERT INTO review_log
                (card_id, reviewed_at, rating, state_before, elapsed_days, scheduled_days,
                 review_duration_ms, scheduler_id, parameter_set_id, source)
            VALUES ('py-1', 100, 3, 'new', 0, 0, 1200, 'fsrs6', 'fsrs6-default', 'scheduled')
            """)
        try database.applyRemainingMigrations()
        #expect(try database.scalarInt("SELECT COUNT(*) FROM review_log") == 1)
        // append-only 봉인도 살아 있어야 한다.
        #expect(throws: RawSQLFailure.self) {
            try database.executeRaw("DELETE FROM review_log")
        }
    }

    // MARK: - 결함 자체

    /// 이 마이그레이션이 존재하는 이유. 006 에서는 실패하고 007 에서는 성공한다.
    @Test("신규 카드의 난이도 0 은 006 에서 거부되고 007 에서 통과한다")
    func theDefectAndItsFix() throws {
        let newCardInsert = """
            INSERT INTO card_state
                (card_id, language_id, stability, difficulty, due_at, state,
                 reps, lapses, scheduled_days, parameter_set_id, rebuilt_at)
            VALUES ('py-new', 'python', 0.0, 0.0, 100, 'new', 0, 0, 0, 'fsrs6-default', 1)
            """

        let database = try at006()
        let failure = #expect(throws: RawSQLFailure.self) {
            try database.executeRaw(newCardInsert)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
        #expect(failure?.message.contains("chk_card_state_difficulty") == true, "\(failure?.message ?? "")")

        try database.applyRemainingMigrations()
        try database.executeRaw(newCardInsert)
        #expect(try database.scalarInt("SELECT COUNT(*) FROM card_state WHERE difficulty = 0.0") == 1)
    }

    // MARK: - 도구

    /// 덤프에서 `card_state` 테이블 정의만 도려낸다. 나머지는 바이트로 비교 가능하다.
    private static func excisingCardStateTable(_ dump: String) -> String {
        guard let start = dump.range(of: "CREATE TABLE card_state (") else { return dump }
        guard let end = dump.range(of: ") STRICT;\n", range: start.upperBound..<dump.endIndex) else {
            return dump
        }
        return dump.replacingCharacters(in: start.lowerBound..<end.upperBound, with: "")
    }

    /// `sqlite_master` 에 저장된 `card_state` 의 CREATE 문 원문.
    private static func cardStateSQL(of database: LearnDatabase) throws -> String {
        let rows = try database.rawRowStrings(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'card_state'"
        )
        guard let row = rows.first else {
            Issue.record("sqlite_master 에 card_state 가 없다")
            return ""
        }
        // `sql="CREATE TABLE …"` 형태로 온다. 앞의 `sql=` 과 양쪽 따옴표를 벗긴다.
        var sql = String(row.dropFirst("sql=".count))
        if sql.hasPrefix("\"") { sql.removeFirst() }
        if sql.hasSuffix("\"") { sql.removeLast() }
        return sql
    }

    /// 인덱스 이름 → (유일성·origin·partial, 키 컬럼 구성).
    private static func indexShape(of database: LearnDatabase) throws -> [String] {
        let list = try database.rawRowStrings("PRAGMA index_list(card_state)").sorted()
        var shape: [String] = []
        for entry in list {
            shape.append(entry)
            guard let name = Self.indexName(in: entry) else { continue }
            shape += try database.rawRowStrings("PRAGMA index_xinfo(\(name))").map { "  \(name): \($0)" }
        }
        return shape
    }

    private static func indexName(in listRow: String) -> String? {
        // `seq=0 name="idx_card_state_due" unique=0 …`
        guard let range = listRow.range(of: "name=\"") else { return nil }
        let rest = listRow[range.upperBound...]
        guard let close = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<close])
    }

    /// CREATE 문에서 `CONSTRAINT <이름> CHECK (<식>)` 을 전부 뽑아 이름 → 식 사전으로.
    ///
    /// 괄호 균형을 세므로 `CHECK (a OR (b AND c))` 같은 중첩도 통째로 잡힌다. 식은 공백을
    /// 하나로 눌러 비교하므로 줄바꿈·들여쓰기 차이는 무시된다 — 006 의 한 줄짜리 정의와
    /// 007 의 여러 줄짜리 정의를 견줄 수 있어야 하기 때문이다.
    private static func checkConstraints(of database: LearnDatabase) throws -> [String: String] {
        let characters = Array(try cardStateSQL(of: database))
        let marker = Array("CONSTRAINT ")
        var result: [String: String] = [:]
        var index = 0

        while index + marker.count <= characters.count {
            guard Array(characters[index..<(index + marker.count)]) == marker else {
                index += 1
                continue
            }
            var cursor = index + marker.count
            var name = ""
            while cursor < characters.count,
                  characters[cursor].isLetter || characters[cursor].isNumber || characters[cursor] == "_" {
                name.append(characters[cursor])
                cursor += 1
            }
            // 이름과 여는 괄호 사이에는 공백과 `CHECK` 뿐이다.
            while cursor < characters.count, characters[cursor] != "(" { cursor += 1 }
            guard cursor < characters.count else { break }

            var depth = 0
            var expression = ""
            while cursor < characters.count {
                let character = characters[cursor]
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                expression.append(character)
                cursor += 1
                if depth == 0 { break }
            }
            result[name] = expression.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            index = cursor
        }
        return result
    }
}
