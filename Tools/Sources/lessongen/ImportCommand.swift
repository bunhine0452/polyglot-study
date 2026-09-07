import ArgumentParser
import ContentKit
import Foundation
import LearnCore
import LessonGenKit

/// 사람이(또는 다른 에이전트가) 쓴 레슨 드래프트를 팩에 들인다. **API 를 부르지 않는다.**
///
/// `lesson` 과 유일하게 다른 것은 `LessonContentDraft` 를 **어디서 얻는가** 뿐이다 —
/// 저쪽은 OpenRouter 에 물어보고 이쪽은 파일에서 읽는다. 그 뒤의 직렬화·검사·팩 쓰기는
/// 같은 코드를 지나므로, 손으로 쓴 레슨도 모델이 쓴 레슨과 **같은 보장**을 받는다:
/// 디렉티브 문법은 `LessonSerializer` 가 만들고, 구운 결과는 곧바로 `LessonParser` 에
/// 태워지며, 팩을 쓴 뒤에는 매니페스트 디코딩과 sha256 대조까지 확인한다.
///
/// 이것을 붙인 이유는 둘이다.
///
/// 1. **품질.** 값싼 모델은 레슨 하나를 $0.005 에 쓰지만 사람 손이 필요한 것을 자주
///    남긴다. 좋은 모델에게 직접 쓰게 하면 그 왕복이 준다.
/// 2. **상류가 리터럴을 지우는 문제.** 2026-09-07 에 구조화 출력에서 소문자 `json` 이
///    통째로 사라지는 것을 확인했다(HANDOFF "OpenRouter"). 재시도로 수렴하지 않아
///    `python-csv-and-json-processing` 을 손으로 다시 써야 했다. 그 경로가 이제 도구로
///    있다.
///
/// 입력은 드래프트 JSON 파일들이다. 스키마는 모델이 내놓는 것과 **같다**
/// (`LessonContentDraft`) — 개요의 순번·제목·학습목표는 outline 에서 읽으므로 드래프트에
/// 다시 적지 않는다.
struct ImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "손으로 쓴 레슨 드래프트를 팩에 들입니다. API 를 부르지 않습니다.",
        discussion: """
            드래프트 JSON 의 스키마는 `lessongen lesson` 이 모델에게 요구하는 것과 같습니다 \
            (concept·example·blank·task·quiz·reflection 여섯 블록). 파일 이름은 \
            `<stableID>.json` 이어야 합니다 — 개요의 어느 레슨인지 그 이름으로 잇습니다.

            예: tracks/rust.outline.json 의 `rust.ownership-basics` 에 대응하는 파일은 \
            `rust.ownership-basics.json` 입니다.

            생성물은 사람이 리뷰한 뒤에 커밋합니다 — 이 도구는 파일을 쓰는 데서 멈춥니다.
            """
    )

    @Option(name: [.customShort("o"), .long], help: "트랙 개요 JSON 경로.")
    var outline: String

    @Option(name: [.customShort("p"), .long], help: "팩 디렉터리. 없으면 만듭니다.")
    var pack: String

    @Option(
        name: [.customShort("d"), .long],
        help: "드래프트 JSON 이 든 디렉터리. `<stableID>.json` 들을 읽습니다.")
    var drafts: String

    @Option(help: "팩 id. 생략하면 기존 매니페스트, 없으면 디렉터리 이름.")
    var packID: String?

    @Option(help: "팩 표시 이름. 생략하면 기존 매니페스트, 없으면 팩 id.")
    var displayName: String?

    @Option(help: "팩 버전.")
    var packVersion: String = "0.1.0"

    @Option(help: "이 팩이 요구하는 최소 앱 버전.")
    var minAppVersion: String = "0.1.0"

    @Option(
        help: """
            매니페스트의 generatedAt (YYYY-MM-DDTHH:MM:SSZ). 생략하면 기존 값을 유지하고, \
            새 팩이면 현재 시각을 씁니다.
            """)
    var generatedAt: String?

    @Option(
        help: """
            레슨을 쓴 주체. 매니페스트가 아니라 실행 기록용 문자열입니다 — 나중에 \
            "이 레슨은 무엇이 썼나" 를 묻게 됩니다.
            """)
    var author: String = "hand-written"

    @Flag(help: "드래프트를 읽고 검사만 합니다. 팩에 쓰지 않습니다.")
    var dryRun = false

    func run() async throws {
        let outlineFile = try OutlineFile.decode(try Data(contentsOf: URL(fileURLWithPath: outline)))
        let draftRoot = URL(fileURLWithPath: drafts, isDirectory: true)

        var generated: [GeneratedLesson] = []
        var failures: [String] = []
        var missing: [String] = []

        for entry in outlineFile.lessons.sorted(by: { $0.ordinal < $1.ordinal }) {
            let file = draftRoot.appendingPathComponent("\(entry.stableID.rawValue).json")
            guard FileManager.default.fileExists(atPath: file.path) else {
                missing.append(entry.stableID.rawValue)
                continue
            }
            do {
                generated.append(try makeLesson(entry: entry, file: file, outline: outlineFile))
            } catch {
                failures.append("  \(entry.stableID.rawValue): \(error)")
            }
        }

        if !missing.isEmpty {
            FileHandle.standardError.write(
                Data(
                    """
                    드래프트가 없어 건너뛴 레슨 \(missing.count)편:
                    \(missing.map { "  \($0)" }.joined(separator: "\n"))

                    """.utf8))
        }
        // 실패는 **쓰기 전에** 보고한다 — `LessonCommand` 와 같은 이유다.
        if !failures.isEmpty {
            FileHandle.standardError.write(
                Data(("드래프트 \(failures.count)편이 검사를 통과하지 못했습니다:\n"
                    + failures.joined(separator: "\n") + "\n").utf8))
        }

        guard !dryRun else {
            FileHandle.standardError.write(
                Data("검사만 했습니다 — 통과 \(generated.count)편, 실패 \(failures.count)편.\n".utf8))
            guard failures.isEmpty else { throw CLIError("드래프트 검사 실패") }
            return
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

                        """.utf8))
            }
        }

        guard failures.isEmpty else {
            throw CLIError("레슨 \(failures.count)편을 들이지 못했습니다.")
        }
    }

    /// 드래프트 하나를 레슨으로. 직렬화와 검사는 전부 `LessonGenKit` 이 한다.
    private func makeLesson(
        entry: LessonOutline, file: URL, outline: TrackOutline
    ) throws -> GeneratedLesson {
        guard let language = LessonLanguage(outline.language) else {
            throw CLIError("개요의 언어를 모릅니다: \(outline.language.rawValue)")
        }
        let decoder = JSONDecoder()
        let draft = try decoder.decode(LessonContentDraft.self, from: try Data(contentsOf: file))
        let stableID = PackLessonID.fromOutline(entry.stableID)
        let paths = try LessonPaths(stableID: stableID, language: language)
        // 여기가 요점이다 — 모델이 쓴 레슨과 **같은** 직렬화·검사를 지난다.
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: stableID, language: language, paths: paths)

        return GeneratedLesson(
            stableID: stableID,
            language: language,
            title: entry.title,
            order: entry.ordinal,
            objectives: entry.objectives,
            prerequisites: entry.prerequisites.map(PackLessonID.fromOutline),
            paths: paths,
            markdown: markdown,
            expectedStdout: draft.example.expectedStdout,
            starterCode: draft.task.starterCode,
            testsCode: draft.task.testsCode,
            solutionCode: draft.task.solutionCode,
            generatorModel: author
        )
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
                ?? CanonicalJSON.canonicalTimestamp(Date())
        )
    }
}
