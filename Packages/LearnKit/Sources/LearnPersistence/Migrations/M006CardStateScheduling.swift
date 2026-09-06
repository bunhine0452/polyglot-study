internal import GRDB

/// 마이그레이션 006 — `card_state` 가 알고리즘 상태를 **전부** 담게 한다.
///
/// ## 왜 새 번호인가
///
/// 002 의 `card_state` 에는 `CardSchedulingState.elapsedDays` 와 `learningStepIndex` 에 대응하는
/// 컬럼이 없었다. 병렬 세션 둘이 서로를 못 보고 만든 구멍이고, 결과는 조용한 오작동이었다 —
/// 캐시에서 되살린 상태로 `ReviewScheduler.apply` 를 부르면 학습 단계 카드의 스텝 인덱스가
/// 0 으로 되감긴다. 002 를 고치는 것은 정책 위반이다(출시된 클로저 불변). 유일한 길이 새 번호다.
///
/// ## 기존 행의 기본값 — "0 을 넣되, 그 0 을 믿지 말라고 표시한다"
///
/// 두 컬럼을 nullable 로 두고 `NULL` 을 "모름(리플레이 필요)" 으로 읽는 안을 검토했고 버렸다.
/// 세 가지 이유다.
///
/// 1. **도메인 타입이 그 상태를 표현하지 않는다.** `CardSchedulingState.learningStepIndex` 는
///    `Int` 다. nullable 컬럼은 `Int?` 를 요구하고, 그 옵셔널은 FSRS 호출 직전까지 따라다니다가
///    결국 어딘가에서 `?? 0` 으로 풀린다 — 지금과 똑같은 버그가 한 겹 아래로 숨는 것뿐이다.
/// 2. **`card_state` 는 캐시다.** "모름" 이라는 세 번째 상태를 캐시에 저장한다는 것은 캐시가
///    스스로의 신뢰도를 들고 있다는 뜻이고, 그건 캐시가 아니라 진실의 원천이 하는 일이다.
///    신뢰도 판정은 이미 `card_state_stale` 뷰가 한다.
/// 3. **재구축 경로가 이미 있다.** `review_log` 는 append-only 진실의 원천이고 리플레이는
///    결정적이다. 되살릴 수 있는 값을 굳이 "모름" 으로 들고 있을 이유가 없다.
///
/// 그래서 `NOT NULL DEFAULT 0` 으로 넣고, **그 0 이 틀렸을 수 있는 행을 전량 stale 로 표시**한다.
/// 표시 방법은 워터마크를 지우는 것이다 (`derived_from_log_id = NULL`). 새 채널을 만들지 않은
/// 이유는 `card_state_stale.log_drift` 가 이미 정확히 그 질문에 답하기 때문이다 —
/// "이 행이 반영한 로그가 최신인가".
///
/// 워터마크를 지우는 것은 거짓말이 아니다. 006 이전에 계산된 행은 알고리즘 필드 두 개를
/// 담을 수 없는 스키마에서 나왔으므로, 그 행이 **어떤 로그도 온전히 반영하지 못했다**는 것이
/// 사실이다. 로그가 하나도 없는 카드(= 워터마크가 원래 `NULL` 인 신규 카드)는 이 UPDATE 가
/// 건드리지 않고 stale 로도 잡히지 않는다 — 리플레이할 이력이 없는 카드의 `elapsed_days` 와
/// `learning_step_index` 는 실제로 0 이 맞기 때문이다.
///
/// 행을 지우지 않고 남기는 것도 의도다. 캐시를 비우면 재구축이 끝날 때까지 due 큐가 텅 비고,
/// 그건 사용자가 "복습할 게 없네" 라고 오해하는 종류의 사고다. 살짝 뒤처진 큐가 빈 큐보다 낫다.
///
/// ## 인덱스 하나 추가 — `{#due-queue-benchmark}` `{#queue-mixing}`
///
/// 002 의 `(language_id, due_at)` 는 "이 언어의 due 카드" 까지만 좁힌다. 큐 쿼리는 거기서
/// **단계별로** 잘라야 하는데(학습중 / 복습 / 신규를 각자의 상한으로), `state` 가 인덱스에 없으면
/// 신규 카드 5장을 찾으려고 그 언어의 due 카드 2만 개를 훑는 일이 생긴다. 선두를
/// `(language_id, state, due_at)` 로 잡으면 버킷 하나가 정확히 인덱스 구간 하나가 되고,
/// `LIMIT` 이 그 구간에서 곧바로 멈춘다. `card_id` 를 꼬리에 붙인 것은 정렬 타이브레이커까지
/// 인덱스로 처리해 버킷 선택이 **커버링 인덱스만으로** 끝나게 하기 위해서다.
func register006CardStateScheduling(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("006-card-state-scheduling") { db in
        // ALTER TABLE ADD COLUMN 은 테이블 수준 CONSTRAINT 를 붙일 수 없다. 컬럼 수준 CHECK 는
        // 되므로 이름을 붙여 002 의 다른 제약들과 같은 규칙(chk_<table>_<what>)을 지킨다.
        try db.execute(sql: """
            ALTER TABLE card_state ADD COLUMN elapsed_days INTEGER NOT NULL DEFAULT 0
                CONSTRAINT chk_card_state_elapsed_days CHECK (elapsed_days >= 0)
            """)
        try db.execute(sql: """
            ALTER TABLE card_state ADD COLUMN learning_step_index INTEGER NOT NULL DEFAULT 0
                CONSTRAINT chk_card_state_learning_step CHECK (learning_step_index >= 0)
            """)

        // 기존 행 전량을 stale 로. 이력이 없어 원래 NULL 이던 행은 그대로 남는다(= 0 이 정답).
        try db.execute(sql: """
            UPDATE card_state SET derived_from_log_id = NULL
            WHERE derived_from_log_id IS NOT NULL
            """)

        try db.execute(sql: """
            CREATE INDEX idx_card_state_queue
                ON card_state(language_id, state, due_at, card_id)
            """)
    }
}
