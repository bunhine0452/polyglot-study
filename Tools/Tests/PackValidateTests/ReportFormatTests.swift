import Foundation
import PackReport
import Testing

@testable import PackValidate

@Suite("리포트 형식")
struct ReportFormatTests {
    private static func report(
        stagesRun: [PackValidationReport.Stage] = PackValidationReport.Stage.allCases,
        failures: [PackValidationReport.Failure] = []
    ) -> PackValidationReport {
        PackValidationReport(
            packID: "polyglot-mvp", packVersion: "1.0.0", validatedAt: 0,
            stagesRun: stagesRun,
            lessons: [
                .init(stableID: "py-0001", language: "python", title: "제목", failures: failures)
            ])
    }

    @Test("JUnit XML 은 레슨마다 suite, 단계마다 case 를 낸다")
    func junitShape() {
        let xml = JUnitReport.render(Self.report())
        #expect(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(xml.contains("<testsuite name=\"py-0001\""))
        for stage in PackValidationReport.Stage.allCases {
            #expect(xml.contains("name=\"\(stage.rawValue)\""))
        }
        #expect(xml.contains("failures=\"0\""))
    }

    @Test("돌지 않은 단계는 skipped 로 남는다 — 통과로 렌더하지 않는다")
    func notRunStagesAreSkipped() {
        let xml = JUnitReport.render(Self.report(stagesRun: [.structural, .syntax, .semantic]))
        #expect(xml.contains("<skipped message=\"이 단계는 돌지 않았다\"/>"))
    }

    @Test("실패는 kind 를 type 으로, 증거를 본문으로 싣는다")
    func failuresCarryEvidence() {
        let xml = JUnitReport.render(
            Self.report(failures: [
                .init(
                    stage: .execution, kind: .starterAlreadyPasses, blockID: "task-1",
                    summary: "starter 가 이미 통과한다", evidence: "PASS 2 tests", line: 3, column: 5)
            ]))
        #expect(xml.contains("type=\"starterAlreadyPasses\""))
        #expect(xml.contains("[task-1] starter 가 이미 통과한다 (3:5)"))
        #expect(xml.contains("PASS 2 tests"))
        #expect(xml.contains("failures=\"1\""))
    }

    @Test("XML 특수문자와 제어문자를 흘려보내지 않는다")
    func escapesHostileEvidence() {
        let xml = JUnitReport.render(
            Self.report(failures: [
                .init(
                    stage: .syntax, kind: .malformedDirective,
                    summary: "a < b & c", evidence: "</failure><x/>\u{0001}끝")
            ]))
        #expect(!xml.contains("</failure><x/>"))
        #expect(xml.contains("&lt;/failure&gt;"))
        #expect(xml.contains("a &lt; b &amp; c"))
        #expect(!xml.unicodeScalars.contains("\u{0001}"))
    }

    @Test("JSON 은 계약의 canonicalJSON 을 그대로 쓴다")
    func jsonIsCanonical() throws {
        let report = Self.report()
        #expect(try report.canonicalJSON() == report.canonicalJSON())
        #expect(try PackValidationReport.decode(report.canonicalJSON()) == report)
    }

    @Test("사람이 읽는 리포트는 미실행 단계를 말한다")
    func textReportNamesUnrunStages() {
        let outcome = ValidationOutcome(
            report: Self.report(stagesRun: [.structural, .syntax, .semantic]),
            skipNotes: ["python: 툴체인이 없다"])
        let text = TextReport.render(outcome)
        #expect(text.contains("execution(미실행)"))
        #expect(text.contains("python: 툴체인이 없다"))
        #expect(text.contains("'통과' 로 읽으면 안 된다"))
    }
}
