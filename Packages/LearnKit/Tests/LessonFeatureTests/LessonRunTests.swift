import ContentKit
import DesignSystem
import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import LessonFeature

@Suite("레슨 실행 · 출력 슬롯과 RunEvent 스트림")
struct LessonRunTests {
    /// 예제 블록으로 옮긴 모델.
    static func exampleModel(_ events: [RunEvent]) throws -> LessonModel {
        let model = try SampleLesson.model(events: events)
        model.advance()
        return model
    }

    @Test("실행 전 출력 슬롯이 비어 있고 상태가 '실행 전' 이다")
    func slotIsEmptyBeforeRun() throws {
        let model = try SampleLesson.model()
        model.advance()
        #expect(model.transcript.isEmpty)
        #expect(model.transcript.statusLabel == "실행 전")
        #expect(model.runState == .idle)
        #expect(model.matchesExpectedOutput == nil)
    }

    @Test("출력 슬롯 높이가 실행 전후로 같다 — 상단 y 좌표가 1px 도 움직이지 않는다")
    func slotHeightIsUnchangedByAShortRun() async throws {
        let model = try Self.exampleModel(FakeRunner.succeeding(stdout: "parsed 42\n"))
        let before = ResultSlotMetrics.reservedHeight(lineCount: model.transcript.lines.count)
        await model.runExample()
        let after = ResultSlotMetrics.reservedHeight(lineCount: model.transcript.lines.count)
        #expect(model.transcript.lines.count == 1)
        #expect(before == after)
        #expect(after == Spacing.outputSlotHeight)
    }

    @Test("예약을 넘는 출력은 아래로만 자란다")
    func longOutputGrowsDownward() async throws {
        let lines = (0..<40).map { "줄 \($0)" }.joined(separator: "\n") + "\n"
        let model = try Self.exampleModel(FakeRunner.succeeding(stdout: lines))
        await model.runExample()
        #expect(model.transcript.lines.count == 40)
        #expect(
            ResultSlotMetrics.reservedHeight(lineCount: 40) > ResultSlotMetrics.reservedHeight(lineCount: 0)
        )
    }

    @Test("RunEvent 가 순서대로 상태에 반영된다")
    func eventsDriveState() async throws {
        let model = try Self.exampleModel([
            .phase(.preparing),
            .phase(.compiling),
            .phase(.running),
            .standardOutput(Data("parsed 42\n".utf8)),
            .standardError(Data("경고\n".utf8)),
            .finished(RunTermination.exitCode(0, durationMilliseconds: 42)),
        ])
        await model.runExample()

        #expect(model.runState == .finished(succeeded: true, exitCode: 0, durationMilliseconds: 42))
        #expect(!model.transcript.isRunning)
        #expect(model.transcript.exitCode == 0)
        #expect(model.transcript.durationMilliseconds == 42)
        #expect(model.transcript.lines.count == 2)
        #expect(model.transcript.standardOutputText == "parsed 42")
        #expect(model.transcript.hasErrorOutput)
    }

    @Test("실행 결과를 팩의 기대 출력과 대조한다")
    func comparesAgainstExpectedSidecar() async throws {
        let matching = try Self.exampleModel(FakeRunner.succeeding(stdout: "parsed 42\n"))
        await matching.runExample()
        #expect(matching.matchesExpectedOutput == true)

        let mismatching = try Self.exampleModel(FakeRunner.succeeding(stdout: "no value\n"))
        await mismatching.runExample()
        #expect(mismatching.matchesExpectedOutput == false)
    }

    @Test("0 이 아닌 종료 코드는 실패로 남는다")
    func nonZeroExit() async throws {
        let model = try Self.exampleModel([
            .standardError(Data("boom\n".utf8)),
            .finished(RunTermination.exitCode(1, durationMilliseconds: 7)),
        ])
        await model.runExample()
        #expect(model.runState == .finished(succeeded: false, exitCode: 1, durationMilliseconds: 7))
        #expect(model.transcript.statusLabel == "종료 1")
    }

    @Test("진단은 트랜스크립트가 아니라 진단 목록으로 간다")
    func diagnosticsAreSeparate() async throws {
        let model = try Self.exampleModel([
            .diagnostic(Diagnostic(file: "main.swift", line: 3, severity: .error, message: "틀렸다")),
            .finished(RunTermination.exitCode(1, durationMilliseconds: 1)),
        ])
        await model.runExample()
        #expect(model.diagnostics.count == 1)
        #expect(model.diagnostics.first?.message == "틀렸다")
        #expect(model.transcript.isEmpty)
    }

    @Test("결과셋은 표 모델로 옮겨진다")
    func resultSetBecomesTable() async throws {
        let resultSet = ResultSet(
            columns: [.init(name: "category"), .init(name: "n", declaredType: "INTEGER")],
            rows: [
                [.text("paper"), .integer(2)],
                [.text("pen"), .null],
            ]
        )
        let model = try Self.exampleModel([
            .resultSet(resultSet),
            .finished(RunTermination.exitCode(0, durationMilliseconds: 3)),
        ])
        await model.runExample()

        let table = try #require(model.resultTable)
        #expect(table.columns.map(\.name) == ["category", "n"])
        #expect(table.columns[1].declaredType == "INTEGER")
        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.map(\.text) == ["paper", "2"])
        #expect(table.rows[1].cells[1].isNull)
        #expect(table.rows[1].cells[1].text == "NULL")
    }

    @Test("절단 이벤트가 한 줄로 표시된다")
    func truncationIsShown() async throws {
        let model = try Self.exampleModel([
            .standardOutput(Data("일부\n".utf8)),
            .truncated,
            .finished(RunTermination.exitCode(0, durationMilliseconds: 1)),
        ])
        await model.runExample()
        #expect(model.transcript.isTruncated)
        #expect(model.transcript.lines.contains { $0.stream == .note })
    }

    @Test("스트림이 던지면 실패 상태로 남고 실행 중이 풀린다")
    func failureUnlocksTheButton() async throws {
        let model = try SampleLesson.model()
        model.advance()
        let failing = LessonModel(
            content: model.content,
            runFactory: FakeRunner.failing(RunFailure.toolchainMissing(hint: "swiftc 가 없다"))
        )
        failing.advance()
        await failing.runExample()

        guard case .failed(let reason) = failing.runState else {
            Issue.record("실패 상태가 아니다: \(failing.runState)")
            return
        }
        #expect(reason.contains("swiftc 가 없다"))
        #expect(!failing.transcript.isRunning)
        #expect(failing.primaryActionIsEnabled)
    }

    @Test("종료 이벤트 없이 스트림이 닫혀도 버튼이 잠기지 않는다")
    func missingTerminationDoesNotHang() async throws {
        let model = try Self.exampleModel([.phase(.running)])
        await model.runExample()
        #expect(!model.runState.isBusy)
        #expect(!model.transcript.isRunning)
        #expect(model.primaryActionIsEnabled)
    }

    @Test("예제 블록이 아닌 곳에서는 실행이 아무 일도 하지 않는다")
    func runIsInertOutsideTheExampleBlock() async throws {
        let model = try SampleLesson.model(events: FakeRunner.succeeding(stdout: "x\n"))
        // 개념 블록에서도 runExample 은 example 블록을 태운다(모델은 블록 위치를 보지 않는다).
        // 대신 주 동작이 없으므로 화면에서 부를 방법이 없다.
        #expect(model.primaryAction == nil)
        await model.performPrimaryAction()
        #expect(model.transcript.isEmpty)
    }

    @Test("진입 파일 이름이 각 어댑터의 기본 진입점과 같다")
    func entryFileNames() {
        #expect(LessonModel.entryFileName(for: .python) == "main.py")
        #expect(LessonModel.entryFileName(for: .swift) == "main.swift")
        #expect(LessonModel.entryFileName(for: .sql) == "query.sql")
    }
}

