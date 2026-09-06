import ContentKit
import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import PackReport
import Testing
import TestSupport

@Suite("수리 — 실패 종류마다 다른 지시")
struct RepairPromptTests {
    private func failure(_ kind: PackValidationReport.Failure.Kind, evidence: String? = nil)
        -> PackValidationReport.LessonResult
    {
        PackValidationReport.LessonResult(
            stableID: "python-fstring",
            language: "python",
            title: "f-string",
            failures: [
                PackValidationReport.Failure(
                    stage: .execution, kind: kind, blockID: "initials",
                    summary: "요약", evidence: evidence)
            ])
    }

    @Test("starter 가 이미 통과하면 '더 어렵게' 가 아니라 '정답을 걷어 내라' 다")
    func starterAlreadyPassesIsDifferent() {
        let instruction = RepairPrompt.instruction(for: .starterAlreadyPasses, language: .python)
        #expect(instruction.contains("걷어 내는"))
        #expect(instruction.contains("테스트와 solution 은 **한 글자도 건드리지 마라.**"))
        // "더 어렵게" 는 이 실패에 대한 **틀린** 대응이라 명시적으로 금지되어 있어야 한다.
        #expect(instruction.contains("과제를 어렵게 만들지 마라"))
        #expect(instruction.contains("NotImplementedError"))

        // 정답이 테스트를 통과하지 못한 경우와 지시가 정반대여야 한다.
        let opposite = RepairPrompt.instruction(for: .solutionFailsTests, language: .python)
        #expect(opposite.contains("solutionCode 를 고쳐"))
        #expect(opposite != instruction)
    }

    @Test("실패 여덟 종이 서로 다른 지시를 받는다")
    func everyKindHasItsOwnInstruction() {
        var seen: Set<String> = []
        for kind in PackValidationReport.Failure.Kind.allCases {
            let instruction = RepairPrompt.instruction(for: kind, language: .swift)
            #expect(!instruction.isEmpty)
            seen.insert(instruction)
        }
        // malformedDirective 와 blockStructure 만 같은 지시를 공유한다 (둘 다 문법 문제다).
        #expect(seen.count == PackValidationReport.Failure.Kind.allCases.count - 1)
    }

    @Test("러너 원문이 요약되지 않고 그대로 실린다")
    func evidenceIsVerbatim() {
        let evidence = """
            solution.py:3: error: 'int' object is not iterable
              File "<stdin>", line 3, in initials
            AssertionError: 'AL' != 'Al'
            """
        let text = RepairPrompt.user(
            lesson: failure(.solutionFailsTests, evidence: evidence),
            currentDraftJSON: "{}",
            language: .python)
        #expect(text.contains(evidence))
    }

    @Test("현재 초안이 프롬프트에 그대로 들어간다 — 고치기지 새로 쓰기가 아니다")
    func carriesCurrentDraft() {
        let text = RepairPrompt.user(
            lesson: failure(.exampleOutputMismatch),
            currentDraftJSON: "{\"concept\":{\"id\":\"a\"}}",
            language: .python)
        #expect(text.contains("\"concept\""))
    }

    @Test("언어마다 starter 골격 문구가 다르다")
    func starterStubPerLanguage() {
        #expect(
            RepairPrompt.instruction(for: .starterAlreadyPasses, language: .swift)
                .contains("fatalError"))
        #expect(
            RepairPrompt.instruction(for: .starterAlreadyPasses, language: .sql)
                .contains("골격 질의"))
    }

    @Test("수리 요청도 생성과 같은 시스템 접두사로 시작한다 — 캐시를 이어 쓴다")
    func sharesCachePrefix() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let read = LessonDraftReader.ReadLesson(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(),
            language: .python)
        let repair = RepairGenerator.makeRequest(
            for: RepairGenerator.Request(lesson: failure(.solutionFailsTests), current: read),
            currentDraftJSON: "{}")
        let generation = LessonGenerator.makeRequest(
            for: LessonGenerator.Request(
                outline: LessonFixtures.outline(), language: .python, trackTitle: "t"))

        #expect(repair.system.count == 2)
        #expect(repair.system[0] == generation.system[0])
        #expect(repair.system[1].text == RepairPrompt.systemSuffix)
    }
}

@Suite("수리 계획과 격리")
struct RepairPlannerTests {
    @Test("실패한 레슨만 대상이 된다")
    func onlyFailedLessons() {
        var report = LessonFixtures.report()
        report.lessons.append(
            PackValidationReport.LessonResult(
                stableID: "python-ok", language: "python", title: "통과", failures: []))
        let plan = RepairPlanner.plan(
            report: report, ledger: AttemptLedger(packID: report.packID))
        #expect(plan.targets.map(\.lesson.stableID) == ["python-fstring"])
        #expect(plan.quarantined.isEmpty)
    }

    @Test("3회를 다 쓴 레슨은 대상이 아니라 격리다 — 모델을 부르기 전에 정해진다")
    func quarantineAfterThree() {
        let report = LessonFixtures.report()
        var ledger = AttemptLedger(packID: report.packID)
        for _ in 1...3 { ledger.recordAttempt("python-fstring") }

        let plan = RepairPlanner.plan(report: report, ledger: ledger)
        #expect(plan.targets.isEmpty)
        #expect(plan.quarantined.map(\.stableID) == ["python-fstring"])
        #expect(plan.quarantined[0].attempts == 3)
        #expect(plan.quarantined[0].failures.first?.contains("starterAlreadyPasses") == true)
    }

