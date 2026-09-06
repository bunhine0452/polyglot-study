import DesignSystem
import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import EditorFeature

@Suite("에디터 모델 · 기본 상태")
struct EditorModelBasicsTests {
    @Test("초기 상태 — 코드는 시작 코드, 실행 전, 출력 탭")
    func initialState() {
        let model = EditorModel(task: SampleTask.swift())
        #expect(model.code == SampleTask.swift().starterSource)
        #expect(model.runState == .idle)
        #expect(model.gradeState == .notSubmitted)
        #expect(model.activeTab == .output)
        #expect(model.canRun)
        #expect(model.canSubmit)
        #expect(model.presenter == .console)
    }

    @Test("SQL 과제의 프리젠터는 table 이다")
    func sqlPresenterIsTable() {
        let model = EditorModel(task: SampleTask.sql(database: nil, solution: "SELECT 1;"))
        #expect(model.presenter == .table)
    }

    @Test("언어별 툴 이름")
    func toolNames() {
        #expect(EditorModel.toolName(for: .swift) == "swiftc")
        #expect(EditorModel.toolName(for: .python) == "python3")
        #expect(EditorModel.toolName(for: .sql) == "sqlite3")
    }
}

@Suite("에디터 모델 · 실행 (콘솔 경로)")
struct EditorModelRunTests {
    @Test("실행이 순서대로 상태에 반영된다")
    func runAppliesEventsInOrder() async {
        let model = EditorModel(
            task: SampleTask.swift(),
            runFactory: FakeRunner.factory(yielding: FakeRunner.succeeding(stdout: "42\n"))
        )
        await model.run()
        #expect(model.transcript.standardOutputText == "42")
        #expect(!model.transcript.isRunning)
        #expect(model.runState == .finished(succeeded: true, exitCode: 0, durationMilliseconds: 12))
        #expect(model.activeTab == .output)
    }

    @Test("실행 전 탭이 테스트였어도 실행을 누르면 출력 탭으로 돌아온다")
    func runResetsToOutputTab() async {
        let model = EditorModel(
            task: SampleTask.swift(),
            runFactory: FakeRunner.factory(yielding: FakeRunner.succeeding(stdout: ""))
        )
        model.activeTab = .tests
        await model.run()
        #expect(model.activeTab == .output)
    }

    @Test("진단은 diagnosticRows 로 조립되고 그 줄의 실제 소스를 담는다")
    func diagnosticsBecomeInlineRows() async {
        let source = "struct Counter {\n    var count = 0\n    func increment() {\n        count += 1\n    }\n}\n"
        let events: [RunEvent] = [
            .phase(.preparing),
            .phase(.compiling),
            .diagnostic(Diagnostic(
                file: "main.swift", line: 4, column: 9, severity: .error,
                message: "cannot assign to property: 'self' is immutable"
            )),
            .finished(RunTermination(status: .failed(code: 1), durationMilliseconds: 410)),
        ]
        let runningModel = EditorModel(
            task: SampleTask.swift(starter: source),
            runFactory: FakeRunner.factory(yielding: events)
        )
        await runningModel.run()

        #expect(runningModel.diagnostics.count == 1)
        let rows = runningModel.diagnosticRows
        #expect(rows.count == 1)
        #expect(rows[0].line == 4)
        #expect(rows[0].column == 9)
        #expect(rows[0].codeLine == "        count += 1")
        #expect(rows[0].locationLabel == "4행 9열 · swiftc · 1개")
        #expect(rows[0].message.contains("immutable"))
    }

    @Test("진단 스냅샷은 마지막 실행 시점 코드다 — 그 뒤 편집해도 안 바뀐다")
    func diagnosticSnapshotSurvivesLaterEdits() async {
        let original = "line one\nline two\n"
        let model = EditorModel(
            task: SampleTask.swift(starter: original),
            runFactory: FakeRunner.factory(yielding: [
                .diagnostic(Diagnostic(file: "main.swift", line: 2, severity: .error, message: "문제")),
                .finished(RunTermination(status: .failed(code: 1), durationMilliseconds: 1)),
            ])
        )
        await model.run()
        #expect(model.diagnosticRows.first?.codeLine == "line two")

        model.code = "완전히 다른 코드\n로 바꿨다\n"
        #expect(model.diagnosticRows.first?.codeLine == "line two", "편집 후에도 진단 스냅샷은 그대로여야 한다")
    }

    @Test("실행이 실패로 던지면 failed 상태로 남고 실행 중이 풀린다")
    func throwingRunFactoryFails() async {
        let model = EditorModel(
            task: SampleTask.swift(),
            runFactory: FakeRunner.failing(RunFailure.toolchainMissing(hint: "swiftc 가 없다"))
        )
        await model.run()
        guard case .failed(let reason) = model.runState else {
            Issue.record("실패 상태가 아니다: \(model.runState)")
            return
        }
        #expect(reason.contains("swiftc"))
        #expect(!model.transcript.isRunning)
    }

