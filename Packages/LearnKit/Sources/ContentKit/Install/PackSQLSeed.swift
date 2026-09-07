public import Foundation
internal import SQLite3

/// SQL 트랙이 대상으로 삼을 데이터베이스를 팩의 시드 스크립트로 굽는다.
///
/// ## 규약 (v1)
///
/// `assets/` 아래의 `*.sql` **전부**를 경로 사전순으로 새 데이터베이스에 차례로
/// 적용한다. 그 결과 하나가 이 팩의 모든 SQL 블록이 보는 데이터베이스다.
///
/// 레슨별 데이터베이스를 지정하는 문법이 **아직 없다** — `@Example` 과 `@Task` 의 인자에
/// 데이터베이스를 가리키는 자리가 없고, 매니페스트에도 없다. 팩 하나에 SQL 트랙 하나가
/// 있는 MVP 에서는 팩 전체가 하나의 시드를 공유하는 것이 맞고, 레슨마다 다른 표가
/// 필요해지는 시점에 디렉티브 인자(`database:`)가 생겨야 한다.
///
/// `sqlite3` CLI 를 쓰지 않고 프로세스 안에서 굽는 이유는 실행기와 같다 — SQL 트랙은
/// 인프로세스 러너를 타므로 **툴체인 의존이 하나도 없어야** 한다. 여기서 CLI 를 부르면
/// SQL 검증이 sqlite3 설치 여부에 매달리게 된다.
///
/// - Note: `ContentKit` 에 있는 이유는 **앱과 `packtool` 이 같은 데이터베이스를 봐야**
///   하기 때문이다. 검증기가 통과시킨 SQL 과제가 앱에서 다른 표를 대상으로 채점되면
///   게이트는 아무것도 보장하지 못한다 — `ContentPack` 이 양쪽의 유일한 팩 창구인 것과
///   같은 이유다.
public enum PackSQLSeed {
    /// 구운 데이터베이스의 파일 이름. 호출자가 정리할 때 이름을 다시 적지 않도록 공개한다.
    public static let fileName = "pack-seed.db"

    /// - Returns: 구운 데이터베이스 경로. 시드 스크립트가 없으면 nil (인메모리로 돈다).
    public static func materialize(pack: ContentPack, into directory: URL) throws -> URL? {
        let scripts =
            pack.manifest.files
            .map(\.path)
            .filter { $0.hasPrefix(PackLayout.assetsDirectory + "/") && $0.hasSuffix(".sql") }
            .sorted()
        guard !scripts.isEmpty else { return nil }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destination)

        var handle: OpaquePointer?
        let opened = sqlite3_open_v2(
            destination.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard opened == SQLITE_OK, let database = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "코드 \(opened)"
            sqlite3_close(handle)
            throw SeedError.cannotOpen(path: destination.path, message: message)
        }
        defer { sqlite3_close(database) }

        for script in scripts {
            let url = pack.directory.appendingPathComponent(script)
            guard let data = FileManager.default.contents(atPath: url.path) else {
                throw SeedError.scriptMissing(path: script)
            }
            let sql = String(decoding: data, as: UTF8.self)
            var raw: UnsafeMutablePointer<CChar>?
            let status = sqlite3_exec(database, sql, nil, nil, &raw)
            if status != SQLITE_OK {
                let message = raw.map { String(cString: $0) } ?? "코드 \(status)"
                sqlite3_free(raw)
                throw SeedError.scriptFailed(path: script, message: message)
            }
            sqlite3_free(raw)
        }
        return destination
    }

    public enum SeedError: Error, Sendable, CustomStringConvertible {
        case cannotOpen(path: String, message: String)
        case scriptMissing(path: String)
        case scriptFailed(path: String, message: String)

        public var description: String {
            switch self {
            case .cannotOpen(let path, let message):
                "시드 데이터베이스를 만들 수 없다 (\(path)): \(message)"
            case .scriptMissing(let path):
                "시드 스크립트 \(path) 를 읽을 수 없다"
            case .scriptFailed(let path, let message):
                "시드 스크립트 \(path) 실행 실패: \(message)"
            }
        }
    }
}