@Suite("레슨 프리젠터 · 도메인 4케이스 → 표시 4케이스")
struct LessonPresentationTests {
    @Test("GradeResult.Presenter 네 케이스가 빠짐없이, 서로 다르게 대응된다")
    func fourCasesMapOneToOne() {
        #expect(GradeResult.Presenter.allCases.count == 4)
        let mapped = GradeResult.Presenter.allCases.map(LessonPresentation.presentation(for:))
        #expect(Set(mapped).count == 4)
        #expect(mapped == [.console, .table, .browser, .registers])
        // 철자가 같아야 로그·저장값이 두 열거형 사이에서 왕복한다.
        for presenter in GradeResult.Presenter.allCases {
            #expect(LessonPresentation.presentation(for: presenter).rawValue == presenter.rawValue)
        }
    }

    @Test("실제 뷰가 있는 것은 콘솔과 표 둘, 나머지는 준비중으로 간다")
    func routes() {
        #expect(LessonPresentation.presentation(for: .console).route == .console)
        #expect(LessonPresentation.presentation(for: .table).route == .table)
        #expect(LessonPresentation.presentation(for: .browser).route == .preparing)
        #expect(LessonPresentation.presentation(for: .registers).route == .preparing)
    }

    @Test("MVP 3트랙의 프리젠터가 백엔드 능력에서 나온다")
    func mvpLanguages() {
        #expect(LessonPresentation.presenter(for: .python) == .console)
        #expect(LessonPresentation.presenter(for: .swift) == .console)
        // 인프로세스 SQL 러너만 `RunEvent.resultSet` 을 낸다.
        #expect(LessonPresentation.presenter(for: .sql) == .table)
        #expect(LessonPresentation.presenter(for: LanguageID("rust")) == .console)
    }

    @Test("레슨 모델의 프리젠터가 레슨 언어를 따른다")
    func modelUsesLessonLanguage() throws {
        #expect(try SampleLesson.model(SampleLesson.swift).presentation == .console)
        #expect(try SampleLesson.model(SampleLesson.python).presentation == .console)
        #expect(try SampleLesson.model(SampleLesson.sql).presentation == .table)
    }
}
