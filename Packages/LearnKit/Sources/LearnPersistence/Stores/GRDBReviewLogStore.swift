internal import GRDB
internal import LearnCore

/// `review_log` + `scheduler_parameters`.
///
/// **actor 가 아니라 struct 다.** GRDB 7 의 `DatabaseWriter` 는 이미 `Sendable` 이고 접근 직렬화를
/// 스스로 한다. 여기에 actor 를 씌우면 (1) 호출마다 액터 홉이 하나 더 붙고, (2) 액터 안에서
/// `await write { }` 하는 동안 액터가 재진입 가능해져 "직렬화됐다" 는 착각을 만든다.
/// 실제 직렬성은 GRDB 의 writer 큐가 보장한다.
struct GRDBReviewLogStore: ReviewLogStore {
    let writer: any DatabaseWriter

    @discardableResult
    func append(_ entry: ReviewLogEntry) async throws -> ReviewLogID {
        let ids = try await append(contentsOf: [entry])
        guard let id = ids.first else {
            throw StoreError.storage(message: "append 가 id 를 내지 않았다")
        }
        return id
    }

    @discardableResult
    func append(contentsOf entries: [ReviewLogEntry]) async throws -> [ReviewLogID] {
        guard !entries.isEmpty else { return [] }
        return try await writer.writeMapped { db in
            var ids: [ReviewLogID] = []
            ids.reserveCapacity(entries.count)
            for entry in entries {
                let row = ReviewLogRow(entry)
                try row.insert(db)
                ids.append(ReviewLogID(db.lastInsertedRowID))
            }
            return ids
        }
    }

    func entries(forCard cardID: CardID) async throws -> [ReviewLogEntry] {
        try await writer.readMapped { db in
            // 인덱스 idx_review_log_card_replay(card_id, reviewed_at, id) 를 그대로 탄다.
            try ReviewLogRow
                .fetchAll(db, sql: """
                    SELECT * FROM review_log
                    WHERE card_id = ?
                    ORDER BY reviewed_at, id
                    """, arguments: [cardID.rawValue])
                .map { try $0.toEntry() }
        }
    }

    func entries(after id: ReviewLogID?, limit: Int) async throws -> [ReviewLogEntry] {
        try await writer.readMapped { db in
            try ReviewLogRow
                .fetchAll(db, sql: """
                    SELECT * FROM review_log
                    WHERE id > ?
                    ORDER BY id
                    LIMIT ?
                    """, arguments: [id?.rawValue ?? 0, max(0, limit)])
                .map { try $0.toEntry() }
        }
    }

    func lastEntryID(forCard cardID: CardID) async throws -> ReviewLogID? {
        try await writer.readMapped { db in
            try Int64.fetchOne(
                db,
                sql: "SELECT MAX(id) FROM review_log WHERE card_id = ?",
                arguments: [cardID.rawValue]
            ).map { ReviewLogID($0) }
        }
    }

    func count() async throws -> Int {
        try await writer.readMapped { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_log") ?? 0
        }
    }

    func count(from: EpochMillis, to: EpochMillis) async throws -> Int {
        try await writer.readMapped { db in
            // 반열린 구간 [from, to). 인덱스 idx_review_log_reviewed_at 를 탄다.
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM review_log WHERE reviewed_at >= ? AND reviewed_at < ?",
                arguments: [from.sqlValue, to.sqlValue]
            ) ?? 0
        }
    }

    func activeParameterSet() async throws -> SchedulerParameterSet {
        try await writer.readMapped { db in
            guard let row = try SchedulerParameterRow.fetchOne(
                db,
                sql: "SELECT * FROM scheduler_parameters WHERE is_active = 1"
            ) else {
                // 부분 유니크 인덱스가 상한을, 마이그레이션 001 의 시드가 하한을 지킨다.
                // 여기 도달했다면 누군가 활성 세트를 내리고 새로 올리지 않은 것이다.
                throw StoreError.notFound(entity: "scheduler_parameters", id: "active")
            }
            return try row.toParameterSet()
        }
    }

    func parameterSet(id: ParameterSetID) async throws -> SchedulerParameterSet? {
        try await writer.readMapped { db in
            try SchedulerParameterRow.fetchOne(
                db,
                sql: "SELECT * FROM scheduler_parameters WHERE id = ?",
                arguments: [id.rawValue]
            )?.toParameterSet()
        }
    }

    func save(parameterSet: SchedulerParameterSet, activate: Bool) async throws {
        try await writer.writeMapped { db in
            var set = parameterSet
            set.isActive = activate || parameterSet.isActive
            if set.isActive {
                // 부분 유니크 인덱스 때문에 내리기와 올리기가 **같은 문장 순서**로 일어나야 한다.
                // 트랜잭션 안이라 중간 상태(활성 0개)가 밖에서 관측되지 않는다.
                try db.execute(
                    sql: "UPDATE scheduler_parameters SET is_active = 0 WHERE is_active = 1 AND id <> ?",
                    arguments: [set.id.rawValue]
                )
            }
            try SchedulerParameterRow(set).save(db)

            // 상한은 부분 유니크 인덱스가 지키지만 **하한은 아무도 안 지킨다** — 활성 세트를
            // 내리기만 하는 호출이 0개를 만들 수 있다. 트랜잭션 안에서 던지면 통째로 롤백된다.
            let activeCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM scheduler_parameters WHERE is_active = 1"
            ) ?? 0
            guard activeCount == 1 else {
                throw StoreError.constraint(
                    message: "활성 파라미터 세트는 정확히 하나여야 한다 (시도 결과 \(activeCount)개)"
                )
            }
        }
    }

    func observeCount() -> AsyncThrowingStream<Int, any Error> {
        makeObservationStream(reader: writer) { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_log") ?? 0
        }
    }
}
