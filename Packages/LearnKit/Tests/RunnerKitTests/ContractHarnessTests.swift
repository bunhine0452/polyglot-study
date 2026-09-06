import Foundation
import Testing
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("러너 계약 하네스", .serialized)
struct ContractHarnessTests {

    @Test("InProcessRunner 가 계약 스위트 전 케이스를 통과한다", .timeLimit(.minutes(3)))
    func inProcessRunnerSatisfiesContract() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(databaseURL: nil),
            language: .sql,
            backendName: "InProcessRunner"
        )
        let report = await harness.run()
        #expect(report.isSatisfied, "\n\(report.summary)")
        // 전부 skip 되면 통과처럼 보이므로 실제로 돌린 케이스 수를 못박는다.
        #expect(report.passed.count == 7, "\n\(report.summary)")
    }

    @Test("지원하지 않는 케이스는 실패가 아니라 skip 이다")
    func unsupportedCasesAreSkipped() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(databaseURL: nil),
            language: .sql,
            backendName: "InProcessRunner"
        )
        let report = await harness.run(only: [.standardInput, .forkBomb, .grandchildProcess])
        #expect(report.results.count == 3)
        #expect(report.skipped.count == 3)
        #expect(report.failures.isEmpty)
        #expect(report.isSatisfied)
    }

    @Test("ContractSupport 는 capabilities 에서 유도된다")
    func supportIsInferredFromCapabilities() {
        let sqlSupport = ContractSupport.inferred(from: InProcessRunner(databaseURL: nil).capabilities)
        #expect(sqlSupport.contains(.baseline))
        #expect(sqlSupport.contains(.diagnostics))
        #expect(!sqlSupport.contains(.standardInput))
        #expect(!sqlSupport.contains(.processIsolation))

        let subprocessLike = ContractSupport.inferred(from: [.standardInput, .compileDiagnostics])
        #expect(subprocessLike.contains(.standardInput))
    }

    @Test("지원을 좁히면 그만큼 skip 된다")
    func narrowingSupportSkipsMore() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(databaseURL: nil),
            language: .sql,
            support: [.exitCodes, .diagnostics],
            backendName: "InProcessRunner(제한)"
        )
        let report = await harness.run()
        #expect(report.passed.count == 1)
        #expect(report.passed.first?.id == .exitCode)
        #expect(report.skipped.count == 9)
        #expect(report.isSatisfied)
    }

    @Test("계약 스위트는 10개 케이스를 정의한다")
    func caseCatalogIsStable() {
        let ids = RunnerContractTests.allCases.map(\.id)
        #expect(ids.count == 10)
        #expect(Set(ids).count == 10)
        #expect(ids.contains(.timeout))
        #expect(ids.contains(.infiniteLoop))
        #expect(ids.contains(.outputFlood))
        #expect(ids.contains(.hugeSingleLine))
        #expect(ids.contains(.nonUTF8Output))
        #expect(ids.contains(.cancellation))
        #expect(ids.contains(.exitCode))
        #expect(ids.contains(.standardInput))
    }

    @Test("픽스처 카탈로그는 아직 못 돌리는 언어도 데이터로 갖고 있다")
    func catalogCarriesFutureLanguages() {
        let catalog = ContractFixtureCatalog.standard
        #expect(catalog.languages.contains(.sql))
        #expect(catalog.languages.contains(.python))
        #expect(catalog.languages.contains(.swift))

        // SQL 은 stdin 이 없어서 픽스처 자체가 없다.
        #expect(catalog[.sql, .standardInput] == nil)
        // 서브프로세스 백엔드가 붙는 날 그대로 쓰일 것들.
        #expect(catalog[.python, .standardInput] != nil)
        #expect(catalog[.python, .forkBomb] != nil)
        #expect(catalog[.swift, .grandchildProcess] != nil)
        #expect(catalog.fixtures(for: .python).count == 10)
    }

    @Test("픽스처가 없는 언어는 전부 skip 된다")
    func missingFixturesSkip() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(databaseURL: nil),
            language: LanguageID("nonexistent"),
            backendName: "InProcessRunner"
        )
        let report = await harness.run()
        #expect(report.skipped.count == RunnerContractTests.allCases.count)
        #expect(report.isSatisfied)
    }
}
