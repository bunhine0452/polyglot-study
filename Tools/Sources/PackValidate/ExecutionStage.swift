internal import ContentKit
internal import Foundation
internal import LanguageKit
internal import LearnCore
internal import PackReport
internal import RunnerKit

/// 실행 단계 — 예제·빈칸·과제를 **실제 `CodeRunner`** 에 태운다.
///
/// 툴체인이 필요한 유일한 단계다. 그래서 규약이 하나 있다 —
/// **툴체인이 없으면 스킵이 아니라 실패가 기본이다.** `--allow-missing-toolchain` 을
/// 명시할 때만 건너뛰고, 건너뛰었으면 `stagesRun` 에서 `.execution` 을 뺀다.
/// "실행 게이트가 돌지 않은 clean" 을 CI 가 통과로 읽으면 이 게이트는 없는 것과 같다.
struct ExecutionStage: Sendable {
    /// 언어 하나가 지금 이 머신에서 실행 가능한지 묻는다.
    ///
    /// 주입 가능한 이유는 하나다 — **"툴체인이 없으면 스킵이 아니라 실패"** 는 이 게이트의
    /// 핵심 규약인데, 실제 머신에 툴체인이 있으면 그 분기가 테스트에서 영영 안 돈다.
    typealias ReadinessProbe = @Sendable (LanguageID, URL?) async -> LanguageReadiness

    let pack: ContentPack
    let options: ValidationOptions
    let probe: ReadinessProbe

    init(
        pack: ContentPack,
        options: ValidationOptions,
        probe: @escaping ReadinessProbe = ExecutionStage.readiness
    ) {
        self.pack = pack
        self.options = options
        self.probe = probe
    }

    struct Result: Sendable {
        var failures: [(lesson: String, failure: PackValidationReport.Failure)] = []
        var packLevelFailures: [PackValidationReport.Failure] = []
        /// 모든 블록을 실제로 태웠는가. 하나라도 건너뛰었으면 false —
        /// 리포트의 `stagesRun` 에서 `.execution` 이 빠진다.
        var ranEverything = true
        /// 사람에게 보여줄 스킵 사유.
        var skipNotes: [String] = []
    }

    // MARK: - 단위

    struct Unit: Sendable {
        var lessonID: String
        var language: LanguageID
        var block: Kind

        enum Kind: Sendable {
            case example(ExampleBlock)
            case blank(BlankBlock)
            case task(TaskBlock)
        }

        var blockID: String {
            switch block {
            case .example(let b): b.id
            case .blank(let b): b.id
            case .task(let b): b.id
            }
        }
    }

    static func units(of lessons: [ParsedLesson]) -> [Unit] {
        var units: [Unit] = []
        for lesson in lessons {
            let id = lesson.entry.stableID.rawValue
            for block in lesson.document.blocks {
                switch block {
                case .example(let example):
                    units.append(.init(lessonID: id, language: example.language, block: .example(example)))
                case .blank(let blank):
                    units.append(.init(lessonID: id, language: blank.language, block: .blank(blank)))
                case .task(let task):
                    units.append(.init(lessonID: id, language: task.language, block: .task(task)))
                case .concept, .quiz, .reflection:
                    continue
                }
            }
        }
        return units
    }

    // MARK: - 실행

