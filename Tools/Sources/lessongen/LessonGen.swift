import ArgumentParser
import Foundation

@main
struct LessonGen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lessongen",
        abstract: "OpenRouter 로 학습 콘텐츠를 생성하는 빌드타임 CLI.",
        discussion: """
            API 키는 OPENROUTER_API_KEY 환경변수(또는 .env)에서만 읽습니다. 플래그나 \
            설정파일로는 받지 않으며 로그에도 싣지 않습니다. 우선순위는 환경변수 > .env \
            입니다.

            모델은 OPENROUTER_MODEL 에서 읽고, 단계별로 OPENROUTER_MODEL_OUTLINE / \
            _LESSON / _PROSE / _REPAIR 로 덮을 수 있습니다. 모델 문자열은 비밀이 아니라 \
            재현에 필요한 기록이므로 로그에 남습니다.

            생성물은 사람이 리뷰한 뒤에 커밋합니다 — 이 도구는 파일을 쓰는 데서 멈춥니다.
            """,
        version: "0.3.0",
        subcommands: [OutlineCommand.self, LessonCommand.self, RepairCommand.self]
    )
}