    @Test("두 번째 시도까지는 계속 고친다")
    func keepsTryingUntilLimit() {
        let report = LessonFixtures.report()
        var ledger = AttemptLedger(packID: report.packID)
        ledger.recordAttempt("python-fstring")
        let plan = RepairPlanner.plan(report: report, ledger: ledger)
        #expect(plan.targets.map(\.attempt) == [2])
    }

    @Test("통과한 레슨은 장부에서 지워져 다음 실패가 처음부터 센다")
    func clearingResetsCount() {
        var ledger = AttemptLedger(packID: "p")
        ledger.recordAttempt("a")
        ledger.recordAttempt("a")
        ledger.clear("a")
        #expect(ledger.attempts(for: "a") == 0)
    }

    @Test("장부는 실행을 넘어 이어진다")
    func ledgerPersists() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(AttemptLedger.fileName)

        var ledger = AttemptLedger(packID: "polyglot-mvp")
        ledger.recordAttempt("python-fstring")
        try ledger.write(to: url)

        let reloaded = AttemptLedger.load(from: url, packID: "polyglot-mvp")
        #expect(reloaded.attempts(for: "python-fstring") == 1)

        // 팩이 다르면 장부를 물려받지 않는다.
        let other = AttemptLedger.load(from: url, packID: "other-pack")
        #expect(other.attempts(for: "python-fstring") == 0)
    }

    @Test("--only 는 대상을 좁힌다")
    func onlyNarrows() {
        var report = LessonFixtures.report()
        report.lessons.append(
            PackValidationReport.LessonResult(
                stableID: "python-other", language: "python", title: "다른 레슨",
                failures: [
                    PackValidationReport.Failure(
                        stage: .syntax, kind: .malformedDirective, summary: "문법")
                ]))
        let plan = RepairPlanner.plan(
            report: report, ledger: AttemptLedger(packID: report.packID),
            only: ["python-other"])
        #expect(plan.targets.map(\.lesson.stableID) == ["python-other"])
    }

    @Test("격리 명단이 사람이 읽는 문단으로 나온다")
    func quarantineReportText() {
        let text = RepairPlanner.quarantineReport(
            [
                RepairPlan.Quarantine(
                    stableID: "python-fstring", language: "python", title: "f-string",
                    attempts: 3, failures: ["[execution/starterAlreadyPasses] starter 통과"])
            ],
            maxAttempts: 3)
        #expect(text.contains("격리 1건"))
        #expect(text.contains("머지하지 마십시오"))
        #expect(text.contains("python-fstring"))
    }
}

@Suite("수리 왕복")
struct RepairGeneratorTests {
    /// 팩 하나를 만들고 그 안의 레슨을 되읽는다.
    private func makePack() throws -> (URL, ContentPack) {
        let directory = try LessonFixtures.temporaryDirectory()
        let writer = PackWriter(directory: directory)
        let lesson = try LessonAssembler.assemble(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(),
            language: .python,
            generatorModel: "m")
        _ = try writer.write(
            lessons: [lesson],
            header: PackWriter.Header(
                packID: PackID("polyglot-mvp"), displayName: "테스트",
                generatedAt: "2026-09-06T00:00:00Z"))
        return (directory, try ContentPack(directory: directory))
    }

    @Test("팩의 레슨을 초안으로 되읽으면 코드와 정답이 그대로다")
    func readsBackDraft() throws {
        let (directory, pack) = try makePack()
        defer { try? FileManager.default.removeItem(at: directory) }

        let read = try LessonDraftReader.read(LessonID("python-fstring"), from: pack)
        #expect(read.language == .python)
        #expect(read.draft.concept.id == "fstring-basics")
        #expect(read.draft.blank.answers.map(\.text) == ["sum", "total"])
        #expect(read.draft.task.testsCode.contains("import unittest"))
        #expect(read.draft.example.expectedStdout == "polyglot has 3 tracks\n")
        #expect(read.outline.title == "f-string 으로 문자열 만들기")
    }

    @Test("수리 한 번으로 고쳐진 레슨이 나오고 검증 가능한 팩으로 다시 쓰인다")
    func repairsAndRewrites() async throws {
        let (directory, pack) = try makePack()
        defer { try? FileManager.default.removeItem(at: directory) }
        let logRoot = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: logRoot) }

        var fixed = LessonFixtures.draft()
        fixed.task.starterCode = "def initials(full_name):\n    raise NotImplementedError"
        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [.success(LessonFixtures.response(text: LessonFixtures.draftJSON(fixed)))])
        let log = try LessonFixtures.runLog(directory: logRoot)
        let generator = RepairGenerator(client: MeteredClient(provider: provider, log: log))

        let read = try LessonDraftReader.read(LessonID("python-fstring"), from: pack)
        let repaired = try await generator.repair(
            RepairGenerator.Request(
                lesson: LessonFixtures.report().lessons[0], current: read))

        #expect(repaired.stableID == LessonID("python-fstring"))
        #expect(repaired.starterCode.contains("NotImplementedError"))

        let writer = PackWriter(directory: directory)
        _ = try writer.write(
            lessons: [repaired],
            header: PackWriter.Header(
                packID: pack.manifest.packID, displayName: pack.manifest.displayName,
                generatedAt: pack.manifest.generatedAt))
        try writer.verify()

        // 수리 단계로 기록되어야 한다 — 어느 단계가 어느 모델을 썼는지가 로그의 요점이다.
        let jsonl = try String(
            contentsOf: log.directory.appendingPathComponent("calls.jsonl"), encoding: .utf8)
        #expect(jsonl.contains("\"stage\":\"repair\""))
    }
}
