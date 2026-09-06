import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("마이그레이션 정책과 골든 스키마")
struct MigrationPolicyTests {
    @Test("마이그레이션 001~005 가 순서대로 전부 적용된다", arguments: DatabaseFlavor.allCases)
    func allMigrationsApply(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        #expect(try harness.database.appliedMigrations() == SchemaMigrations.identifiers)
    }

    @Test("식별자는 번호 접두사를 갖고 사전순 = 적용순이다")
    func identifiersAreOrdered() {
        #expect(SchemaMigrations.identifiers == SchemaMigrations.identifiers.sorted())
        for identifier in SchemaMigrations.identifiers {
            let startsWithNumber = identifier.prefix(3).allSatisfy { $0.isNumber }
            #expect(startsWithNumber, "번호로 시작하지 않는다: \(identifier)")
        }
        #expect(Set(SchemaMigrations.identifiers).count == SchemaMigrations.identifiers.count)
    }

    @Test("전체 마이그레이션 후 스키마 덤프가 체크인 픽스처와 바이트 일치", arguments: DatabaseFlavor.allCases)
    func schemaMatchesGoldenSnapshot(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let dump = try harness.database.schemaDump()

        // 바이트 비교. 다르면 어디가 다른지 첫 줄을 알려준다 — 통짜 diff 는 읽기 어렵다.
        if dump != GoldenSchema.dump {
            let actual = dump.split(separator: "\n", omittingEmptySubsequences: false)
            let expected = GoldenSchema.dump.split(separator: "\n", omittingEmptySubsequences: false)
            let firstDifference = zip(actual, expected).enumerated().first { $0.element.0 != $0.element.1 }
            Issue.record("""
                스키마가 골든과 다르다.
                첫 불일치 \(firstDifference.map { "\($0.offset + 1)행" } ?? "행 수 (\(actual.count) vs \(expected.count))")
                  실제: \(firstDifference?.element.0 ?? "—")
                  기대: \(firstDifference?.element.1 ?? "—")
                의도한 변경이면 새 번호의 마이그레이션을 추가한 뒤 골든을 다시 굽는다.
                """)
        }
        #expect(dump == GoldenSchema.dump)
    }

    @Test("두 주입의 스키마가 동일하다")
    func fileAndMemorySchemasMatch() throws {
        let memory = try TestDatabase(.inMemory)
        let file = try TestDatabase(.file)
        #expect(try memory.database.schemaDump() == file.database.schemaDump())
    }

    @Test("같은 파일을 다시 열어도 마이그레이션이 다시 돌지 않는다")
    func reopeningIsIdempotent() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("LearnKitReopen-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("learn.sqlite")

        let first = try LearnDatabase.open(at: url)
        let dumpBefore = try first.schemaDump()
        // 시드가 두 번 들어가면 여기서 UNIQUE 위반이 나거나 활성 세트가 둘이 된다.
        #expect(try first.scalarInt("SELECT COUNT(*) FROM scheduler_parameters") == 1)

        let second = try LearnDatabase.open(at: url)
        #expect(try second.schemaDump() == dumpBefore)
        #expect(try second.scalarInt("SELECT COUNT(*) FROM scheduler_parameters") == 1)
        #expect(try second.appliedMigrations() == SchemaMigrations.identifiers)
    }

    /// `{#migration-rules}` 의 CI grep. 테스트로 두는 이유는 CI 설정 파일보다 여기가 안 잊히기 때문이다.
    @Test("스키마 변경 시 DB 를 지우는 GRDB 편의 플래그가 소스에 0건")
    func noEraseOnSchemaChangeFlag() throws {
        // 플래그 이름을 조각으로 만들어 이 테스트 파일 자신이 grep 에 걸리지 않게 한다.
        let flag = "eraseDatabase" + "OnSchemaChange"
        var offenders: [String] = []
        for file in try SourceTree.swiftFiles(under: "Sources") {
            let contents = try String(contentsOf: file, encoding: .utf8)
            if contents.contains(flag) { offenders.append(file.lastPathComponent) }
        }
        #expect(offenders.isEmpty, "DEBUG 에서도 금지다: \(offenders)")
    }

