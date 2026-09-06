internal import GRDB
internal import LearnCore

/// `mistake_note` + `mistake_note_fts`.
///
/// FTS 테이블을 직접 쓰는 코드는 여기 없다. external content + synchronize 트리거라
/// 원본 테이블만 갱신하면 인덱스가 따라온다 — 두 곳에 쓰는 코드가 있으면 반드시 언젠가 어긋난다.
struct GRDBMistakeNoteStore: MistakeNoteStore {
    let writer: any DatabaseWriter

    @discardableResult
    func save(_ note: MistakeNote) async throws -> MistakeNoteID {
        try await writer.writeMapped { db in
            var row = MistakeNoteRow(note)
            if let id = note.id {
                try row.save(db)
                return id
            }
            row.id = nil
            try row.insert(db)
            return MistakeNoteID(db.lastInsertedRowID)
        }
    }

    func update(_ note: MistakeNote) async throws {
        guard let id = note.id else {
            throw StoreError.notFound(entity: "mistake_note", id: "nil")
        }
        try await writer.writeMapped { db in
            // update(_:) 는 대상 행이 없으면 RecordError.recordNotFound 를 던진다.
            // mapDatabaseError 가 그것을 StoreError.notFound 로 옮긴다.
            do {
                try MistakeNoteRow(note).update(db)
            } catch is RecordError {
                throw StoreError.notFound(entity: "mistake_note", id: "\(id.rawValue)")
            }
        }
    }

    func delete(id: MistakeNoteID) async throws {
        try await writer.writeMapped { db in
            try db.execute(
                sql: "DELETE FROM mistake_note WHERE id = ?",
                arguments: [id.rawValue]
            )
        }
    }

    func note(id: MistakeNoteID) async throws -> MistakeNote? {
        try await writer.readMapped { db in
            try MistakeNoteRow.fetchOne(
                db,
                sql: "SELECT * FROM mistake_note WHERE id = ?",
                arguments: [id.rawValue]
            )?.toNote()
        }
    }

    func count() async throws -> Int {
        try await writer.readMapped { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mistake_note") ?? 0
        }
    }

    func search(_ query: String, limit: Int) async throws -> [MistakeNoteSearchHit] {
        let trimmed = query.trimmingWhitespace()
        // trigram 은 3자 미만을 색인하지 않는다. 여기서 걸러야 사용자가 "왜 아무것도 안 나오지" 대신
        // 빈 결과를 명시적 상태로 보게 된다.
        guard trimmed.count >= MistakeNoteSearch.minimumQueryLength else { return [] }
        let pattern = Self.phrasePattern(trimmed)

        return try await writer.readMapped { db in
            // bm25 는 **작을수록 관련도가 높다**(음수). 그래서 ORDER BY 가 오름차순이다.
            // fts5 가 예약한 `rank` 컬럼명과 부딪히지 않게 별칭을 bm25_rank 로 둔다.
            try Row.fetchAll(db, sql: """
                SELECT
                    n.id AS note_id,
                    n.title AS title,
                    snippet(mistake_note_fts, 1, '\(MistakeNoteSearch.highlightOpen)', \
                '\(MistakeNoteSearch.highlightClose)', '\(MistakeNoteSearch.ellipsis)', 12) AS snippet,
                    bm25(mistake_note_fts) AS bm25_rank
                FROM mistake_note_fts
                JOIN mistake_note n ON n.rowid = mistake_note_fts.rowid
                WHERE mistake_note_fts MATCH ?
                ORDER BY bm25_rank, n.id
                LIMIT ?
                """, arguments: [pattern, max(0, limit)])
                .map { row in
                    // GRDB Row 는 이 클로저 밖으로 나가지 않는다.
                    MistakeNoteSearchHit(
                        noteID: MistakeNoteID(row["note_id"]),
                        title: row["title"],
                        snippet: row["snippet"] ?? "",
                        rank: row["bm25_rank"]
                    )
                }
        }
    }

    /// 질의를 FTS5 **구(phrase)** 로 감싼다.
    ///
    /// 감싸지 않으면 사용자가 친 `AND`·`OR`·`NEAR`·`*`·`:` 가 FTS5 쿼리 문법으로 해석되어
    /// 문법 오류를 던지거나 엉뚱한 걸 찾는다. 오답 노트 검색은 문법 언어가 아니라
    /// "이 문자열이 들어간 노트" 다. 내부 큰따옴표는 두 개로 이스케이프한다.
    static func phrasePattern(_ query: String) -> String {
        "\"" + query.replacing("\"", with: "\"\"") + "\""
    }

    func observeCount() -> AsyncThrowingStream<Int, any Error> {
        makeObservationStream(reader: writer) { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mistake_note") ?? 0
        }
    }
}

extension String {
    func trimmingWhitespace() -> String {
        var result = self[...]
        while let first = result.first, first.isWhitespace { result = result.dropFirst() }
        while let last = result.last, last.isWhitespace { result = result.dropLast() }
        return String(result)
    }
}
