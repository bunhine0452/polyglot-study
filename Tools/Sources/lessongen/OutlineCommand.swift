// `Effort` 에 ArgumentParser 적합성을 얹으므로 두 모듈 다 공개 임포트여야 한다.
// (실행 파일 타깃이라 밖으로 새는 표면은 없다.)
public import AnthropicKit
public import ArgumentParser
import Foundation
import LearnCore
import LessonGenKit

/// `--effort low|medium|high|xhigh|max` 를 그대로 받게 한다. `CaseIterable` 덕에
/// `--help` 가 유효한 값을 나열해 준다.
extension Effort: ExpressibleByArgument {}

struct OutlineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outline",
        abstract: "트랙 개요를 구조화 출력 1회로 뽑아 tracks/<lang>.outline.json 으로 씁니다.",
        discussion: """
            결과는 커밋되지 않습니다. 사람이 읽고 고친 뒤에 직접 커밋하십시오.
            """
    )

    @Option(name: [.customShort("l"), .long], help: "트랙 언어 ID. 소문자 kebab. 예: python, sql, swift")
    var language: String

    @Option(name: .long, help: "레슨 수.")
    var lessons: Int = 24

    @Option(name: [.customShort("o"), .customLong("output")], help: "개요 파일을 놓을 디렉터리.")
    var outputDirectory: String = "tracks"

    @Option(name: .long, help: "모델 ID.")
    var model: String = AnthropicModel.opus5.rawValue

    @Option(name: .long, help: "사고 노력 수준 (low/medium/high/xhigh/max).")
    var effort: Effort = .high

    @Option(name: .long, help: "응답 최대 토큰.")
    var maxTokens: Int = 16000

    @Option(name: .long, help: "프롬프트에 덧붙일 추가 요구사항.")
    var notes: String?

    @Flag(name: .long, help: "호출하지 않고 보낼 요청만 출력합니다. API 키가 없어도 됩니다.")
    var dryRun = false

    @Flag(name: [.customShort("v"), .long], help: "진행 로그를 stderr 로 출력합니다.")
    var verbose = false

    func validate() throws {
        guard OutlineValidator.isKebabIdentifier(language) else {
            throw ValidationError("--language 는 소문자 kebab 이어야 합니다: \(language)")
        }
        guard lessons > 0 else { throw ValidationError("--lessons 는 1 이상이어야 합니다.") }
        guard maxTokens > 0 else { throw ValidationError("--max-tokens 는 1 이상이어야 합니다.") }
    }

    func run() async throws {
        let languageID = LanguageID(language)
        let generatorRequest = OutlineGenerator.Request(
            language: languageID,
            lessonCount: lessons,
            notes: notes,
            model: AnthropicModel(model),
            effort: effort,
            maxTokens: maxTokens
        )

        // 키를 못 읽으면 네트워크를 건드리기 전에 여기서 끝난다.
        let apiKey: APIKey
        do {
            apiKey = try APIKey.fromEnvironment()
        } catch {
            if dryRun {
                // --dry-run 은 키가 없어도 돌아야 한다. 요청 모양만 보여 주는 것이므로
                // 실제로는 쓰이지 않는 자리표시자를 넣는다.
                apiKey = try APIKey(rawValue: "sk-ant-DRY-RUN-PLACEHOLDER")
            } else {
                throw CLIError(String(describing: error))
            }
        }

        let client = AnthropicClient(
            apiKey: apiKey,
            log: verbose ? StandardErrorLog() : DiscardLog()
        )
        let messagesRequest = OutlineGenerator.makeRequest(for: generatorRequest)

        if dryRun {
            // 반드시 redactedDump 를 거친다. URLRequest 를 그대로 찍으면 헤더가 나온다.
            let urlRequest = try client.makeURLRequest(for: messagesRequest)
            print(RequestBuilder.redactedDump(of: urlRequest))
            return
        }

        let generator = OutlineGenerator(client: client)
        let outline: TrackOutline
        do {
            outline = try await generator.generate(generatorRequest)
        } catch {
            // 어떤 오류든 키가 실릴 수 있는 경로를 한 번 더 막는다.
            throw CLIError(Redactor(apiKey: apiKey).redact(String(describing: error)))
        }

        let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        let written = try OutlineFile.write(outline, toDirectory: directory)

        FileHandle.standardError.write(
            Data(
                """
                개요 \(outline.lessons.count)개 레슨을 썼습니다: \(written.path)
                커밋하기 전에 사람이 읽고 확인하십시오 — 이 도구는 커밋하지 않습니다.

                """.utf8
            )
        )
    }
}

/// 스택 트레이스 없이 메시지만 보여 주는 종료.
///
/// `LocalizedError` 와 `CustomStringConvertible` 을 둘 다 채택한다 — ArgumentParser 가
/// 어느 쪽을 읽든 같은 문장이 나오게.
struct CLIError: LocalizedError, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
    var errorDescription: String? { description }
}
