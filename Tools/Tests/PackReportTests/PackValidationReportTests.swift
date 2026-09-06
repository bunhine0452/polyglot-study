import Testing
import Foundation
@testable import PackReport

@Suite("팩 검증 리포트")
struct PackValidationReportTests {
    private func report(failures: [PackValidationReport.Failure] = []) -> PackValidationReport {
        PackValidationReport(
            packID: "polyglot-mvp",
            packVersion: "1.0.0",
            validatedAt: 1_767_225_600_000,
            stagesRun: [.structural, .syntax, .semantic],
            lessons: [
                .init(stableID: "python.fstring", language: "python", title: "f-string", failures: failures)
            ]
        )
    }

    @Test("정규 JSON 은 두 번 써도 바이트가 같다")
    func canonicalJSONIsStable() throws {
        let r = report()
        #expect(try r.canonicalJSON() == r.canonicalJSON())
    }

    @Test("왕복해도 값이 보존된다")
    func roundTrips() throws {
        let r = report(failures: [
            .init(stage: .execution, kind: .starterAlreadyPasses, blockID: "task-1",
                  summary: "starter 가 이미 통과합니다", evidence: "Test run with 2 tests passed")
        ])
        #expect(try PackValidationReport.decode(r.canonicalJSON()) == r)
    }

    @Test("모르는 스키마 버전은 조용히 넘어가지 않는다")
    func rejectsUnknownSchemaVersion() throws {
        var r = report()
        r.schemaVersion = 99
        let data = try r.canonicalJSON()
        #expect(throws: ReportError.self) { try PackValidationReport.decode(data) }
    }

    @Test("실행 게이트가 안 돌았으면 통과를 통과로 읽지 않는다")
    func executionStageIsObservable() {
        #expect(report().isClean)
        #expect(report().executionStageRan == false, "실행 단계 없이 clean 이면 반쪽 검증이다")
    }
}
