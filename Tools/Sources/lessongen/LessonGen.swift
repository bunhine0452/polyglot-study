import ArgumentParser
import Foundation

@main
struct LessonGen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lessongen",
        abstract: "Claude API 로 학습 콘텐츠를 생성하는 빌드타임 CLI.",
        discussion: """
            API 키는 ANTHROPIC_API_KEY 환경변수에서만 읽습니다. 플래그나 설정파일로는 \
            받지 않으며 로그에도 싣지 않습니다.

            생성물은 사람이 리뷰한 뒤에 커밋합니다 — 이 도구는 파일을 쓰는 데서 멈춥니다.
            """,
        version: "0.1.0",
        subcommands: [OutlineCommand.self]
    )
}