    @Test("실행 중에는 다시 실행할 수 없다")
    func cannotRunWhileBusy() async {
        // `Gate` 가 `open()` 을 부를 때까지 스트림이 끝나지 않는다 — 벽시계 `sleep` 이
        // 아니라 결정적 신호로 "아직 실행 중"인 순간을 만든다.
        let gate = Gate()
        let model = EditorModel(task: SampleTask.swift(), runFactory: { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.phase(.compiling))
                Task {
                    await gate.wait()
                    continuation.yield(.finished(RunTermination.exitCode(0, durationMilliseconds: 1)))
                    continuation.finish()
                }
            }
        })

        let task = Task { await model.run() }
        await Task.yield()
        #expect(model.runState.isBusy)
        #expect(!model.canRun)

        await gate.open()
        await task.value
        #expect(!model.runState.isBusy)
    }
}

@Suite("에디터 모델 · 제출 (채점)")
struct EditorModelGradeTests {
    @Test("제출이 채점 결과를 반영하고 테스트 탭으로 옮긴다")
    func submitAppliesGradeResult() async {
        let outcome = GradeResult(
            passed: true,
            tests: [.init(name: "count 는 0 에서 시작한다", passed: true)],
            durationMilliseconds: 5,
            presenter: .console
        )
        let model = EditorModel(task: SampleTask.swift(), graderFactory: FakeGrader.succeeding(outcome))
        await model.submit()
        #expect(model.gradeState == .graded(outcome))
        #expect(model.activeTab == .tests)
    }

    @Test("채점기가 던지면 failed 상태가 된다")
    func gradeFailureIsRecorded() async {
        let model = EditorModel(
            task: SampleTask.swift(),
            graderFactory: FakeGrader.failing(RunFailure.backend("빌드 실패"))
        )
        await model.submit()
        #expect(model.gradeState == .failed("빌드 실패"))
    }

    @Test("채점 중에는 실행도 제출도 다시 못 한다")
    func busyDuringGrading() async {
        let gate = Gate()
        let outcome = GradeResult(passed: true, durationMilliseconds: 0, presenter: .console)
        let model = EditorModel(task: SampleTask.swift(), graderFactory: { _, _ in
            await gate.wait()
            return EditorGradeOutcome(result: outcome)
        })

        let task = Task { await model.submit() }
        await Task.yield()
        #expect(model.gradeState.isBusy)
        #expect(!model.canSubmit)
        #expect(!model.canRun)

        await gate.open()
        await task.value
        #expect(!model.gradeState.isBusy)
        #expect(model.gradeState == .graded(outcome))
    }

    @Test("SQL 과제는 run() 도 submit() 도 같은 채점 경로를 탄다")
    func sqlRunAndSubmitBothGrade() async {
        let outcome = EditorGradeOutcome(
            result: GradeResult(passed: false, durationMilliseconds: 3, presenter: .table)
        )
        let callCount = Box(0)
        let grader: EditorGraderFactory = { _, _ in
            callCount.value += 1
            return outcome
        }
        let model = EditorModel(
            task: SampleTask.sql(database: nil, solution: "SELECT 1;"), graderFactory: grader
        )
        await model.run()
        #expect(callCount.value == 1)
        await model.submit()
        #expect(callCount.value == 2)
        #expect(model.activeTab == .output, "SQL 화면엔 탭이 없다 — 콘솔 탭 상태를 건드리지 않는다")
    }
}

@Suite("에디터 모델 · 상태 열거형")
struct EditorModelEnumTests {
    @Test("RunState.isBusy 는 준비·컴파일·실행 중일 때만 참이다")
    func runStateIsBusy() {
        #expect(!EditorModel.RunState.idle.isBusy)
        #expect(EditorModel.RunState.preparing.isBusy)
        #expect(EditorModel.RunState.compiling.isBusy)
        #expect(EditorModel.RunState.running.isBusy)
        #expect(!EditorModel.RunState.finished(succeeded: true, exitCode: 0, durationMilliseconds: 1).isBusy)
        #expect(!EditorModel.RunState.failed("x").isBusy)
    }

    @Test("GradeState.isBusy·result 파생")
    func gradeStateDerived() {
        #expect(!EditorModel.GradeState.notSubmitted.isBusy)
        #expect(EditorModel.GradeState.grading.isBusy)
        let result = GradeResult(passed: true, durationMilliseconds: 1, presenter: .console)
        #expect(EditorModel.GradeState.graded(result).result == result)
        #expect(EditorModel.GradeState.notSubmitted.result == nil)
    }
}
