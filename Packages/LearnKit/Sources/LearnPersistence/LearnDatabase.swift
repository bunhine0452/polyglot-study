public import struct Foundation.URL
public import LearnCore
public import class Foundation.FileManager
internal import GRDB

/// 영속화 계층의 조립 루트.
///
/// 바깥 세계가 GRDB 를 만나는 지점은 여기 하나이고, 이 타입의 public 표면에는 GRDB 타입이
/// 단 하나도 나오지 않는다 (`internal import GRDB`). 스토어 5종은 전부 `LearnCore` 프로토콜로만 나간다.
///
/// ## 파일 / 인메모리
///
/// 파일은 `DatabasePool`(WAL), 테스트는 인메모리 `DatabaseQueue` 를 쓴다. 둘 다
/// `any DatabaseWriter` 하나로 스토어에 주입되므로 **같은 테스트 스위트가 두 주입 모두에서 돈다**.
/// WAL 이 필요한 이유는 읽기와 쓰기가 서로를 막지 않아야 하기 때문이고(복습 중 통계 화면이 떠 있다),
/// 인메모리를 쓰는 이유는 테스트가 디스크·파일 락·정리 코드에 의존하지 않게 하기 위해서다.
public struct LearnDatabase: Sendable {
    /// 스토어 구현이 공유하는 단일 writer. GRDB 7 의 writer 는 그 자체로 `Sendable` 이고
    /// 직렬화를 스스로 하므로 **actor 로 감싸지 않는다** — 감싸면 홉만 늘고 재진입 위험이 생긴다.
    let writer: any DatabaseWriter

    /// 부팅 시 실측한 SQLite 환경.
    public let environment: EnvironmentProbe

    private init(writer: any DatabaseWriter, environment: EnvironmentProbe) {
        self.writer = writer
        self.environment = environment
    }

    // MARK: - 열기

    /// 파일 DB 를 연다. 경로를 주지 않으면 `~/Library/Application Support/LearnKit/learn.sqlite`.
    ///
    /// 상위 디렉터리는 필요하면 만든다. 동기 폴더(iCloud·Dropbox…) 안이면 열지 않고 던진다.
    public static func open(at url: URL? = nil) throws -> LearnDatabase {
        let fileURL = try url ?? DatabaseLocation.defaultURL()
        try DatabaseLocation.validate(fileURL)

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var configuration = Configuration()
        configuration.journalMode = .wal
        // 기본값은 immediateError 라 동시 쓰기가 곧바로 SQLITE_BUSY 를 낸다. 학습 앱에서 동시 쓰기는
        // 드물지만(복습 기록 + 제출 기록) 겹치면 사용자 입력이 사라지므로 잠깐 기다린다.
        configuration.busyMode = .timeout(5)
        configuration.maximumReaderCount = 4

        let pool = try DatabasePool(path: fileURL.path, configuration: configuration)
        return try bootstrap(writer: pool, expectedJournalMode: "wal")
    }

    /// 인메모리 DB. 테스트와 미리보기 전용.
    public static func inMemory() throws -> LearnDatabase {
        let queue = try DatabaseQueue()
        return try bootstrap(writer: queue, expectedJournalMode: "memory")
    }

    private static func bootstrap(
        writer: any DatabaseWriter,
        expectedJournalMode: String
    ) throws -> LearnDatabase {
        // 순서가 중요하다 — 마이그레이션 004 가 FTS5 trigram 가상 테이블을 만들므로, 환경 실측이
        // 먼저 와야 "fts5 가 없다" 가 마이그레이션 중간의 알 수 없는 실패가 아니라 명확한 에러로 나온다.
        let environment = try writer.write { db in
            try EnvironmentProbe.measure(db)
        }
        try environment.validate(expectedJournalMode: expectedJournalMode)

        try SchemaMigrations.migrator().migrate(writer)

        return LearnDatabase(writer: writer, environment: environment)
    }

    // MARK: - 스토어 5종

    public var reviewLogStore: any ReviewLogStore { GRDBReviewLogStore(writer: writer) }
    public var cardStateStore: any CardStateStore { GRDBCardStateStore(writer: writer) }
    public var submissionStore: any SubmissionStore { GRDBSubmissionStore(writer: writer) }
    public var mistakeNoteStore: any MistakeNoteStore { GRDBMistakeNoteStore(writer: writer) }
    public var lessonProgressStore: any LessonProgressStore { GRDBLessonProgressStore(writer: writer) }

    // MARK: - 진단

    /// 적용된 마이그레이션 식별자 목록. 순서는 적용 순서다.
    public func appliedMigrations() throws -> [String] {
        try writer.read { db in
            try SchemaMigrations.migrator().appliedIdentifiers(db).sorted()
        }
    }

    /// 스키마 덤프. 골든 스냅샷 테스트가 이걸 체크인된 픽스처와 바이트 비교한다.
    public func schemaDump() throws -> String {
        let output = SchemaDumpStream()
        try writer.read { db in
            try db.dumpSchema(to: output)
        }
        return output.text
    }
}

