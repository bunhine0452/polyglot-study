internal import GRDB

/// 마이그레이션 001 — `review_log` 를 append-only 진실의 원천으로.
///
/// 이 파일은 **출시 후 절대 수정하지 않는다**. 스키마를 바꿔야 하면 006 을 새로 만든다.
///
/// ## 설계 근거
///
/// - **`STRICT` 테이블.** SQLite 기본값은 어떤 컬럼에든 어떤 타입이든 넣게 해준다. epoch ms 컬럼에
///   ISO 문자열이 한 번 들어가면 리플레이가 조용히 어긋난다. `STRICT` 는 그 사고를 쓰기 시점에 막는다.
/// - **`AUTOINCREMENT`.** 그냥 `INTEGER PRIMARY KEY` 는 최댓값 행이 사라지면 id 를 재사용한다.
///   여기선 트리거가 DELETE 를 막으니 실질 위험은 낮지만, `card_state.derived_from_log_id` 가
///   "여기까지 반영했다" 는 워터마크로 쓰이므로 단조성을 스키마로 보장해 둔다.
/// - **팩 소유 테이블로 나가는 외래키 없음.** `card_id`·`pack_id` 를 참조하고 싶은 충동이 들지만,
///   콘텐츠 팩은 삭제·교체된다. FK 를 걸면 팩을 지울 때 이력이 같이 지워지거나(CASCADE)
///   삭제 자체가 막힌다(RESTRICT). 둘 다 틀렸다 — 학습 이력은 콘텐츠보다 오래 살아야 한다.
///   유일한 예외가 `parameter_set_id` 이고, 그건 팩이 아니라 이 앱이 소유하는 테이블이다.
func register001ReviewLog(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("001-review-log") { db in
        // 어떤 w 로 스케줄됐는지 소급 설명하기 위한 소형 테이블.
        try db.execute(sql: """
            CREATE TABLE scheduler_parameters (
                id TEXT NOT NULL PRIMARY KEY,
                scheduler_id TEXT NOT NULL,
                weights TEXT,
                desired_retention REAL NOT NULL,
                created_at INTEGER NOT NULL,
                is_active INTEGER NOT NULL,
                CONSTRAINT chk_scheduler_parameters_weights
                    CHECK (weights IS NULL OR json_valid(weights)),
                CONSTRAINT chk_scheduler_parameters_retention
                    CHECK (desired_retention > 0.0 AND desired_retention < 1.0),
                CONSTRAINT chk_scheduler_parameters_is_active
                    CHECK (is_active IN (0, 1))
            ) STRICT
            """)

        // 활성 세트는 최대 하나 — 부분 유니크 인덱스가 상한을 지킨다.
        // 하한(최소 하나)은 바로 아래 시드가 지키고, 세트 교체는 한 트랜잭션 안에서 일어난다.
        try db.execute(sql: """
            CREATE UNIQUE INDEX idx_scheduler_parameters_active
                ON scheduler_parameters(is_active) WHERE is_active = 1
            """)

        // `weights` 가 NULL 인 것은 "스케줄러 내장 기본 가중치" 를 뜻한다. FSRS-6 의 21개 상수를
        // 여기 복제하면 벤더 FSRS 를 갱신할 때 두 곳이 어긋난다 — 상수의 주인은 LearnScheduling 이다.
        // created_at 을 0 으로 박는 것은 마이그레이션이 결정적이어야 하기 때문이다(시계를 읽지 않는다).
        try db.execute(sql: """
            INSERT INTO scheduler_parameters
                (id, scheduler_id, weights, desired_retention, created_at, is_active)
            VALUES ('fsrs6-default', 'fsrs6', NULL, 0.9, 0, 1)
            """)

        try db.execute(sql: """
            CREATE TABLE review_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                card_id TEXT NOT NULL,
                reviewed_at INTEGER NOT NULL,
                rating INTEGER NOT NULL,
                state_before TEXT NOT NULL,
                elapsed_days INTEGER NOT NULL,
                scheduled_days INTEGER NOT NULL,
                review_duration_ms INTEGER NOT NULL,
                scheduler_id TEXT NOT NULL,
                parameter_set_id TEXT NOT NULL
                    REFERENCES scheduler_parameters(id) ON DELETE RESTRICT,
                source TEXT NOT NULL,
                CONSTRAINT chk_review_log_card_id
                    CHECK (length(card_id) > 0),
                CONSTRAINT chk_review_log_reviewed_at
                    CHECK (reviewed_at > 0),
                CONSTRAINT chk_review_log_rating
                    CHECK (rating BETWEEN 1 AND 4),
                CONSTRAINT chk_review_log_state_before
                    CHECK (state_before IN ('new', 'learning', 'review', 'relearning')),
                CONSTRAINT chk_review_log_source
                    CHECK (source IN ('scheduled', 'cram', 'manual', 'import')),
                CONSTRAINT chk_review_log_intervals
                    CHECK (elapsed_days >= 0 AND scheduled_days >= 0 AND review_duration_ms >= 0)
            ) STRICT
            """)

        // 리플레이용. `WHERE card_id = ? ORDER BY reviewed_at, id` 가 정렬 없이 인덱스만으로 끝난다.
        try db.execute(sql: """
            CREATE INDEX idx_review_log_card_replay
                ON review_log(card_id, reviewed_at, id)
            """)
        // 통계용. "지난 30일 복습 수" 류의 기간 집계.
        try db.execute(sql: """
            CREATE INDEX idx_review_log_reviewed_at
                ON review_log(reviewed_at)
            """)

        // append-only 봉인. RAISE(ABORT) 는 SQLITE_CONSTRAINT_TRIGGER 로 올라온다.
        // 애플리케이션 코드의 규율이 아니라 **엔진 차원의 불변식**이어야 한다 — sqlite3 CLI 로 직접
        // 열어 UPDATE 를 때려도 막혀야 하고, 실수로 만든 마이그레이션도 막혀야 한다.
        try db.execute(sql: """
            CREATE TRIGGER trg_review_log_no_update
            BEFORE UPDATE ON review_log
            BEGIN
                SELECT RAISE(ABORT, 'review_log is append-only: UPDATE is forbidden');
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER trg_review_log_no_delete
            BEFORE DELETE ON review_log
            BEGIN
                SELECT RAISE(ABORT, 'review_log is append-only: DELETE is forbidden');
            END
            """)
    }
}
