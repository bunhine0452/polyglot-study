internal import GRDB

/// 마이그레이션 002 — `card_state` 를 파생 캐시로.
///
/// 이 테이블에는 **재계산할 수 없는 값이 하나도 없다**. 그 성질이 깨지는 순간(예: 사용자 메모 컬럼을
/// 여기 추가하는 순간) 재구축이 파괴적 연산이 되고, FSRS 파라미터 재최적화가 사실상 불가능해진다.
/// 새 값이 필요하면 `review_log` 에 넣거나 별도 테이블을 만든다.
func register002CardState(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("002-card-state") { db in
        try db.execute(sql: """
            CREATE TABLE card_state (
                card_id TEXT NOT NULL PRIMARY KEY,
                language_id TEXT NOT NULL,
                stability REAL NOT NULL,
                difficulty REAL NOT NULL,
                due_at INTEGER NOT NULL,
                last_reviewed_at INTEGER,
                state TEXT NOT NULL,
                reps INTEGER NOT NULL,
                lapses INTEGER NOT NULL,
                scheduled_days INTEGER NOT NULL,
                derived_from_log_id INTEGER
                    REFERENCES review_log(id) ON DELETE RESTRICT,
                parameter_set_id TEXT NOT NULL
                    REFERENCES scheduler_parameters(id) ON DELETE RESTRICT,
                rebuilt_at INTEGER NOT NULL,
                CONSTRAINT chk_card_state_state
                    CHECK (state IN ('new', 'learning', 'review', 'relearning')),
                CONSTRAINT chk_card_state_stability
                    CHECK (stability >= 0.0),
                CONSTRAINT chk_card_state_difficulty
                    CHECK (difficulty >= 1.0 AND difficulty <= 10.0),
                CONSTRAINT chk_card_state_counters
                    CHECK (reps >= 0 AND lapses >= 0 AND scheduled_days >= 0),
                CONSTRAINT chk_card_state_last_reviewed
                    CHECK (last_reviewed_at IS NULL OR last_reviewed_at > 0)
            ) STRICT
            """)

        // 트랙별 독립 학습이므로 큐 쿼리는 항상 언어로 먼저 좁힌다. 선두 컬럼이 due_at 이면
        // 언어 하나를 뽑는 데 다른 9개 트랙의 카드까지 훑게 된다.
        try db.execute(sql: """
            CREATE INDEX idx_card_state_due
                ON card_state(language_id, due_at)
            """)

        // stale 판정 헬퍼. 재구축 로직 자체는 LearnScheduling 이 갖고, 여기는 "무엇이 뒤처졌나" 까지만.
        //
        // 두 원인을 나누는 이유는 대응 비용이 다르기 때문이다.
        // - log_drift: 새 리뷰가 아직 반영 안 됨 → 그 카드만 이어서 적용하면 된다.
        // - parameter_drift: 가중치가 바뀜 → 그 카드 이력을 처음부터 다시 돌려야 한다.
        //
        // SQLite 의 비교 연산자는 0/1 정수를 낸다. 뷰로 두면 앱과 sqlite3 CLI 가 같은 정의를 쓴다.
        try db.execute(sql: """
            CREATE VIEW card_state_stale AS
            SELECT
                cs.card_id AS card_id,
                cs.language_id AS language_id,
                cs.parameter_set_id <> (
                    SELECT sp.id FROM scheduler_parameters sp WHERE sp.is_active = 1
                ) AS parameter_drift,
                COALESCE(cs.derived_from_log_id, 0) <> COALESCE((
                    SELECT MAX(rl.id) FROM review_log rl WHERE rl.card_id = cs.card_id
                ), 0) AS log_drift
            FROM card_state cs
            """)
    }
}