// MARK: - 테스트·진단 전용 표면
//
// 전부 internal 이다. 프로덕션 경로는 예외 없이 스토어 5종을 거친다 — 여기 있는 것들은
// "스키마가 정말 그렇게 동작하는가" 를 밖에서 확인하기 위한 것이고, 그 확인 자체가
// 이 계층의 완료 기준이다 (append-only 봉인, 인덱스 사용, CHECK 도메인).

/// 원시 SQL 실행이 실패했을 때의 정보. SQLite 결과코드를 **그대로** 들고 있다.
struct RawSQLFailure: Error {
    var primaryResultCode: Int32
    var extendedResultCode: Int32
    var message: String
    /// 같은 실패를 스토어가 밖으로 내보낼 때의 도메인 에러.
    var mapped: any Error
}

extension LearnDatabase {
    /// 임의 SQL 실행. 스토어를 우회하므로 **테스트와 진단 전용**.
    func executeRaw(_ sql: String) throws {
        do {
            try writer.write { db in try db.execute(sql: sql) }
        } catch let error as DatabaseError {
            throw RawSQLFailure(
                primaryResultCode: error.resultCode.rawValue,
                extendedResultCode: error.extendedResultCode.rawValue,
                message: error.message ?? "\(error)",
                mapped: mapDatabaseError(error)
            )
        }
    }

    /// `EXPLAIN QUERY PLAN` 의 `detail` 열. 인덱스를 실제로 타는지 확인하는 데 쓴다.
    func queryPlan(for sql: String, arguments: [Int64] = []) throws -> [String] {
        try writer.read { db in
            let statementArguments = StatementArguments(arguments.map { $0 as (any DatabaseValueConvertible)? })
            return try Row
                .fetchAll(db, sql: "EXPLAIN QUERY PLAN \(sql)", arguments: statementArguments)
                .map { $0["detail"] ?? "" }
        }
    }

    /// 특정 마이그레이션까지만 적용한 인메모리 DB.
    ///
    /// 마이그레이션 하나를 제대로 검증하려면 **그 앞까지만 적용된 DB** 가 필요하다. 006 의 본체는
    /// "이미 있는 행을 어떻게 다루는가" 인데, 전부 적용된 DB 에는 애초에 기존 행이 없다.
    /// 나머지는 `applyRemainingMigrations()` 로 이어 붙인다.
    static func inMemory(upTo identifier: String) throws -> LearnDatabase {
        let queue = try DatabaseQueue()
        let environment = try queue.write { db in try EnvironmentProbe.measure(db) }
        try environment.validate(expectedJournalMode: "memory")
        try SchemaMigrations.migrator().migrate(queue, upTo: identifier)
        return LearnDatabase(writer: queue, environment: environment)
    }

    /// 남은 마이그레이션을 마저 적용한다. `inMemory(upTo:)` 와 짝이다.
    func applyRemainingMigrations() throws {
        try SchemaMigrations.migrator().migrate(writer)
    }

    /// due 큐 쿼리의 `EXPLAIN QUERY PLAN`. 스토어가 실제로 실행하는 SQL·인자를 그대로 쓴다.
    func dueQueuePlan(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) throws -> [String] {
        try GRDBCardStateStore(writer: writer).queryPlan(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: policy
        )
    }

    /// 단일 정수 조회. 스키마 불변식을 SQL 로 직접 확인할 때.
    func scalarInt(_ sql: String) throws -> Int? {
        try writer.read { db in try Int.fetchOne(db, sql: sql) }
    }

    /// 임의 조회의 결과를 행마다 `컬럼=값 컬럼=값 …` 한 줄로.
    ///
    /// `PRAGMA table_info`·`index_xinfo`·`foreign_key_list` 를 **비교 가능한 값**으로 꺼내기
    /// 위한 것이다 — 마이그레이션 007 처럼 테이블을 재생성하는 변경은 "빠뜨린 컬럼·제약·
    /// 인덱스가 없다" 를 눈이 아니라 테스트로 증명해야 하고, 그 증명의 재료가 이 PRAGMA 들이다.
    /// GRDB `Row` 는 클로저 밖으로 나가지 못하므로 여기서 문자열로 굳혀 내보낸다.
    func rawRowStrings(_ sql: String) throws -> [String] {
        try writer.read { db in
            try Row.fetchAll(db, sql: sql).map { row in
                row.map { "\($0.0)=\($0.1)" }.joined(separator: " ")
            }
        }
    }
}

/// `dumpSchema(to:)` 가 요구하는 `TextOutputStream`.
///
/// `write(_:)` 가 mutating 이 아니라 참조 의미론이 필요하다 — 값 타입으로 넘기면 GRDB 가 사본에 쓴다.
private final class SchemaDumpStream: TextOutputStream, @unchecked Sendable {
    private(set) var text = ""
    func write(_ string: String) { text += string }
}
