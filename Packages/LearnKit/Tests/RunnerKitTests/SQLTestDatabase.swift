import Foundation
import SQLite3

/// 테스트용 샘플 DB. **코드로 만든다** — 픽스처 바이너리를 커밋하면 스키마가 바뀔 때마다
/// 리뷰할 수 없는 diff 가 생기고, SQLite 파일 포맷은 같은 SQL 로도 바이트가 달라진다.
enum SQLTestDatabase {
    /// 채점 케이스를 전부 담은 작은 스키마.
    ///
    /// `nickname` 에 NULL·빈 문자열·0 이 한 행씩 들어 있다 — 이 셋을 구분하지 못하는
    /// 채점기는 SQL 을 가르칠 수 없다.
    static let schema = """
        CREATE TABLE members (
            id       INTEGER PRIMARY KEY,
            name     TEXT NOT NULL,
            city     TEXT,
            score    REAL,
            nickname TEXT
        );
        INSERT INTO members (id, name, city, score, nickname) VALUES
            (1, 'Ada',   'Seoul',  10.0,  NULL),
            (2, 'Grace', 'Busan',  10,    ''),
            (3, 'Linus', 'Seoul',  7.5,   '0'),
            (4, 'Alan',  NULL,     10.0,  'al'),
            (5, 'Edsger','Seoul',  0.0,   'ed');

        CREATE TABLE visits (
            member_id INTEGER NOT NULL,
            city      TEXT NOT NULL
        );
        INSERT INTO visits (member_id, city) VALUES
            (1, 'Seoul'), (1, 'Seoul'), (2, 'Busan'), (3, 'Seoul'), (3, 'Seoul');
        """

    /// - Parameter schema: 기본은 위 샘플. 레슨마다 DB 가 다른 상황을 재현할 때만 바꾼다.
    static func create(at url: URL, schema: String = SQLTestDatabase.schema) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let database = handle else {
            throw Failure(message: "샘플 DB 를 만들 수 없습니다: \(url.path)")
        }
        defer { sqlite3_close_v2(database) }
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, schema, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "알 수 없는 오류"
            sqlite3_free(errorMessage)
            throw Failure(message: "스키마 적용 실패: \(message)")
        }
    }

    /// 임시 디렉터리에 DB 를 만들고 블록이 끝나면 통째로 지운다.
    static func withDatabase<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("study.db")
        try create(at: databaseURL)
        return try await body(databaseURL)
    }

    struct Failure: Error, CustomStringConvertible {
        var message: String
        var description: String { message }
    }

    /// 원본이 손대지지 않았는지 판정하는 데 쓰는 지문.
    struct Fingerprint: Equatable {
        var modificationDate: Date
        var size: Int
        var digest: Data

        init(of url: URL) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            modificationDate = attributes[.modificationDate] as? Date ?? .distantPast
            size = attributes[.size] as? Int ?? -1
            digest = try Data(contentsOf: url)
        }
    }
}
