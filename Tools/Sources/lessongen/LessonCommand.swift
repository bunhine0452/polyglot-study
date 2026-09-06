import ArgumentParser
import ContentKit
import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import OpenRouterKit

struct LessonCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lesson",
        abstract: "개요를 읽어 레슨 본문과 사이드카를 만들고 팩에 씁니다.",
        discussion: """
            모델은 레슨을 JSON 으로 내놓고, 디렉티브 마크다운은 이 도구가 조립합니다. \
            조립한 뒤 곧바로 레슨 파서에 태우고, 팩을 쓴 뒤에는 매니페스트 디코딩·sha256 \
            대조·참조 파일 존재까지 확인합니다 — packtool 의 구조·문법 단계와 같은 코드입니다.

            트랙 전체는 동시성을 제한한 병렬 요청으로 돕니다. Batch 엔드포인트는 현 모델에서 \
            프로모션가의 두 배이고 seed 를 받지 않아 쓰지 않습니다.
            """
    )

    @Option(name: [.customShort("o"), .long], help: "트랙 개요 JSON 경로.")
    var outline: String

    @Option(name: [.customShort("p"), .long], help: "팩 디렉터리. 없으면 만듭니다.")
    var pack: String

    @Option(name: .long, parsing: .upToNextOption, help: "이 stableID 만 생성합니다. 여러 번 줄 수 있습니다.")
    var only: [String] = []

    @Option(name: .long, help: "앞에서부터 이만큼만 생성합니다. 0 이면 전부.")
    var limit: Int = 0

    @Option(name: .long, help: "팩 id. 생략하면 기존 매니페스트, 없으면 디렉터리 이름.")
    var packID: String?

    @Option(name: .long, help: "팩 표시 이름. 생략하면 기존 매니페스트, 없으면 팩 id.")
    var displayName: String?

    @Option(name: .long, help: "팩 버전.")
    var packVersion: String = "0.1.0"

    @Option(name: .long, help: "이 팩이 요구하는 최소 앱 버전.")
    var minAppVersion: String = "0.1.0"

    @Option(
        name: .long,
        help: """
            매니페스트의 generatedAt (YYYY-MM-DDTHH:MM:SSZ). 생략하면 기존 값을 유지하고, \
            새 팩이면 현재 시각을 씁니다 — 스펙상 출처는 git commit date 이므로 CI 는 명시하십시오.
            """
    )
    var generatedAt: String?

    @Option(name: .long, help: "프롬프트에 덧붙일 추가 요구사항.")
    var notes: String?

    @OptionGroup var options: GenerationOptions

    func validate() throws {
        guard limit >= 0 else { throw ValidationError("--limit 은 0 이상이어야 합니다.") }
    }

    func run() async throws {
        let outlineURL = URL(fileURLWithPath: outline)
        let track: TrackOutline
        do {
            track = try OutlineFile.decode(try Data(contentsOf: outlineURL))
        } catch {
            throw CLIError("개요를 읽지 못했습니다: \(outlineURL.path) — \(error)")
        }
        let issues = OutlineValidator.validate(track)
        guard issues.isEmpty else {
            throw CLIError(
                "개요가 검증을 통과하지 못했습니다 (\(issues.count)건)\n"
                    + issues.map { "  - \($0)" }.joined(separator: "\n"))
        }
        guard let language = LessonLanguage(track.language) else {
            throw CLIError(
                "레슨 생성이 모르는 언어입니다: \(track.language.rawValue) "
                    + "(아는 것: \(LessonLanguage.allCases.map(\.rawValue).joined(separator: ", ")))")
        }

        let selected = select(from: track.lessons)
        guard !selected.isEmpty else { throw CLIError("생성할 레슨이 없습니다.") }

        let environment = try options.environment()
        let selection = try options.modelSelection(environment)
        let stage = LessonGenerator.stage
        let apiKey = try options.apiKey(environment)
        let provider = options.provider(apiKey: apiKey, model: selection.model(for: stage))

        let requests = selected.map { lesson in
            LessonGenerator.Request(
                outline: lesson,
                language: language,
                trackTitle: track.trackTitle,
                precedingTitles: track.lessons.filter { $0.ordinal < lesson.ordinal }.map(\.title),
                notes: notes,
                effort: options.effort,
                maxTokens: options.maxTokens,
                sampling: options.sampling,
                serializationRetries: options.serializationRetries)
        }

        if options.dryRun {
            print(try provider.redactedDump(of: LessonGenerator.makeRequest(for: requests[0])))
            FileHandle.standardError.write(
                Data("\n레슨 \(requests.count)편을 동시성 \(options.concurrency)로 보냅니다 (첫 요청만 출력).\n".utf8))
            return
        }

        let runLog = try options.runLog(command: "lesson", models: selection)
        options.logRunHeader(
            options.log, stage: stage, selection: selection, environment: environment,
            runDirectory: runLog.directory)

        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: runLog))
        let redactor = Redactor(apiKey: apiKey)
        let outcomes = await BoundedFanout.run(
            requests,
            limit: options.concurrency,
            shouldStop: { $0 is RunLogError }
        ) { _, request in
            try await generator.generate(request)
        }

        var generated: [GeneratedLesson] = []
        var failures: [String] = []
        for outcome in outcomes {
            switch outcome.result {
            case .success(let lesson):
                generated.append(lesson)
            case .failure(let error):
                failures.append(
                    "  \(requests[outcome.index].outline.stableID.rawValue) — "
                        + redactor.redact(String(describing: error)))
            }
        }

        // 실패는 **쓰기 전에** 보고한다. 쓰기가 던지면 이 목록이 영영 안 보이고,
        // 그러면 "왜 한 편이 없지" 를 로그를 뒤져 찾아야 한다.
        if !failures.isEmpty {
            let text = "레슨 \(failures.count)편 실패:\n" + failures.joined(separator: "\n") + "\n"
            FileHandle.standardError.write(Data(text.utf8))
        }

        if !generated.isEmpty {
            let writer = PackWriter(directory: URL(fileURLWithPath: pack, isDirectory: true))
            let header = try makeHeader(writer: writer)
            let written = try writer.write(lessons: generated, header: header)
            let documents = try writer.verify()
            FileHandle.standardError.write(
                Data(
                    """
                    레슨 \(generated.count)편을 \(pack) 에 썼습니다. \
                    팩 전체 \(documents.count)편이 구조·문법 검사를 통과했습니다.

                    """.utf8))
            if !written.droppedPrerequisites.isEmpty {
                let lines = written.droppedPrerequisites.map {
                    "  \($0.lesson.rawValue) → \($0.prerequisite.rawValue)"
                }
                FileHandle.standardError.write(
                    Data(
                        """
                        경고: 팩에 없는 레슨을 가리키는 선수 관계 \(written.droppedPrerequisites.count)건을 떼었습니다.
                        \(lines.joined(separator: "\n"))
                        빠진 레슨을 만든 뒤 그 뒤 레슨도 다시 생성해야 관계가 복원됩니다.

                        """.utf8))
            }
        }

        let manifest = try await runLog.finish()
        FileHandle.standardError.write(Data("\n\(manifest.summaryText)\n".utf8))

        guard failures.isEmpty else {
            throw CLIError(
                "레슨 \(failures.count)편을 만들지 못했습니다.\n" + failures.joined(separator: "\n"))
        }
    }

    private func select(from lessons: [LessonOutline]) -> [LessonOutline] {
        var chosen = lessons
        if !only.isEmpty {
            let wanted = Set(only)
            chosen = chosen.filter {
                wanted.contains($0.stableID.rawValue)
                    || wanted.contains(PackLessonID.fromOutline($0.stableID).rawValue)
            }
        }
        if limit > 0 { chosen = Array(chosen.prefix(limit)) }
        return chosen
    }

    /// 매니페스트 머리말. 기존 팩이 있으면 그 값이 이긴다 — 도구가 팩 신원을 바꾸면 안 된다.
    private func makeHeader(writer: PackWriter) throws -> PackWriter.Header {
        let existing = try writer.existingManifest()
        let directoryName = URL(fileURLWithPath: pack, isDirectory: true).lastPathComponent
        let id = packID ?? existing?.packID.rawValue ?? directoryName
        return PackWriter.Header(
            packID: PackID(id),
            displayName: displayName ?? existing?.displayName ?? id,
            version: existing?.version ?? packVersion,
            minAppVersion: existing?.minAppVersion ?? minAppVersion,
            generatedAt: generatedAt ?? existing?.generatedAt
                ?? CanonicalJSON.canonicalTimestamp(Date()))
    }
}
