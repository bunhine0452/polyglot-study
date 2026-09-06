internal import GRDB

/// 마이그레이션 003 — 제출 이력과 정규화된 진단.
///
/// `GradeResult` 하나가 `submission` 1행 + `diagnostic` N행이 된다. 둘은 **한 트랜잭션**으로만
/// 쓰인다 — 진단 없는 제출 행이 잠깐이라도 관측되면 gutter 가 비어 보이고, 그게 "경고 없이 통과"
/// 인지 "아직 안 써짐" 인지 구별할 방법이 없다.
///
/// 진단을 JSON blob 이 아니라 테이블로 푸는 이유: "최근 실패에서 가장 흔한 컴파일 에러" 같은 집계와
/// `WHERE submission_id = ? ORDER BY ordinal` 렌더링이 SQL 로 끝나야 하기 때문이다.
func register003Submission(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("003-submission") { db in
        // presenter / runner_backend / failure_kind 의 CHECK 목록은 각각 LearnCore 의
        // GradeResult.Presenter · RunnerBackend · SubmissionFailureKind rawValue 와 **정확히** 같다.
        // SubmissionSchemaTests 가 두 목록을 실제로 대조한다 — 손으로 맞춘 목록은 반드시 어긋난다.
        try db.execute(sql: """
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
            ) STRICT
            """)

        // recent / attemptCount / 보존 정리가 전부 이 인덱스를 탄다. 마지막 컬럼이 id 라
        // "최근 N건" 이 인덱스 역방향 스캔으로 끝나고 정렬이 필요 없다.
        try db.execute(sql: """
            CREATE INDEX idx_submission_lesson_block
                ON submission(pack_id, lesson_id, block_index, id)
            """)

        // `column` 은 SQL 예약어가 아니지만 방언마다 취급이 달라 항상 따옴표로 감싼다.
        try db.execute(sql: """
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
            ) STRICT
            """)

        // ordinal 이 배열 순서를 보존한다. UNIQUE 로 두면 중복 삽입 버그가 쓰기 시점에 잡히고,
        // 동시에 submission_id 조회 인덱스 역할도 한다.
        try db.execute(sql: """
            CREATE UNIQUE INDEX idx_diagnostic_submission_ordinal
                ON diagnostic(submission_id, ordinal)
            """)
    }
}
