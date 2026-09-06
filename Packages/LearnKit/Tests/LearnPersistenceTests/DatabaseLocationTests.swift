import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// `{#db-location}` — DB 경로는 Application Support 하나로 고정하고 동기 폴더는 금지한다.
@Suite("DB 위치 정책")
struct DatabaseLocationTests {
    @Test("기본 경로는 Application Support/LearnKit/learn.sqlite 다")
    func defaultPathIsUnderApplicationSupport() throws {
        let url = try DatabaseLocation.defaultURL()
        #expect(url.lastPathComponent == "learn.sqlite")
        #expect(url.deletingLastPathComponent().lastPathComponent == "LearnKit")

        let components = url.pathComponents
        #expect(components.contains("Application Support"), "\(url.path)")
        // 사용자가 실수로 열어볼 만한 곳(Documents·Desktop)에 있으면 안 된다.
        #expect(!components.contains("Documents"))
        #expect(!components.contains("Desktop"))
        #expect(DatabaseLocation.fileName == "learn.sqlite")
        #expect(DatabaseLocation.directoryName == "LearnKit")
    }

    @Test(
        "동기 폴더 경로는 전부 거부된다",
        arguments: [
            "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/learn.sqlite",
            "/Users/me/Library/Mobile Documents/iCloud~com~example~app/learn.sqlite",
            "/Users/me/Library/CloudStorage/Dropbox/learn.sqlite",
            "/Users/me/Library/CloudStorage/OneDrive-Personal/learn.sqlite",
            "/Users/me/Library/CloudStorage/GoogleDrive-me@example.com/My Drive/learn.sqlite",
            "/Users/me/Dropbox/LearnKit/learn.sqlite",
            "/Users/me/Dropbox (Personal)/learn.sqlite",
            "/Users/me/OneDrive/learn.sqlite",
            "/Users/me/Google Drive/learn.sqlite",
            "/Users/me/Sync.com/learn.sqlite",
            "/Users/me/pCloud Drive/learn.sqlite",
        ]
    )
    func syncedFoldersAreRejected(path: String) throws {
        #expect(DatabaseLocation.syncRejectionReason(forPath: path) != nil, "\(path)")
        #expect(throws: DatabaseLocation.LocationError.self) {
            try DatabaseLocation.validate(URL(fileURLWithPath: path))
        }
    }

    @Test(
        "동기 폴더가 아닌 경로는 통과한다",
        arguments: [
            "/Users/me/Library/Application Support/LearnKit/learn.sqlite",
            "/Users/me/Library/Containers/com.example.app/Data/learn.sqlite",
            "/tmp/LearnKitTests/learn.sqlite",
            // 이름에 우연히 비슷한 단어가 들어간 경우까지 막으면 안 된다.
            "/Users/me/Projects/dropbox-clone/learn.sqlite",
            "/Users/me/Documents/mydrive/learn.sqlite",
        ]
    )
    func ordinaryPathsPass(path: String) throws {
        #expect(DatabaseLocation.syncRejectionReason(forPath: path) == nil, "\(path)")
        try DatabaseLocation.validate(URL(fileURLWithPath: path))
    }

    @Test("동기 폴더에 열려고 하면 LearnDatabase.open 이 파일을 만들지 않고 던진다")
    func openRefusesSyncedFolder() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("LearnKitSync-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Dropbox", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base.deletingLastPathComponent()) }

        let url = base.appendingPathComponent("learn.sqlite")
        #expect(throws: DatabaseLocation.LocationError.self) {
            _ = try LearnDatabase.open(at: url)
        }
        // 디렉터리 생성보다 검증이 먼저다 — 거부된 경로에 흔적이 남으면 안 된다.
        #expect(!FileManager.default.fileExists(atPath: base.path))
    }

    @Test("열면 WAL 형제 파일이 같은 디렉터리에 생긴다")
    func walSiblingsLiveNextToTheDatabase() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("LearnKitWAL-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("learn.sqlite")
        let database = try LearnDatabase.open(at: url)
        try await database.reviewLogStore.append(Fixture.reviewEntry())

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: url.path + "-wal"))
        // 이 형제 파일들이 동기 폴더에서 따로 움직이면 DB 가 깨진다 — 금지 정책의 근거다.
        #expect(database.environment.isWriteAheadLogging)
    }

    @Test("상위 디렉터리가 없으면 만든다")
    func createsMissingDirectories() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("LearnKitDeep-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("nested/LearnKit", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(
                at: directory.deletingLastPathComponent().deletingLastPathComponent()
            )
        }
        _ = try LearnDatabase.open(at: directory.appendingPathComponent("learn.sqlite"))
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }
}
