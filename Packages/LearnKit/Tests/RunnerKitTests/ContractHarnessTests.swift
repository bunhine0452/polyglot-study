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
            runner: InProcessRunner(),
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
            runner: InProcessRunner(),
            language: .sql,
            backendName: "InProcessRunner"
        )
        let report = await harness.run(only: [.standardInput, .forkBomb, .grandchildProcess])
        #expect(report.results.count == 3)
        #expect(report.skipped.count == 3)
        #expect(report.failures.isEmpty)
        #expect(report.isSatisfied)
    }

    @Test("ContractSupport 는 러너가 선언한 능력과 강제 가능 상한에서 유도된다")
    func supportIsInferredFromRunner() {
        let sqlSupport = ContractSupport.inferred(from: InProcessRunner())
        #expect(sqlSupport.contains(.baseline))
        #expect(sqlSupport.contains(.diagnostics))
        // 인프로세스가 실제로 막을 수 있는 것.
        #expect(sqlSupport.contains(.wallClockTimeout))
        #expect(sqlSupport.contains(.outputTruncation))
        #expect(sqlSupport.contains(.memoryLimit))
        // 막을 수단이 아예 없는 것.
        #expect(!sqlSupport.contains(.cpuTimeLimit))
        #expect(!sqlSupport.contains(.fileSizeLimit))
        #expect(!sqlSupport.contains(.processIsolation))
        #expect(!sqlSupport.contains(.standardInput))

        let subprocessLike = ContractSupport.inferred(
            capabilities: [.standardInput, .compileDiagnostics],
            enforcedLimits: .all
        )
        #expect(subprocessLike.contains(.standardInput))
        #expect(subprocessLike == .all)
    }

    @Test("강제할 수 없다고 선언한 상한의 케이스는 자동으로 skip 된다")
    func unenforceableLimitCasesAutoSkip() async throws {
        // 아무 상한도 못 거는 러너. 상한 계열 케이스 전부가 skip 으로 떨어져야 한다.
        let toothless = StubRunner(capabilities: [], enforcedLimits: .none)
        let toothlessSupport = ContractSupport.inferred(from: toothless)
        #expect(toothlessSupport == .baseline)

        let report = await RunnerContractTests(
            runner: toothless,
            language: .python,
            backendName: "StubRunner(무제한)"
        ).run()
        let skippedIDs = Set(report.skipped.map(\.id))
        for id: ContractCaseID in [
            .timeout, .infiniteLoop, .outputFlood, .cpuExhaustion,
            .memoryExhaustion, .fileSizeFlood, .forkBomb, .grandchildProcess,
        ] {
            #expect(skippedIDs.contains(id), "\(id) 가 skip 되지 않았습니다\n\(report.summary)")
        }
        // 반대쪽도 못박는다 — 의무 계열은 선언과 무관하게 **항상** 검사한다.
        // 아무것도 내지 않는 러너라면 skip 이 아니라 실패로 잡혀야 한다.
        for id: ContractCaseID in [.hugeSingleLine, .nonUTF8Output, .cancellation, .exitCode] {
            #expect(!skippedIDs.contains(id), "\(id) 는 의무라 skip 될 수 없습니다")
        }
        #expect(report.failures.count == 4, "\n\(report.summary)")

        // 상한마다 정확히 그 케이스만 열린다 — 하네스가 하드코딩으로 걸러내지 않는다는 증거.
        let cpuOnly = ContractSupport.inferred(capabilities: [], enforcedLimits: [.cpuTime])
        #expect(cpuOnly.contains(.cpuTimeLimit))
        #expect(!cpuOnly.contains(.wallClockTimeout))

        let processOnly = ContractSupport.inferred(capabilities: [], enforcedLimits: [.processCount])
        #expect(processOnly.contains(.processIsolation))
        #expect(!processOnly.contains(.memoryLimit))
    }

    @Test("지원을 좁히면 그만큼 skip 된다")
    func narrowingSupportSkipsMore() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(),
            language: .sql,
            support: [.terminationStatus, .diagnostics],
            backendName: "InProcessRunner(제한)"
        )
        let report = await harness.run()
        #expect(report.passed.count == 1)
        #expect(report.passed.first?.id == .exitCode)
        #expect(report.skipped.count == RunnerContractTests.allCases.count - 1)
        #expect(report.isSatisfied)
    }

    @Test("계약 스위트는 13개 케이스를 정의한다")
    func caseCatalogIsStable() {
        let ids = RunnerContractTests.allCases.map(\.id)
        #expect(ids.count == 13)
        #expect(Set(ids).count == 13)
        #expect(ids.contains(.timeout))
        #expect(ids.contains(.infiniteLoop))
        #expect(ids.contains(.outputFlood))
        #expect(ids.contains(.hugeSingleLine))
        #expect(ids.contains(.nonUTF8Output))
        #expect(ids.contains(.cancellation))
        #expect(ids.contains(.exitCode))
        #expect(ids.contains(.standardInput))
        #expect(ids.contains(.cpuExhaustion))
        #expect(ids.contains(.memoryExhaustion))
        #expect(ids.contains(.fileSizeFlood))
    }

    @Test("픽스처 카탈로그는 아직 못 돌리는 언어도 데이터로 갖고 있다")
    func catalogCarriesFutureLanguages() {
        let catalog = ContractFixtureCatalog.standard
        #expect(catalog.languages.contains(.sql))
        #expect(catalog.languages.contains(.python))
        #expect(catalog.languages.contains(.swift))

        // SQL 은 stdin 이 없어서 픽스처 자체가 없다.
        #expect(catalog[.sql, .standardInput] == nil)
        // 상한 계열 셋도 인프로세스에서는 잴 방법이 없다 — 데이터도 두지 않는다.
        #expect(catalog[.sql, .cpuExhaustion] == nil)
        #expect(catalog[.sql, .memoryExhaustion] == nil)
        #expect(catalog[.sql, .fileSizeFlood] == nil)
        // 서브프로세스·컨테이너 백엔드가 붙는 날 그대로 쓰일 것들.
        #expect(catalog[.python, .standardInput] != nil)
        #expect(catalog[.python, .forkBomb] != nil)
        #expect(catalog[.python, .cpuExhaustion] != nil)
        #expect(catalog[.python, .fileSizeFlood] != nil)
        #expect(catalog[.swift, .grandchildProcess] != nil)
        #expect(catalog[.swift, .memoryExhaustion] != nil)
        #expect(catalog.fixtures(for: .python).count == 13)
    }

    @Test("픽스처가 없는 언어는 전부 skip 된다")
    func missingFixturesSkip() async throws {
        let harness = RunnerContractTests(
            runner: InProcessRunner(),
            language: LanguageID("nonexistent"),
            backendName: "InProcessRunner"
        )
        let report = await harness.run()
        #expect(report.skipped.count == RunnerContractTests.allCases.count)
        #expect(report.isSatisfied)
    }
}

/// 아무 일도 하지 않는 러너. 하네스가 **선언만 보고** 케이스를 여닫는지 재는 데 쓴다.
struct StubRunner: CodeRunner {
    var capabilities: RunnerCapabilities
    var enforcedLimits: EnforcedLimits

    func run(_ request: RunRequest) -> AsyncThrowingStream<RunEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished(RunTermination(status: .succeeded, durationMilliseconds: 0)))
            continuation.finish()
        }
    }
}
