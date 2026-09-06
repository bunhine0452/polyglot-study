internal import GRDB

/// 마이그레이션 005 — 6블록 시퀀스 진도를 팩·레슨 단위로.
///
/// PK 가 `(pack_id, lesson_id)` 인 것은 같은 `LessonID` 가 여러 팩에 존재할 수 있기 때문이다.
/// `LessonID` 는 팩이 갱신돼도 바뀌지 않는다는 계약이므로, 팩 버전을 올려도 진도가 고아가 되지 않는다.
///
/// 시도 횟수 컬럼이 없는 것은 의도다 — `submission` 을 세면 나온다. 이중 기록하면 실패 제출
/// 보존 정책(블록당 20건)이 돌 때 두 값이 어긋나고, 그 시점엔 어느 쪽이 진짜인지 알 수 없다.
func register005LessonProgress(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("005-lesson-progress") { db in
        try db.execute(sql: """
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
            ) STRICT
            """)

        // 팩 화면이 "이 팩에서 몇 개 끝냈나" 를 세는 경로.
        try db.execute(sql: """
            CREATE INDEX idx_lesson_progress_pack_status
                ON lesson_progress(pack_id, status)
            """)
    }
}