    /// `{#grdb-pin}` 의 완료 기준.
    ///
    /// 판정은 **줄 단위**다. 왜 GRDB 를 public 으로 못 내보내는지 주석으로 설명해 둔 파일이
    /// 있어서(`DomainColumns.swift`) 통짜 문자열 검색은 자기 자신의 근거 문서에 걸린다.
    /// `learnCoreIsGRDBFree` 도 같은 이유로 줄 단위다 — 언급은 괜찮고 import 가 금지다.
    @Test("public import GRDB 가 0건이고 GRDB 는 LearnPersistence 안에만 있다")
    func grdbStaysInternal() throws {
        var publicImports: [String] = []
        var leakedOutsidePersistence: [String] = []

        for file in try SourceTree.swiftFiles(under: "Sources") {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let importLines = contents
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasSuffix("import GRDB") || $0.contains("import GRDB.") }
            guard !importLines.isEmpty else { continue }

            if importLines.contains(where: { $0.hasPrefix("public ") || $0.hasPrefix("@_exported") }) {
                publicImports.append(file.lastPathComponent)
            }
            if !file.path.contains("/Sources/LearnPersistence/") {
                leakedOutsidePersistence.append(file.lastPathComponent)
            }
        }

        #expect(publicImports.isEmpty, "public import GRDB: \(publicImports)")
        #expect(leakedOutsidePersistence.isEmpty, "GRDB 가 새어나갔다: \(leakedOutsidePersistence)")
    }

    /// `{#core-contracts}` — LearnCore 는 GRDB 없이 컴파일돼야 한다.
    ///
    /// 주석에서 GRDB 를 **언급**하는 것은 괜찮다(왜 이렇게 나눴는지 설명해야 한다).
    /// 금지되는 것은 import 와 타입 사용이다.
    @Test("LearnCore 소스에 GRDB import 가 0건")
    func learnCoreIsGRDBFree() throws {
        var offenders: [String] = []
        for file in try SourceTree.swiftFiles(under: "Sources/LearnCore") {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let importsGRDB = contents
                .split(separator: "\n")
                .contains { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return trimmed.hasSuffix("import GRDB") || trimmed.contains("import GRDB.")
                }
            if importsGRDB { offenders.append(file.lastPathComponent) }
        }
        #expect(offenders.isEmpty, "LearnCore 가 GRDB 를 import 한다: \(offenders)")
    }

    /// 구조적 보장도 함께 확인한다 — Package.swift 의 LearnCore 타깃에 GRDB 의존이 없어야 한다.
    @Test("Package.swift 의 LearnCore 타깃에 GRDB 의존이 없다")
    func learnCoreTargetHasNoGRDBDependency() throws {
        let manifest = try String(
            contentsOf: SourceTree.packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        guard let line = manifest
            .split(separator: "\n")
            .first(where: { $0.contains("name: \"LearnCore\"") })
        else {
            Issue.record("Package.swift 에서 LearnCore 타깃을 찾지 못했다")
            return
        }
        #expect(!line.contains("GRDB"))
    }

    /// `{#derived-rebuild-idiom}` — 파생 재구축이 review_log 를 건드리면 던진다.
    @Test("파생 재구축 관용구는 review_log 행 수 불변을 단언한다", arguments: DatabaseFlavor.allCases)
    func derivedRebuildAssertsLogIsUntouched(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let log = harness.database.reviewLogStore
        try await log.append(Fixture.reviewEntry())
        try await log.append(Fixture.reviewEntry(at: 1))

        let before = try await log.count()
        try await harness.database.cardStateStore.replaceAll(with: [Fixture.cardState()])
        try await harness.database.cardStateStore.deleteAll()
        #expect(try await log.count() == before)
    }
}
