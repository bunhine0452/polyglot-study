import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("EnvironmentProbe — 부팅 시 SQLite 환경 실측")
struct EnvironmentProbeTests {
    @Test("fts5 · trigram · foreign_keys 를 실측한다", arguments: DatabaseFlavor.allCases)
    func measuresRuntimeEnvironment(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let environment = harness.database.environment

        // fts5_source_id() 는 "fts5: <날짜> <해시>" 형태를 낸다. 값 자체보다 "호출이 됐다" 가 핵심 —
        // FTS5 가 없으면 이 함수가 아예 없어서 부팅이 중단됐어야 한다.
        #expect(environment.fts5SourceID.hasPrefix("fts5:"))
        #expect(environment.trigramTokenizerAvailable)
        #expect(environment.foreignKeysEnabled)
        #expect(!environment.sqliteVersion.isEmpty)
        #expect(environment.journalMode.lowercased() == flavor.expectedJournalMode)
    }

    @Test("파일 DB 는 WAL 이고 인메모리는 memory 다")
    func journalModeDiffersByFlavor() throws {
        let file = try TestDatabase(.file)
        let memory = try TestDatabase(.inMemory)

        #expect(file.database.environment.isWriteAheadLogging)
        #expect(!memory.database.environment.isWriteAheadLogging)
    }

    @Test("기대와 다른 저널 모드는 validate 가 거부한다")
    func validateRejectsWrongJournalMode() throws {
        let probe = EnvironmentProbe(
            sqliteVersion: "3.51.1",
            fts5SourceID: "fts5: test",
            trigramTokenizerAvailable: true,
            journalMode: "delete",
            foreignKeysEnabled: true
        )
        #expect(throws: EnvironmentProbeError.unexpectedJournalMode(actual: "delete", expected: "wal")) {
            try probe.validate(expectedJournalMode: "wal")
        }
    }

    @Test("foreign_keys 가 꺼져 있으면 부팅을 중단한다")
    func validateRejectsDisabledForeignKeys() throws {
        let probe = EnvironmentProbe(
            sqliteVersion: "3.51.1",
            fts5SourceID: "fts5: test",
            trigramTokenizerAvailable: true,
            journalMode: "wal",
            foreignKeysEnabled: false
        )
        #expect(throws: EnvironmentProbeError.foreignKeysDisabled) {
            try probe.validate(expectedJournalMode: "wal")
        }
    }

    @Test("PRAGMA foreign_keys 가 실제 연결에서 켜져 있어 CASCADE 가 동작한다", arguments: DatabaseFlavor.allCases)
    func foreignKeysAreLiveOnConnection(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        #expect(try harness.database.scalarInt("PRAGMA foreign_keys") == 1)

        // 실측: submission 을 지우면 diagnostic 이 따라 지워져야 한다.
        let store = harness.database.submissionStore
        let id = try await store.record(
            Fixture.submission(diagnostics: [.init(severity: .error, message: "boom")])
        )
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM diagnostic") == 1)

        try harness.database.executeRaw("DELETE FROM submission WHERE id = \(id.rawValue)")
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM diagnostic") == 0)
    }
}
