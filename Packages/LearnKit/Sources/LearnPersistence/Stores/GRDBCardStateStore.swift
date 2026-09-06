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

    /// 오늘의 복습 큐. `{#queue-mixing}` `{#due-queue-benchmark}`
    ///
    /// **혼합과 상한이 전부 이 SQL 안에 있다.** 앱 계층은 결과를 그대로 쓴다.
    ///
    /// ## 구조
    ///
    /// `done` 이 오늘 큐로 푼 카드를 갈래별로 세고, 세 개의 버킷 CTE 가 각자의 남은 몫만큼
    /// 카드를 뽑고, 마지막 SELECT 가 우선순위 → due → card_id 순으로 합친다. 버킷마다
    /// `WHERE language_id = ? AND state = ? AND due_at <= ?` + `ORDER BY due_at, card_id` 는
    /// `idx_card_state_queue(language_id, state, due_at, card_id)` 의 접두사와 정확히 같은
    /// 모양이라 **커버링 인덱스 구간 하나**가 되고, `LIMIT` 이 거기서 곧바로 멈춘다. 22.8만 행에서
    /// 50장을 뽑는 데 전체 스캔이 없는 이유가 이것이다 (`DueQueueBenchmarkTests` 가 실측한다).
    ///
    /// ## 왜 `LIMIT` 안에 서브쿼리를 넣는가
    ///
    /// 남은 몫(`몫 - 오늘 한 개수`)을 Swift 에서 계산해 넘기려면 `done` 을 세는 쿼리를 따로
    /// 한 번 돌려야 하고, 그 두 쿼리 사이에 리뷰가 하나 들어오면 상한이 하루에 한 장씩 샌다.
    /// SQLite 의 `LIMIT` 은 임의 표현식을 받으므로 같은 스냅샷 안에서 계산하는 편이 정확하다.
    func queue(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) async throws -> [DueQueueEntry] {
        let arguments = Self.queueArguments(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: policy
        )
        return try await writer.readMapped { db in
            try Row
                .fetchAll(db, sql: Self.queueSQL, arguments: arguments)
                .map { row in
                    let bucketValue: Int = row["bucket"]
                    guard let bucket = DueQueueBucket(rawValue: bucketValue) else {
                        throw StoreError.storage(message: "큐 버킷 값이 도메인 밖이다: \(bucketValue)")
                    }
                    return DueQueueEntry(snapshot: try CardStateRow(row: row).toSnapshot(), bucket: bucket)
                }
        }
    }

    /// 같은 SQL 을 같은 인자로 `EXPLAIN QUERY PLAN` 한다.
    ///
    /// 플랜 단언이 프로덕션 쿼리와 갈라지지 않도록 **문자열도 인자도 공유**한다 —
    /// 테스트가 손으로 베낀 SQL 을 검사하면 진짜 쿼리가 인덱스를 놓쳐도 초록이 나온다.
    func queryPlan(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) throws -> [String] {
        let arguments = Self.queueArguments(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: policy
        )
        return try writer.read { db in
            try Row
                .fetchAll(db, sql: "EXPLAIN QUERY PLAN \(Self.queueSQL)", arguments: arguments)
                .map { $0["detail"] ?? "" }
        }
    }

    private static func queueArguments(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) -> StatementArguments {
        [
            "lang": languageID.rawValue,
            "now": now.sqlValue,
            "dayStart": studyDayStart.sqlValue,
            "queueSource": ReviewLogSource.review.sqlText,
            "learningState": CardPhase.learning.sqlText,
            "relearningState": CardPhase.relearning.sqlText,
            "reviewState": CardPhase.review.sqlText,
            "newState": CardPhase.new.sqlText,
            "sessionLimit": policy.sessionLimit,
            "reviewAllowance": policy.reviewAllowance,
            "newAllowance": policy.newAllowance,
        ]
    }

    /// `queue(languageID:now:studyDayStart:policy:)` 의 SQL.
    ///
    /// 이름 있는 파라미터를 쓰는 이유는 같은 값(`:lang`·`:now`·`:sessionLimit`)이 여러 버킷에서
    /// 되풀이되기 때문이다. `?` 로 두면 19자리를 텍스트 순서대로 맞춰야 하고, CTE 를 하나
    /// 끼워 넣는 순간 조용히 어긋난다.
    static let queueSQL = """
        WITH
            done AS (
                -- 오늘 큐로 푼 카드 수. 같은 카드를 학습 스텝으로 여러 번 풀어도 한 장이다.
                -- `state_before` 로 갈래를 나누는 이유: 오늘 아침 신규로 꺼낸 카드는 지금
                -- learning 이지만 소비한 것은 신규 몫이다. relearning 스텝은 그 카드가
                -- review 였을 때 이미 세었으므로 다시 세지 않는다.
                -- `source` 를 큐 리뷰로 한정하는 이유는 몰아보기가 오늘 예산을 갉아먹으면 안 되기 때문.
                SELECT
                    COUNT(DISTINCT CASE WHEN rl.state_before = 'new' THEN rl.card_id END) AS new_done,
                    COUNT(DISTINCT CASE WHEN rl.state_before = 'review' THEN rl.card_id END) AS review_done
                FROM review_log rl
                JOIN card_state cs ON cs.card_id = rl.card_id
                WHERE rl.reviewed_at >= :dayStart AND rl.source = :queueSource
                  AND cs.language_id = :lang
            ),
            learning AS (
                -- 학습중은 일일 상한 밖이다 — 이미 떠안은 부담이고, 미루면 스텝이 깨진다.
                SELECT card_id, due_at, 0 AS bucket FROM card_state
                WHERE language_id = :lang
                  AND state IN (:learningState, :relearningState)
                  AND due_at <= :now
                ORDER BY due_at, card_id
                LIMIT :sessionLimit
            ),
            reviewing AS (
                SELECT card_id, due_at, 1 AS bucket FROM card_state
                WHERE language_id = :lang AND state = :reviewState AND due_at <= :now
                ORDER BY due_at, card_id
                LIMIT MAX(0, MIN(:sessionLimit, :reviewAllowance - (SELECT review_done FROM done)))
            ),
            introducing AS (
                SELECT card_id, due_at, 2 AS bucket FROM card_state
                WHERE language_id = :lang AND state = :newState AND due_at <= :now
                ORDER BY due_at, card_id
                LIMIT MAX(0, MIN(:sessionLimit, :newAllowance - (SELECT new_done FROM done)))
            ),
            picked AS (
                SELECT * FROM learning
                UNION ALL SELECT * FROM reviewing
                UNION ALL SELECT * FROM introducing
            )
        SELECT cs.*, p.bucket AS bucket
        FROM picked p
        JOIN card_state cs ON cs.card_id = p.card_id
        ORDER BY p.bucket, p.due_at, p.card_id
        LIMIT :sessionLimit
        """

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
