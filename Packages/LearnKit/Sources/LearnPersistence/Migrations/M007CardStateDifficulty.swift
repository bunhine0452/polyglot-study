internal import GRDB

/// 마이그레이션 007 — 한 번도 복습하지 않은 카드를 `card_state` 에 넣을 수 있게 한다.
///
/// ## 결함
///
/// 002 의 `chk_card_state_difficulty` 는 `difficulty >= 1.0 AND difficulty <= 10.0` 을 요구했다.
/// 그런데 FSRS 난이도는 **첫 복습 전까지 정의되지 않는다** — `CardSchedulingState.difficulty` 의
/// 기본값이 0 이고 `newCard(...)` 가 그 값을 그대로 들고 나온다. 두 사실이 겹치는 결과가
/// "신규 카드는 저장 자체가 불가능" 이었다: `cardStateStore.upsert(...)` 가
/// `CHECK constraint failed: chk_card_state_difficulty` 로 실패한다.
///
/// 이 CHECK 는 **나머지 설계와 모순된다**. `chk_card_state_state` 가 `'new'` 를 허용하고,
/// due 큐의 `introducing` 버킷(`GRDBCardStateStore.queueSQL`)은 `state = 'new'` 행을 읽는다.
/// 즉 스키마의 나머지 전부가 신규 카드 행을 전제하는데 제약 하나가 그 행의 삽입을 막고 있었다.
///
/// 아무도 못 잡은 이유는 세 테스트 경로가 전부 실제 DB 에 신규 카드를 넣지 않았기 때문이다 —
/// 스케줄링 테스트는 CHECK 없는 인메모리 페이크를 쓰고, 영속화 테스트는 손으로 유효한 난이도를
/// 넣고, 재구축 드라이버는 복습이 1회 이상인 카드만 쓴다.
///
/// ## 센티널 표현 — 왜 `0.0` 이고, 왜 nullable 이 아닌가
///
/// `difficulty` 를 nullable 로 바꿔 `NULL` 을 "아직 없음" 으로 읽는 안을 검토했고 버렸다.
/// 006 이 `learning_step_index` 에서 nullable 을 버린 논리(`M006CardStateScheduling.swift`)가
/// 여기에도 **한 갈래만** 그대로 적용되고, 나머지 한 갈래는 여기서 더 강하다.
///
/// 1. **도메인 타입이 그 상태를 표현하지 않는다** — 006 과 같은 논리, 같은 결론.
///    `CardSchedulingState.difficulty` 는 `Double` 이고 신규 카드에서 값은 `0` 이다.
///    컬럼만 `Double?` 로 만들면 `CardStateRow.toSnapshot()` 이 어딘가에서 `?? 0` 으로 풀어야
///    하고, 그 순간 "저장할 수 없는 값" 이 "조용히 0 이 되는 값" 으로 바뀌는 것뿐이다.
/// 2. **006 의 2번 논리(캐시가 신뢰도를 들지 않는다)는 여기 해당하지 않는다.** 006 의 `NULL`
///    후보는 "이 값을 모른다(리플레이 필요)" 였다. 여기 `0` 은 모름이 아니라 **정의된 도메인
///    값**이다 — "첫 복습 전이라 난이도가 아직 없다". 재구축을 해도 값은 그대로 0 이다.
///    그래서 이 컬럼의 `0` 은 stale 신호와 아무 관계가 없고, `card_state_stale` 뷰가 답하는
///    질문과도 겹치지 않는다.
/// 3. **짝이 되는 컬럼이 이미 같은 관례를 쓴다.** `stability` 는 신규 카드에서 0 이고
///    `chk_card_state_stability` 가 `stability >= 0.0` 으로 그 0 을 이미 받는다. FSRS 의
///    두 기억 상태 변수가 같은 행에서 서로 다른 "없음" 표현(0 과 `NULL`)을 쓰는 것은
///    읽는 사람에게 없는 구분을 있다고 말하는 것이다.
///
/// 그래서 `NOT NULL REAL` 을 유지하고 CHECK 만 `difficulty = 0.0` 을 추가로 받게 한다.
/// **0 이 "정의되지 않음" 이라는 사실은 스키마 덤프만 봐도 읽혀야 하므로** 제약 이름을
/// `chk_card_state_difficulty_unrated_or_1_to_10` 으로 바꾸고 CREATE 문 안에 주석을 남긴다
/// (SQLite 는 `sqlite_master.sql` 에 원문을 주석까지 그대로 보관한다).
///
/// `state = 'new'` 와 묶어 `(difficulty = 0.0 AND state = 'new') OR ...` 로 쓰는 안도 봤다.
/// 지금은 참인 불변식이지만 채택하지 않았다 — 캐시 행의 두 컬럼을 교차 구속하면 스케줄러가
/// 만들어 낸 조합 하나가 어긋나는 순간 **저장이 실패**하고, 그건 이 마이그레이션이 고치고 있는
/// 사고와 정확히 같은 종류다. 컬럼의 도메인은 컬럼만 보고 판정한다.
///
/// ## 왜 테이블 재생성인가
///
/// SQLite 는 `ALTER TABLE` 로 CHECK 를 바꾸지 못한다. 그래서 <https://sqlite.org/lang_altertable.html>
/// 의 12단계 절차를 따른다. GRDB 의 마이그레이션은 기본이 `foreignKeyChecks: .deferred` 라
/// 그 절차의 1·2·10·11·12 단계(외래키 끄기 → 트랜잭션 → `foreign_key_check` → 커밋 → 되켜기)를
/// 이미 대신 해 준다. 여기서는 뜻을 분명히 하려고 기본값을 **명시**한다.
///
/// 순서에 두 가지 함정이 있다.
///
/// - **뷰를 먼저 지운다.** `legacy_alter_table` 이 꺼진 현대 SQLite 에서 `ALTER TABLE … RENAME`
///   은 다른 뷰·트리거 안의 테이블 참조를 **자동으로 고쳐 쓴다**. `card_state_stale` 를 남겨
///   두면 뷰가 헌 테이블(`card_state_pre007`)을 가리키도록 재작성된다.
/// - **새 테이블이 아니라 헌 테이블의 이름을 바꾼다.** 반대로 하면(`card_state_new` 를 만들고
///   나중에 rename) SQLite 가 저장된 CREATE 문의 테이블 이름 토큰을 `"card_state"` 로
///   **따옴표를 붙여** 다시 쓴다. 골든 스냅샷이 그 흔적을 그대로 들고 다니게 되므로,
///   최종 이름으로 처음부터 CREATE 하는 쪽을 택했다.
///
/// 재생성이므로 002·006 이 만든 컬럼·제약·인덱스와 `card_state_stale` 뷰가 **하나도 빠지면
/// 안 된다**. 눈으로 베끼는 것으로는 부족해서 `Migration007Tests` 가 006 직후와 007 직후의
/// 스키마를 `PRAGMA table_info`/`index_list`/`index_xinfo`/`foreign_key_list` 와 뷰 SQL 로
/// 뽑아 비교한다 — 달라도 되는 것은 `difficulty` 의 CHECK 하나뿐이다.
func register007CardStateDifficulty(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("007-card-state-difficulty", foreignKeyChecks: .deferred) { db in
        // 3단계: 딸린 객체를 기억해 뒀다가 나중에 그대로 다시 만든다.
        //   인덱스 — idx_card_state_due (002), idx_card_state_queue (006)
        //   뷰     — card_state_stale (002)
        // 인덱스는 DROP TABLE 이 함께 지우므로 따로 지우지 않는다. 뷰는 위 주석의 이유로 먼저.
        try db.execute(sql: "DROP VIEW card_state_stale")

        try db.execute(sql: "ALTER TABLE card_state RENAME TO card_state_pre007")

        // 4단계: 002 + 006 의 정의를 그대로 옮기고 difficulty CHECK 하나만 넓힌다.
        // 컬럼 순서도 006 이후와 같게 유지한다 — 006 이 ALTER 로 뒤에 붙인 두 컬럼이 뒤에 온다.
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
                elapsed_days INTEGER NOT NULL DEFAULT 0
                    CONSTRAINT chk_card_state_elapsed_days CHECK (elapsed_days >= 0),
                learning_step_index INTEGER NOT NULL DEFAULT 0
                    CONSTRAINT chk_card_state_learning_step CHECK (learning_step_index >= 0),
                CONSTRAINT chk_card_state_state
                    CHECK (state IN ('new', 'learning', 'review', 'relearning')),
                CONSTRAINT chk_card_state_stability
                    CHECK (stability >= 0.0),
                -- difficulty = 0.0 은 값이 아니라 **센티널**이다: "첫 복습 전이라 FSRS 난이도가
                -- 아직 없다". FSRS 가 실제로 만들어 내는 난이도는 1.0...10.0 뿐이고, 0.0 은
                -- 그 구간 밖이라 실제 값과 섞이지 않는다. 같은 행의 stability 도 신규 카드에서
                -- 0 이며 chk_card_state_stability 가 그 0 을 받는다 — 같은 관례다.
                CONSTRAINT chk_card_state_difficulty_unrated_or_1_to_10
                    CHECK (difficulty = 0.0 OR (difficulty >= 1.0 AND difficulty <= 10.0)),
                CONSTRAINT chk_card_state_counters
                    CHECK (reps >= 0 AND lapses >= 0 AND scheduled_days >= 0),
                CONSTRAINT chk_card_state_last_reviewed
                    CHECK (last_reviewed_at IS NULL OR last_reviewed_at > 0)
            ) STRICT
            """)

        // 5단계: 내용 이관. `SELECT *` 대신 컬럼을 전부 적는다 — 순서에 기대면 다음 재생성이
        // 조용히 어긋난다. 헌 행은 전부 더 좁은 CHECK 를 통과한 값이라 새 CHECK 도 통과한다.
        try db.execute(sql: """
            INSERT INTO card_state (
                card_id, language_id, stability, difficulty, due_at, last_reviewed_at,
                state, reps, lapses, scheduled_days, derived_from_log_id,
                parameter_set_id, rebuilt_at, elapsed_days, learning_step_index
            )
            SELECT
                card_id, language_id, stability, difficulty, due_at, last_reviewed_at,
                state, reps, lapses, scheduled_days, derived_from_log_id,
                parameter_set_id, rebuilt_at, elapsed_days, learning_step_index
            FROM card_state_pre007
            """)

        // 6단계: 헌 테이블과 거기 딸린 인덱스를 함께 버린다.
        try db.execute(sql: "DROP TABLE card_state_pre007")

        // 8·9단계: 인덱스와 뷰를 002·006 의 정의 그대로 되살린다.
        try db.execute(sql: """
            CREATE INDEX idx_card_state_due
                ON card_state(language_id, due_at)
            """)
        try db.execute(sql: """
            CREATE INDEX idx_card_state_queue
                ON card_state(language_id, state, due_at, card_id)
            """)
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
