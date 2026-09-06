internal import ArgumentParser

/// 콘텐츠 팩 검증·빌드·서명 CLI.
///
/// 파이프라인의 순서가 곧 서브커맨드의 순서다 —
/// `validate`(실행 게이트까지) → `build`(solutions 를 벗겨 tar) → `sign` → `verify`.
/// 굽고 나면 solutions 가 없어 실행 게이트를 돌릴 수 없으므로 이 순서는 뒤집을 수 없다.
@main
struct Packtool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "packtool",
        abstract: "콘텐츠 팩 검증·빌드·서명",
        version: "1.0.0",
        subcommands: [
            ValidateCommand.self,
            BuildCommand.self,
            SignCommand.self,
            VerifyCommand.self,
            KeygenCommand.self,
        ]
    )
}
