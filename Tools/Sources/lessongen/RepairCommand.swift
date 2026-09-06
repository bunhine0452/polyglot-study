import ArgumentParser
import ContentKit
import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import OpenRouterKit
import PackReport

struct RepairCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repair",
        abstract: "packtool 리포트를 읽어 실패한 레슨만 다시 만듭니다.",
        discussion: """
            실패 종류마다 다른 지시를 보냅니다 — 특히 starter 가 이미 통과하는 과제는 \
            "더 어렵게" 가 아니라 "starter 에서 정답을 걷어 내라" 입니다. 러너가 뱉은 원문은 \
            요약하지 않고 그대로 프롬프트에 싣습니다.

            \(RepairPlanner.defaultMaxAttempts)회 수리하고도 통과하지 못한 레슨은 팩에서 빼고 \
            명단과 함께 non-zero 로 끝냅니다. 시도 횟수는 실행을 넘어 이어지며 \
            <runs>/\(AttemptLedger.fileName) 에 남습니다.
            """
    )

    @Option(name: [.customShort("r"), .long], help: "packtool validate 가 낸 JSON 리포트 경로.")
    var report: String

    @Option(name: [.customShort("p"), .long], help: "고칠 팩 디렉터리.")
    var pack: String

    @Option(name: .long, help: "격리하기까지 허용할 수리 횟수.")
    var maxAttempts: Int = RepairPlanner.defaultMaxAttempts

    @Option(name: .long, parsing: .upToNextOption, help: "이 stableID 만 고칩니다.")
    var only: [String] = []

    @Flag(name: .long, help: "고치지 않고 계획만 출력합니다.")
    var planOnly = false

    @OptionGroup var options: GenerationOptions

    func validate() throws {
        guard maxAttempts >= 1 else { throw ValidationError("--max-attempts 는 1 이상이어야 합니다.") }
    }

    func run() async throws {
        let reportURL = URL(fileURLWithPath: report)
        let reportData: Data
        let validation: PackValidationReport
        do {
            reportData = try Data(contentsOf: reportURL)
            validation = try PackValidationReport.decode(reportData)
        } catch {
            throw CLIError("검증 리포트를 읽지 못했습니다: \(reportURL.path) — \(error)")
        }

        let packURL = URL(fileURLWithPath: pack, isDirectory: true)
        let contentPack: ContentPack
        do {
            contentPack = try ContentPack(directory: packURL)
        } catch {
            throw CLIError("팩을 열지 못했습니다: \(packURL.path) — \(error)")
        }

        let ledgerURL = URL(fileURLWithPath: options.runsDirectory, isDirectory: true)
            .appendingPathComponent(AttemptLedger.fileName)
        var ledger = AttemptLedger.load(from: ledgerURL, packID: validation.packID)
        // 이번에 통과한 레슨은 장부에서 지운다 — 다음에 다시 실패하면 처음부터 세야 한다.
        let failing = Set(validation.failedLessons.map(\.stableID))
        for lesson in validation.lessons where !failing.contains(lesson.stableID) {
            ledger.clear(lesson.stableID)
        }

        let plan = RepairPlanner.plan(
            report: validation, ledger: ledger, maxAttempts: maxAttempts, only: Set(only))

        if !validation.executionStageRan {
            FileHandle.standardError.write(
                Data("경고: 이 리포트에는 실행 게이트가 돌지 않았습니다 — 통과를 통과로 읽지 마십시오.\n".utf8))
        }

        guard !plan.isEmpty else {
            FileHandle.standardError.write(Data("고칠 레슨이 없습니다. 리포트가 깨끗합니다.\n".utf8))
            try ledger.write(to: ledgerURL)
            return
        }

        if planOnly {
            for target in plan.targets {
                print(
                    "수리 \(target.attempt)/\(maxAttempts) — \(target.lesson.stableID): "
                        + target.lesson.failures.map { $0.kind.rawValue }.joined(separator: ", "))
            }
            if !plan.quarantined.isEmpty {
                print(RepairPlanner.quarantineReport(plan.quarantined, maxAttempts: maxAttempts))
            }
            return
        }

        // 격리는 모델을 부르기 전에 확정된다 — 시도를 다 쓴 레슨에 돈을 더 쓰지 않는다.
        var quarantined = plan.quarantined
        var repaired: [GeneratedLesson] = []
        var failures: [String] = []

        if !plan.targets.isEmpty {
            let environment = try options.environment()
            let selection = try options.modelSelection(environment)
            let stage = RepairGenerator.stage
            let apiKey = try options.apiKey(environment)
            let provider = options.provider(apiKey: apiKey, model: selection.model(for: stage))

            var requests: [RepairGenerator.Request] = []
            for target in plan.targets {
                let current = try LessonDraftReader.read(
                    LessonID(target.lesson.stableID), from: contentPack)
                requests.append(
                    RepairGenerator.Request(
                        lesson: target.lesson,
                        current: current,
                        effort: options.effort,
                        maxTokens: options.maxTokens,
                        sampling: options.sampling,
                        serializationRetries: options.serializationRetries))
            }

            if options.dryRun {
                let json = try LessonDraftReader.json(requests[0].current.draft)
                print(
                    try provider.redactedDump(
                        of: RepairGenerator.makeRequest(for: requests[0], currentDraftJSON: json)))
                return
            }

            let runLog = try options.runLog(command: "repair", models: selection)
            try await runLog.attach(reportData, named: "report.json")
            options.logRunHeader(
                options.log, stage: stage, selection: selection, environment: environment,
                runDirectory: runLog.directory)

            let generator = RepairGenerator(client: MeteredClient(provider: provider, log: runLog))
            let redactor = Redactor(apiKey: apiKey)
            let outcomes = await BoundedFanout.run(
                requests,
                limit: options.concurrency,
                shouldStop: { $0 is RunLogError }
            ) { _, request in
                try await generator.repair(request)
            }

            for outcome in outcomes {
                let target = plan.targets[outcome.index]
                ledger.recordAttempt(target.lesson.stableID)
                switch outcome.result {
                case .success(let lesson):
                    repaired.append(lesson)
                case .failure(let error):
                    let detail = redactor.redact(String(describing: error))
                    failures.append("  \(target.lesson.stableID) — \(detail)")
                    // 생성 자체가 실패한 것도 시도를 쓴 것이다. 상한에 닿았으면 지금 격리한다.
                    if ledger.attempts(for: target.lesson.stableID) >= maxAttempts {
                        quarantined.append(
                            RepairPlan.Quarantine(
                                stableID: target.lesson.stableID,
                                language: target.lesson.language,
                                title: target.lesson.title,
                                attempts: ledger.attempts(for: target.lesson.stableID),
                                failures: [detail]))
                    }
                }
            }

            let manifest = try await runLog.finish()
            if !quarantined.isEmpty {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
                try await runLog.attach(try encoder.encode(quarantined), named: "quarantined.json")
            }
            FileHandle.standardError.write(Data("\n\(manifest.summaryText)\n".utf8))
        }

        let writer = PackWriter(directory: packURL)
        let quarantinedIDs = Set(quarantined.map { LessonID($0.stableID) })
        if !repaired.isEmpty || !quarantinedIDs.isEmpty {
            let existing = contentPack.manifest
            let written = try writer.write(
                lessons: repaired,
                removing: quarantinedIDs,
                header: PackWriter.Header(
                    packID: existing.packID,
                    displayName: existing.displayName,
                    version: existing.version,
                    minAppVersion: existing.minAppVersion,
                    generatedAt: existing.generatedAt))
            let documents = try writer.verify()
            // 격리는 뒤 레슨의 선수 관계를 매달리게 만든다. 떼어 냈다는 사실을 숨기지 않는다.
            if !written.droppedPrerequisites.isEmpty {
                let lines = written.droppedPrerequisites.map {
                    "  \($0.lesson.rawValue) → \($0.prerequisite.rawValue)"
                }
                FileHandle.standardError.write(
                    Data(
                        ("격리된 레슨을 가리키던 선수 관계 \(lines.count)건을 떼었습니다.\n"
                            + lines.joined(separator: "\n") + "\n").utf8))
            }
            FileHandle.standardError.write(
                Data(
                    "레슨 \(repaired.count)편을 고쳤습니다. 팩 전체 \(documents.count)편이 구조·문법 검사를 통과했습니다.\n"
                        .utf8))
        }
        try ledger.write(to: ledgerURL)

        if !quarantined.isEmpty {
            let text = "\n" + RepairPlanner.quarantineReport(quarantined, maxAttempts: maxAttempts)
            FileHandle.standardError.write(Data((text + "\n").utf8))
            throw ExitCode(3)
        }
        guard failures.isEmpty else {
            throw CLIError("수리 \(failures.count)건이 실패했습니다.\n" + failures.joined(separator: "\n"))
        }
    }
}
