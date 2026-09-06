import Foundation
import LanguageKit
import LearnCore
import RunnerKit
import SQLite3

@testable import EditorFeature

/// 프로세스를 띄우지 않는 실행 스트림. **실행 경로의 사건 순서만** 재현한다 — 실제
/// 백엔드의 계약은 `RunnerKitTests` 가 이미 검증했다. `LessonFeatureTests.FakeRunner`
/// 와 같은 이유·같은 모양이다.
enum FakeRunner {
    static func factory(yielding events: [RunEvent]) -> EditorRunFactory {
        { _, _ in
            AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    static func failing(_ error: any Error) -> EditorRunFactory {
        { _, _ in AsyncThrowingStream { $0.finish(throwing: error) } }
    }

    static func succeeding(stdout: String, durationMilliseconds: Int = 12) -> [RunEvent] {
        [
            .phase(.preparing),
            .phase(.running),
            .standardOutput(Data(stdout.utf8)),
            .finished(RunTermination.exitCode(0, durationMilliseconds: durationMilliseconds)),
        ]
    }
}

/// `swift test` 의 XCTest 호스트 프로세스에서는 `Bundle.main` 이 `.build` 산출물
/// 레이아웃을 가리키지 않는다 — `SubprocessRunner` 가 기본으로 찾는 `LauncherLocator`
/// 의 "형제 실행 파일" 경로가 이 컨텍스트에서는 성립하지 않는다는 뜻이다.
///
/// `RunnerKitTests.ToolchainLauncherHarness.locateLauncher()` 와 같은 탐색을 여기서도
/// 하되, 찾은 경로를 `LEARN_LAUNCHER_PATH` 환경 변수로 꽂아 넣는다 —
/// `LauncherLocator` 가 **그 환경 변수를 최우선으로** 보게 설계돼 있어서다
/// ("테스트와 CI 가 빌드 산출물을 직접 가리킨다"). 그러면 `EditorModel` 의 기본
/// 배선(`SwiftLanguageModule().makeRunner()`, 설정을 하나도 안 바꾼)이 그대로
/// 이 launcher 를 찾는다 — 팩토리를 주입해 우회하지 않고 실제 기본 경로를 검증한다.
enum RealToolchainEnvironment {
    private static let didInstall: Void = {
        guard let launcher = try? locateLauncher() else { return }
        setenv("LEARN_LAUNCHER_PATH", launcher, 1)
    }()

    /// 실제 서브프로세스 러너(swiftc·python3)를 쓰는 통합 테스트가 맨 먼저 부른다.
    static func install() { _ = didInstall }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EditorFeatureTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LearnKit
    }

    private static func locateLauncher() throws -> String {
        if let override = ProcessInfo.processInfo.environment["LEARN_LAUNCHER_PATH"],
            FileManager.default.isExecutableFile(atPath: override)
        {
            return override
        }
        let build = packageRoot.appendingPathComponent(".build")
        var candidates: [String] = [
            build.appendingPathComponent("debug/learn-launcher").path,
            build.appendingPathComponent("release/learn-launcher").path,
        ]
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: build.path) {
            for entry in entries.sorted() {
                candidates.append(build.appendingPathComponent("\(entry)/debug/learn-launcher").path)
                candidates.append(build.appendingPathComponent("\(entry)/release/learn-launcher").path)
            }
        }
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        struct NotBuilt: Error, CustomStringConvertible {
            let description = "learn-launcher 빌드 산출물을 찾지 못했다."
        }
        throw NotBuilt()
    }
}

/// 비동기 동작 중간에서 멈춰 세우는 문. 벽시계 `sleep` 로 "아직 끝나지 않은 순간"을
/// 흉내 내면 타이밍에 따라 흔들린다 — 이 문은 `open()` 을 부를 때까지 **결정적으로**
/// 열리지 않는다.
actor Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

/// `@Sendable` 클로저가 캡처할 수 있는 가변 상자. 테스트가 클로저 호출 횟수·순서를
/// 세는 용도로만 쓴다 — 실제 상태는 여전히 `EditorModel` 이 갖는다.
///
/// `nonisolated` — 이 테스트 타깃의 기본 격리도 `MainActor` 라, 표시가 없으면
/// `@Sendable` 클로저(`EditorGraderFactory` 등) 안에서 값을 못 바꾼다.
nonisolated final class Box<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) { storage = value }

    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

/// 프로세스를 띄우지 않는 채점기. 상태 전이 테스트가 `SwiftTestingGrader`·
/// `SQLResultSetGrader` 없이 `EditorModel.grade()` 의 배선만 검증하게 한다.
enum FakeGrader {
    static func succeeding(_ result: GradeResult) -> EditorGraderFactory {
        { _, _ in EditorGradeOutcome(result: result) }
    }

