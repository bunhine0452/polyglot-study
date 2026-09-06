// 이 파일은 생성물이다. 손으로 고치지 말고 아래 명령으로 다시 굽는다.
//
//   LEARNKIT_REGENERATE_GOLDEN=1 swift test --filter regenerateGoldenSchema
//
// 다시 구워야 하는 유일한 경우는 **새 번호의 마이그레이션을 추가했을 때**다.
// 기존 마이그레이션을 고쳐서 이 파일이 바뀐다면 그건 정책 위반이고, 되돌려야 한다.

enum GoldenSchema {
    static let dump = """
    sqlite_master
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
    ) STRICT;
    CREATE INDEX idx_card_state_due
        ON card_state(language_id, due_at);
    CREATE INDEX idx_card_state_queue
        ON card_state(language_id, state, due_at, card_id);
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
    FROM card_state cs;
    CREATE TABLE diagnostic (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        submission_id INTEGER NOT NULL
            REFERENCES submission(id) ON DELETE CASCADE,
        ordinal INTEGER NOT NULL,
        file TEXT,
        line INTEGER,
        "column" INTEGER,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        rule_id TEXT,
        CONSTRAINT chk_diagnostic_ordinal
            CHECK (ordinal >= 0),
        CONSTRAINT chk_diagnostic_severity
            CHECK (severity IN ('note', 'warning', 'error')),
        CONSTRAINT chk_diagnostic_position
            CHECK ((line IS NULL OR line >= 1) AND ("column" IS NULL OR "column" >= 1))
    ) STRICT;
    CREATE UNIQUE INDEX idx_diagnostic_submission_ordinal
        ON diagnostic(submission_id, ordinal);
    CREATE TABLE lesson_progress (
        pack_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        language_id TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_blocks TEXT NOT NULL,
        current_block_index INTEGER NOT NULL,
        started_at INTEGER,
        last_activity_at INTEGER,
        completed_at INTEGER,
        PRIMARY KEY (pack_id, lesson_id),
        CONSTRAINT chk_lesson_progress_status
            CHECK (status IN ('notStarted', 'inProgress', 'completed', 'skipped')),
        CONSTRAINT chk_lesson_progress_blocks_json
            CHECK (json_valid(completed_blocks)),
        CONSTRAINT chk_lesson_progress_current_block
            CHECK (current_block_index BETWEEN 0 AND 5),
        CONSTRAINT chk_lesson_progress_completed_at
            CHECK ((status = 'completed') = (completed_at IS NOT NULL))
    ) STRICT;
    CREATE INDEX idx_lesson_progress_pack_status
        ON lesson_progress(pack_id, status);
    CREATE TABLE mistake_note (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id TEXT,
        language_id TEXT NOT NULL,
        pack_id TEXT,
        lesson_id TEXT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        CONSTRAINT chk_mistake_note_title
            CHECK (length(title) > 0),
        CONSTRAINT chk_mistake_note_timestamps
            CHECK (created_at > 0 AND updated_at >= created_at)
    ) STRICT;
    CREATE INDEX idx_mistake_note_card
        ON mistake_note(card_id) WHERE card_id IS NOT NULL;
    CREATE INDEX idx_mistake_note_language
        ON mistake_note(language_id, updated_at);
    CREATE TRIGGER "__mistake_note_fts_ad" AFTER DELETE ON "mistake_note" BEGIN
        INSERT INTO "mistake_note_fts"("mistake_note_fts", "rowid", "title", "body") VALUES('delete', old."id", old."title", old."body");
    END;
    CREATE TRIGGER "__mistake_note_fts_ai" AFTER INSERT ON "mistake_note" BEGIN
        INSERT INTO "mistake_note_fts"("rowid", "title", "body") VALUES (new."id", new."title", new."body");
    END;
    CREATE TRIGGER "__mistake_note_fts_au" AFTER UPDATE ON "mistake_note" BEGIN
        INSERT INTO "mistake_note_fts"("mistake_note_fts", "rowid", "title", "body") VALUES('delete', old."id", old."title", old."body");
        INSERT INTO "mistake_note_fts"("rowid", "title", "body") VALUES (new."id", new."title", new."body");
    END;
    CREATE VIRTUAL TABLE "mistake_note_fts" USING fts5(title, body, tokenize='''trigram''', content='mistake_note', content_rowid='id');
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
    ) STRICT;
    CREATE INDEX idx_review_log_card_replay
        ON review_log(card_id, reviewed_at, id);
    CREATE INDEX idx_review_log_reviewed_at
        ON review_log(reviewed_at);
    CREATE TRIGGER trg_review_log_no_delete
    BEFORE DELETE ON review_log
    BEGIN
        SELECT RAISE(ABORT, 'review_log is append-only: DELETE is forbidden');
    END;
    CREATE TRIGGER trg_review_log_no_update
    BEFORE UPDATE ON review_log
    BEGIN
        SELECT RAISE(ABORT, 'review_log is append-only: UPDATE is forbidden');
    END;
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
    ) STRICT;
    CREATE UNIQUE INDEX idx_scheduler_parameters_active
        ON scheduler_parameters(is_active) WHERE is_active = 1;
    CREATE TABLE submission (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pack_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        block_index INTEGER NOT NULL,
        language_id TEXT NOT NULL,
        submitted_at INTEGER NOT NULL,
        passed INTEGER NOT NULL,
        source_code TEXT NOT NULL,
        stdout TEXT NOT NULL,
        stderr TEXT NOT NULL,
        exit_code INTEGER,
        duration_ms INTEGER NOT NULL,
        presenter TEXT NOT NULL,
        runner_backend TEXT NOT NULL,
        toolchain_version TEXT,
        failure_kind TEXT,
        CONSTRAINT chk_submission_block_index
            CHECK (block_index BETWEEN 0 AND 5),
        CONSTRAINT chk_submission_passed
            CHECK (passed IN (0, 1)),
        CONSTRAINT chk_submission_submitted_at
            CHECK (submitted_at > 0),
        CONSTRAINT chk_submission_duration
            CHECK (duration_ms >= 0),
        CONSTRAINT chk_submission_presenter
            CHECK (presenter IN ('console', 'table', 'browser', 'registers')),
        CONSTRAINT chk_submission_runner_backend
            CHECK (runner_backend IN
                ('inProcess', 'webView', 'subprocess', 'emulator', 'remote')),
        CONSTRAINT chk_submission_failure_kind
            CHECK (failure_kind IS NULL OR failure_kind IN
                ('compileError', 'testFailure', 'wrongResult', 'toolchainMissing',
                 'wallClockExceeded', 'cpuExceeded', 'memoryExceeded', 'cancelled',
                 'backend')),
        CONSTRAINT chk_submission_outcome
            CHECK ((passed = 1) = (failure_kind IS NULL))
    ) STRICT;
    CREATE INDEX idx_submission_lesson_block
        ON submission(pack_id, lesson_id, block_index, id);
    
    """
}
