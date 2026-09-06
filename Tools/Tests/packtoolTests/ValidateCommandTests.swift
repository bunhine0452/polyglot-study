import ArgumentParser
import PackReport
import PackValidate
import Testing

@testable import packtool

/// CLI 표면만 본다 — 플래그 해석과 사람이 읽는 한 줄. 검증 로직은 `PackValidateTests`.
@Suite("packtool validate CLI")
struct ValidateCommandTests {
    @Test("기본값 — 텍스트 리포트, 실행 게이트 켬, 툴체인 없으면 실패")
    func defaults() throws {
        let command = try ValidateCommand.parse(["Content/packs/polyglot-mvp"])
        #expect(command.packPath == "Content/packs/polyglot-mvp")
        #expect(command.report == .text)
        #expect(command.output == nil)
        #expect(command.allowMissingToolchain == false)
        #expect(command.jobs == nil)
    }

    @Test("리포트 형식과 출력 경로를 받는다")
    func parsesReportOptions() throws {
        let command = try ValidateCommand.parse(
            ["pack", "--report", "junit", "-o", "out.xml", "--allow-missing-toolchain", "-j", "3"])
        #expect(command.report == .junit)
        #expect(command.output == "out.xml")
        #expect(command.allowMissingToolchain)
        #expect(command.jobs == 3)
    }

    @Test("모르는 리포트 형식은 거부한다")
    func rejectsUnknownFormat() {
        #expect(throws: (any Error).self) {
            _ = try ValidateCommand.parse(["pack", "--report", "yaml"])
        }
    }

    @Test("형식 세 가지가 전부 붙어 있다")
    func formatsAreComplete() {
        #expect(ReportFormat.allCases.map(\.rawValue).sorted() == ["json", "junit", "text"])
    }

    @Test("한 줄 요약이 팩·결과·단계를 담는다")
    func summaryLine() {
        let report = PackValidationReport(
            packID: "polyglot-mvp", packVersion: "1.0.0", validatedAt: 0,
            stagesRun: [.structural, .syntax, .semantic],
            lessons: [
                .init(
                    stableID: "py-0001", language: "python", title: "제목",
                    failures: [
                        .init(stage: .execution, kind: .exampleFailedToRun, summary: "안 돈다")
                    ])
            ])
        let line = ValidateCommand.summary(
            ValidationOutcome(report: report, skipNotes: ["python: 없다"]))
        #expect(line.contains("polyglot-mvp@1.0.0"))
        #expect(line.contains("실패 1건"))
        #expect(line.contains("execution(미실행)"))
        #expect(line.contains("건너뜀 — python: 없다"))
    }

    /// 정규화 규칙과 "툴체인 없으면 실패" 규약은 `--help` 에 적혀 있어야 한다.
    /// 스펙이 코드 주석에만 있으면 도구를 쓰는 사람에게는 없는 것과 같다.
    @Test("도움말이 스펙을 말한다")
    func helpCarriesSpec() {
        let help = ValidateCommand.helpMessage(columns: 100)
        #expect(help.contains("CRLF"))
        #expect(help.contains("후행 개행"))
        #expect(help.contains("starter"))
        #expect(help.contains("--allow-missing-toolchain"))
        #expect(help.contains("종료 코드"))
    }
}
