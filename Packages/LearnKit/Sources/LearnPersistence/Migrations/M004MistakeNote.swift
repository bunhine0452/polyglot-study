internal import GRDB

/// 마이그레이션 004 — 오답 노트 본문 + FTS5 external-content 인덱스.
///
/// ## 토크나이저를 trigram 으로 고른 이유
///
/// 이 앱의 검색어는 두 종류다 — 한국어 산문("클로저가 캡처")과 코드 식별자(`snake_case_ident`).
/// `unicode61` 은 공백·구두점 경계로만 끊으므로 **둘 다 놓친다**: 한국어는 어절 전체를 정확히
/// 입력해야 하고, `case_id` 로는 `snake_case_ident` 를 찾지 못한다. trigram 은 3자 슬라이딩
/// 윈도우라 두 경우 모두 부분 일치한다 (SQLite 3.51.1 에서 실측 확인).
///
/// 대가는 셋이다. 인덱스가 커지고, 2자 이하 질의가 아무것도 매치하지 않으며
/// (`MistakeNoteSearch.minimumQueryLength`), 어간 추출이 없다. 학습 노트 규모에서는 전부 감수할 만하다.
///
/// ## external content 를 쓰는 이유
///
/// 본문을 FTS 테이블에 복제하면 같은 텍스트가 DB 에 두 벌 남고 둘이 어긋날 수 있다.
/// `synchronize(withTable:)` 은 `content=` 옵션 + INSERT/UPDATE/DELETE 트리거 3종을 만들어
/// 원본만 갱신하면 인덱스가 따라오게 한다.
func register004MistakeNote(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("004-mistake-note") { db in
        try db.execute(sql: """
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
            ) STRICT
            """)

        try db.execute(sql: """
            CREATE INDEX idx_mistake_note_language
                ON mistake_note(language_id, updated_at)
            """)
        // 부분 인덱스 — 카드에 묶이지 않은 자유 노트가 다수일 것이므로 NULL 행은 색인하지 않는다.
        try db.execute(sql: """
            CREATE INDEX idx_mistake_note_card
                ON mistake_note(card_id) WHERE card_id IS NOT NULL
            """)

        try db.create(virtualTable: "mistake_note_fts", using: FTS5()) { table in
            table.synchronize(withTable: "mistake_note")
            table.tokenizer = FTS5TokenizerDescriptor(components: ["trigram"])
            table.column("title")
            table.column("body")
        }
    }
}