    static func failing(_ error: any Error) -> EditorGraderFactory {
        { _, _ in throw error }
    }
}

/// 테스트가 조립하는 최소 `EditorTask`. 실제 화면이 받는 것과 같은 값 타입이고,
/// 팩 로더가 아직 없으므로(`{#pack-format-spec}`) 테스트가 직접 채운다.
enum SampleTask {
    static func swift(
        starter: String = "struct Counter {\n    var count = 0\n}\n",
        testSource: String? = nil,
        testCount: Int = 3
    ) -> EditorTask {
        EditorTask(
            trackCaption: "Swift · 레슨 07 / 24",
            lessonTitle: "값 타입과 참조 타입",
            blockCaption: "블록 4 / 6 · 테스트 과제",
            taskOrdinalLabel: "04 테스트 과제",
            prose: "`Counter` 를 값 타입(`struct`)으로 유지한 채 고치세요.",
            language: .swift,
            entryFileName: "main.swift",
            starterSource: starter,
            testSource: testSource,
            testCount: testCount
        )
    }

    static func sql(database: URL?, solution: String, testCount: Int = 1) -> EditorTask {
        EditorTask(
            trackCaption: "SQL · 레슨 12 / 22",
            lessonTitle: "LEFT JOIN 과 NULL",
            blockCaption: "블록 4 / 6 · 테스트 과제",
            taskOrdinalLabel: "04 테스트 과제",
            prose: "회원별 체크인 횟수를 구하세요.",
            language: .sql,
            entryFileName: "query.sql",
            starterSource: "SELECT 1;",
            solutionSource: solution,
            database: database,
            testCount: testCount
        )
    }
}

/// 실측 SQL 픽스처. `InProcessRunner` 는 읽기 전용(authorizer 가 INSERT·CREATE 를
/// 막는다)이라 픽스처 DB 는 러너 **밖**에서 raw SQLite3 로 만든다 —
/// `RunnerKitTests.SQLTestDatabase` 와 같은 이유·같은 방식이다.
enum SQLFixtureDatabase {
    /// `design/ResultSQL.dc.html` 의 헬스장 체크인 시나리오. `Tushar Chandra`·
    /// `Bob Bell` 은 체크인이 한 번도 없다 — INNER JOIN 이 그 둘을 지운다.
    static let schema = """
        CREATE TABLE members (
            id     INTEGER PRIMARY KEY,
            name   TEXT NOT NULL,
            status TEXT NOT NULL
        );
        INSERT INTO members (id, name, status) VALUES
            (1, 'Annabel Miller', 'gold'),
            (2, 'Jeremy Bowers', 'gold'),
            (3, 'Joe Germuska', 'regular'),
            (4, 'Morty Schapiro', 'silver'),
            (5, 'Bob Bell', 'regular'),
            (6, 'Tushar Chandra', 'silver');

        CREATE TABLE checkins (
            member_id INTEGER NOT NULL,
            day       TEXT NOT NULL
        );
        INSERT INTO checkins (member_id, day) VALUES
            (1, '2026-01-01'), (1, '2026-01-02'), (1, '2026-01-03'), (1, '2026-01-04'), (1, '2026-01-05'),
            (2, '2026-01-01'), (2, '2026-01-02'), (2, '2026-01-03'), (2, '2026-01-04'),
            (3, '2026-01-01'), (3, '2026-01-02'),
            (4, '2026-01-01');
        """

    /// LEFT JOIN 정답 — 체크인이 없는 회원도 0으로 포함한다.
    static let correctSolution = """
        SELECT m.name, m.status, COUNT(c.member_id) AS checkins
        FROM members m LEFT JOIN checkins c ON c.member_id = m.id
        GROUP BY m.id
        ORDER BY checkins DESC, m.name;
        """

    /// 흔한 오답 — INNER JOIN 이라 체크인 0인 회원이 사라진다.
    static let innerJoinMistake = """
        SELECT m.name, m.status, COUNT(c.member_id) AS checkins
        FROM members m JOIN checkins c ON c.member_id = m.id
        GROUP BY m.id
        ORDER BY checkins DESC, m.name;
        """

    static func create(at url: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let database = handle else {
            struct Failure: Error {}
            throw Failure()
        }
        defer { sqlite3_close_v2(database) }
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, schema, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "알 수 없는 오류"
            sqlite3_free(errorMessage)
            struct Failure: Error, CustomStringConvertible { let description: String }
            throw Failure(description: message)
        }
    }

    static func withDatabase<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("editorfeature-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("gym.db")
        try create(at: databaseURL)
        return try await body(databaseURL)
    }
}
