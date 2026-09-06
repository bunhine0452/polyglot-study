internal import GRDB
internal import LearnCore

/// 마이그레이션 정책.
///
/// 규칙 셋. 어기면 사용자 DB 가 조용히 갈라진다.
///
/// 1. **출시된 마이그레이션 클로저는 절대 수정하지 않는다.** 이미 돌린 기기에서는 다시 돌지 않으므로,
///    고친 내용이 신규 설치에만 반영돼 같은 앱 버전이 서로 다른 스키마를 갖게 된다. 변경은 항상 새 번호다.
/// 2. **식별자는 번호로 시작하고 바뀌지 않는다.** GRDB 는 `grdb_migrations` 테이블에 식별자 문자열을
///    기록한다. 이름을 바꾸면 이미 적용된 마이그레이션이 미적용으로 보이고 그대로 다시 돈다.
/// 3. **스키마가 바뀌면 DB 를 통째로 지우는 GRDB 편의 플래그는 DEBUG 에서도 쓰지 않는다.**
///    개발 중 지워지는 건 개발자의 `review_log` 이고, 그건 재생성이 불가능한 유일한 데이터다.
///    `MigrationPolicyTests` 가 소스 전체를 훑어 그 플래그 이름이 0회 나오는지 확인한다.
enum SchemaMigrations {
    /// 등록 순서 = 적용 순서. **이 배열에서 항목을 빼거나 이름을 바꾸는 것은 파괴적 변경**이다.
    static let identifiers = [
        "001-review-log",
        "002-card-state",
        "003-submission",
        "004-mistake-note",
        "005-lesson-progress",
        "006-card-state-scheduling",
    ]

    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        register001ReviewLog(&migrator)
        register002CardState(&migrator)
        register003Submission(&migrator)
        register004MistakeNote(&migrator)
        register005LessonProgress(&migrator)
        register006CardStateScheduling(&migrator)
        return migrator
    }
}

/// 파생 테이블 재구축 관용구.
///
/// `card_state` 와 FTS 섀도 테이블에 **한해** drop → recreate → replay 를 허용한다. 두 테이블은
/// 정의상 `review_log` 와 `mistake_note` 에서 재계산되기 때문이다. 관용구를 쓰는 코드는
/// 재구축 전후로 `review_log` 행 수가 같음을 단언해야 한다 — 그 단언이 "파생인 줄 알았는데
/// 사실 진실이었던 테이블" 을 지우는 사고를 잡는다.
enum DerivedRebuild {
    /// 재구축 블록을 감싼다. 블록 안에서 던지면 트랜잭션이 통째로 롤백되어 기존 캐시가 남는다.
    /// 성공해도 `review_log` 행 수가 달라졌으면 던진다.
    static func perform<T>(
        in db: Database,
        _ body: (Database) throws -> T
    ) throws -> T {
        let before = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_log") ?? 0
        let result = try body(db)
        let after = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_log") ?? 0
        guard before == after else {
            throw StoreError.storage(
                message: "파생 재구축이 review_log 를 건드렸다: \(before) → \(after)"
            )
        }
        return result
    }
}