    func run(_ lessons: [ParsedLesson]) async -> Result {
        var result = Result()
        let all = Self.units(of: lessons)
        guard !all.isEmpty else { return result }

        // `swiftc` 를 직접 띄우기 전에 SDKROOT 을 채운다 — 없으면 멀쩡한 Swift 레슨이
        // 전부 "컴파일 실패"로 뒤집힌다. 자세한 경위는 ``ToolchainEnvironment``.
        if all.contains(where: { $0.language == .swift }) {
            await ToolchainEnvironment.ensureSDKRoot()
        }

        let launcher = LauncherDiscovery.locate()
        var readiness: [String: LanguageReadiness] = [:]
        for language in Set(all.map(\.language.rawValue)).sorted() {
            readiness[language] = await probe(LanguageID(language), launcher)
        }

        // SQL 시드. 실패는 팩 전체의 결함이다 — 학습자 코드가 아니라 콘텐츠가 잘못됐다.
        var seed: URL?
        let workspace = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("packtool-seed-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        var sqlBlocked = false
        if all.contains(where: { $0.language == .sql }) {
            do {
                seed = try PackSQLSeed.materialize(pack: pack, into: workspace)
            } catch {
                sqlBlocked = true
                // 시드가 없으면 SQL 블록은 태워 보지도 못한다. 실패를 남기는 것과 별개로
                // "실행 게이트가 팩 전체를 태웠다"고 말하면 안 된다.
                result.ranEverything = false
                result.packLevelFailures.append(
                    .init(
                        stage: .execution, kind: .exampleFailedToRun,
                        summary: "SQL 시드 데이터베이스를 만들 수 없다", evidence: "\(error)"))
            }
        }

        var runnable: [Unit] = []
        for unit in all {
            if unit.language == .sql, sqlBlocked { continue }
            switch readiness[unit.language.rawValue] ?? .ready {
            case .ready:
                runnable.append(unit)
            case .unavailable(let reason):
                if options.allowMissingToolchain {
                    result.ranEverything = false
                    let note = "\(unit.language.rawValue): \(reason)"
                    if !result.skipNotes.contains(note) { result.skipNotes.append(note) }
                } else {
                    result.failures.append(
                        (unit.lessonID, Self.toolchainFailure(unit, reason: reason)))
                }
            }
        }
        guard !runnable.isEmpty else { return result }

        let grader = SwiftTestingGrader(
            configuration: .init(
                templateDirectory: options.swiftTemplateDirectory
                    ?? SwiftTemplateLocation.directory(for: pack.directory)))
        // Swift 과제가 있으면 템플릿을 미리 굽는다. 실패해도 여기서 보고하지 않는다 —
        // 진짜 원인은 첫 채점의 증거에 그대로 실려 나온다.
        if runnable.contains(where: { $0.language == .swift && Self.isTask($0) }) {
            _ = try? await grader.warmUp()
        }

        let gate = BlockGate(
            pack: pack,
            limits: options.limits,
            launcherPath: launcher?.path,
            seedDatabase: seed,
            swiftGrader: grader)

        let produced = await Self.execute(
            runnable, gate: gate, maxConcurrency: options.maxConcurrency)
        result.failures += produced
        return result
    }

    /// 동시성 상한을 지키며 태운다. 결과는 **입력 순서로** 정렬해 돌려준다 —
    /// 리포트가 실행 순서에 따라 흔들리면 CI 의 diff 비교가 무의미해진다.
    private static func execute(
        _ units: [Unit], gate: BlockGate, maxConcurrency: Int
    ) async -> [(lesson: String, failure: PackValidationReport.Failure)] {
        var collected: [(Int, String, [PackValidationReport.Failure])] = []
        await withTaskGroup(of: (Int, String, [PackValidationReport.Failure]).self) { group in
            var next = 0
            let limit = max(1, maxConcurrency)
            func schedule() {
                guard next < units.count else { return }
                let index = next
                let unit = units[index]
                next += 1
                group.addTask {
                    let failures: [PackValidationReport.Failure]
                    switch unit.block {
                    case .example(let block): failures = await gate.example(block)
                    case .blank(let block): failures = await gate.blank(block)
                    case .task(let block): failures = await gate.task(block)
                    }
                    return (index, unit.lessonID, failures)
                }
            }
            for _ in 0..<min(limit, units.count) { schedule() }
            while let finished = await group.next() {
                collected.append(finished)
                schedule()
            }
        }
        return
            collected
            .sorted { $0.0 < $1.0 }
            .flatMap { _, lesson, failures in failures.map { (lesson, $0) } }
    }

    private static func isTask(_ unit: Unit) -> Bool {
        if case .task = unit.block { return true }
        return false
    }

    // MARK: - 툴체인

    enum LanguageReadiness: Sendable {
        case ready
        case unavailable(String)
    }

    static func readiness(for language: LanguageID, launcher: URL?) async -> LanguageReadiness {
        switch language {
        case .sql:
            // 인프로세스 러너다. 외부 바이너리가 하나도 필요 없다 — `sqlite3` CLI 조차.
            return .ready
        case .python, .swift:
            guard launcher != nil else { return .unavailable(LauncherDiscovery.hint) }
            let spec = language == .python ? ToolchainCatalog.python : ToolchainCatalog.swift
            switch await LanguageToolchain.shared.availability(for: spec) {
            case .ready:
                return .ready
            case .missing(let hint):
                return .unavailable("\(spec.displayName) 툴체인이 없다 — \(hint)")
            case .stub(let path, let reason):
                return .unavailable("\(path) 는 동작하지 않는다 — \(reason)")
            case .unsupported(let path, let version, let minimum):
                return .unavailable("\(path) 는 \(version) 이라 최소 \(minimum) 에 못 미친다")
            }
        default:
            return .unavailable("실행 게이트가 아는 언어는 python·sql·swift 뿐이다")
        }
    }

    static func toolchainFailure(
        _ unit: Unit, reason: String
    ) -> PackValidationReport.Failure {
        let kind: PackValidationReport.Failure.Kind = isTask(unit) ? .solutionFailsTests : .exampleFailedToRun
        return PackValidationReport.Failure(
            stage: .execution,
            kind: kind,
            blockID: unit.blockID,
            summary: "실행 게이트를 태울 수 없다 (\(unit.language.rawValue))",
            // 스킵이 아니라 실패다. `--allow-missing-toolchain` 을 명시해야만 건너뛴다.
            evidence: reason + "\n\n툴체인 없이 통과시키려면 --allow-missing-toolchain 을 명시해라."
                + " 그 경우 리포트의 stagesRun 에서 execution 이 빠진다.")
    }
}
