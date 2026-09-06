internal import GRDB
internal import LearnCore

/// `card_state` — 파생 캐시.
struct GRDBCardStateStore: CardStateStore {
    let writer: any DatabaseWriter

    func snapshot(forCard cardID: CardID) async throws -> CardStateSnapshot? {
        try await writer.readMapped { db in
            try CardStateRow.fetchOne(
                db,
                sql: "SELECT * FROM card_state WHERE card_id = ?",
                arguments: [cardID.rawValue]
            )?.toSnapshot()
        }
    }

    func upsert(_ snapshot: CardStateSnapshot) async throws {
        try await writer.writeMapped { db in
            try CardStateRow(snapshot).save(db)
        }
    }

    func count() async throws -> Int {
        try await writer.readMapped { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM card_state") ?? 0
        }
    }

    /// 파생 재구축 관용구 — DELETE 전량 → 삽입 전량을 **한 트랜잭션**으로.
    ///
    /// 도중 실패하면 롤백되어 기존 캐시가 그대로 남는다. 반쯤 재구축된 캐시가 관측되면
    /// due 큐가 조용히 카드를 빠뜨리는데, 그건 사용자가 알아채기까지 며칠 걸리는 종류의 버그다.
    func replaceAll(with snapshots: [CardStateSnapshot]) async throws {
        try await writer.writeMapped { db in
            try DerivedRebuild.perform(in: db) { db in
                try db.execute(sql: "DELETE FROM card_state")
                for snapshot in snapshots {
                    try CardStateRow(snapshot).insert(db)
                }
            }
        }
    }

    func deleteAll() async throws {
        try await writer.writeMapped { db in
            try DerivedRebuild.perform(in: db) { db in
                try db.execute(sql: "DELETE FROM card_state")
            }
        }
    }

    func dueCards(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis,
        limit: Int
    ) async throws -> [CardStateSnapshot] {
        try await writer.readMapped { db in
            // idx_card_state_due(language_id, due_at) 를 탄다 — 언어로 먼저 좁히고 due_at 순으로 훑는다.
            try CardStateRow
                .fetchAll(db, sql: """
                    SELECT * FROM card_state
                    WHERE language_id = ? AND due_at <= ?
                    ORDER BY due_at, card_id
                    LIMIT ?
                    """, arguments: [languageID.rawValue, dueAtOrBefore.sqlValue, max(0, limit)])
                .map { try $0.toSnapshot() }
        }
    }

    func staleCards(limit: Int) async throws -> [CardStaleness] {
        try await writer.readMapped { db in
            try Row
                .fetchAll(db, sql: """
                    SELECT card_id, language_id, parameter_drift, log_drift
                    FROM card_state_stale
                    WHERE parameter_drift = 1 OR log_drift = 1
                    ORDER BY card_id
                    LIMIT ?
                    """, arguments: [max(0, limit)])
                .map { row in
                    // Row 는 이 클로저 밖으로 나가지 않는다 — 값 타입으로 옮겨서 내보낸다.
                    CardStaleness(
                        cardID: CardID(row["card_id"]),
                        languageID: LanguageID(row["language_id"]),
                        parameterDrift: row["parameter_drift"],
                        logDrift: row["log_drift"]
                    )
                }
        }
    }

    func staleCount() async throws -> Int {
        try await writer.readMapped { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM card_state_stale
                WHERE parameter_drift = 1 OR log_drift = 1
                """) ?? 0
        }
    }

    func observeDueCount(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis
    ) -> AsyncThrowingStream<Int, any Error> {
        let language = languageID.rawValue
        return makeObservationStream(reader: writer) { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM card_state WHERE language_id = ? AND due_at <= ?",
                arguments: [language, dueAtOrBefore.sqlValue]
            ) ?? 0
        }
    }
}
