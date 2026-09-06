internal import ArgumentParser

/// 콘텐츠 팩 검증·빌드·서명 CLI.
///
/// `validate` 만 구현돼 있다. `build`(solutions 를 벗긴 배포 팩)와 `sign`(정규 매니페스트
/// 바이트에 대한 분리 서명)은 플래너의 `{#packtool-build}` `{#packtool-sign}` 이고
/// 다른 작업이다.
@main
struct Packtool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "packtool",
        abstract: "콘텐츠 팩 검증·빌드·서명",
        version: "1.0.0",
        subcommands: [ValidateCommand.self]
    )
}
