internal import ArgumentParser
internal import ContentKit
internal import Foundation
internal import LearnCore
internal import PackBuild
internal import PackReport
internal import PackValidate

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "배포용 팩을 결정적으로 굽는다 — solutions 를 벗기고 tar 로",
        discussion: """
            소스 팩에서 `solutions/` 를 벗기고, 해시를 다시 세고, tar 하나로 굽는다.

            **두 번 구우면 바이트가 같다.** tar 헤더의 mtime 은 매니페스트의
            generatedAt 에서 오고 uid·gid·uname·gname 은 비어 있다 — 굽는 머신과
            굽는 사람이 결과에 남지 않는다. gzip 을 걸지 않는 것도 같은 이유다
            (gzip 헤더에 압축 시각이 들어간다).

            굽기 전에 구조·문법·의미 세 단계를 돌리고, 하나라도 실패하면 굽지 않는다.
            실행 게이트는 여기서 돌지 않는다 — 비싸고, 이미 `validate` 의 일이다.
            배포 팩에는 solutions 가 없으므로 **구운 뒤에는 실행 게이트를 돌릴 수 없다.**
            그래서 순서가 validate → build 이지 그 반대가 아니다.

            --sign 을 주면 \(SigningEnvironment.privateKeyVariable) 의 개인키로
            정규 매니페스트 바이트에 서명해 \(PackLayout.signatureFileName) 을 함께 굽는다.
            **서명 파일만은 재현되지 않는다** — CryptoKit 의 Ed25519 가 논스에 난수를
            섞기 때문이고(실측), 나머지 파일은 서명을 붙여도 바이트가 같다.

            종료 코드: 0 통과 · 1 소스 팩 검증 실패 · 2 사용법·입출력 오류.
            """
    )

    @Argument(help: "소스 팩 디렉터리 경로")
    var packPath: String

    @Option(name: [.customShort("o"), .long], help: "구운 tar 를 쓸 경로 (기본 <packID>-<version>.tar)")
    var output: String?

    @Option(name: .long, help: "배포 트리를 펼칠 자리 (기본 <output>.staging)")
    var staging: String?

    @Flag(name: .long, help: "매니페스트에 서명해 함께 굽는다")
    var sign = false

    func run() async throws {
        let source = URL(fileURLWithPath: packPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ValidateCommand.toolFailure("팩 디렉터리가 아니다: \(packPath)")
        }

        // 굽기 전 게이트. 툴체인 없는 머신에서도 도는 세 단계만 본다.
        let outcome = await PackValidator(
            packDirectory: source, options: ValidationOptions(runExecution: false)
        ).validate()
        guard outcome.isClean else {
            FileHandle.standardError.write(Data(TextReport.render(outcome).utf8))
            FileHandle.standardError.write(
                Data("packtool: 검증에 실패한 팩은 굽지 않는다.\n".utf8))
            throw ExitCode(1)
        }

        let signingKey: String?
        if sign {
            do {
                signingKey = try SigningEnvironment.privateKey()
            } catch {
                throw ValidateCommand.toolFailure("\(error)")
            }
        } else {
            signingKey = nil
        }

        let manifestVersion = outcome.report.packVersion
        let defaultName = "\(outcome.report.packID)-\(manifestVersion).tar"
        let archiveURL = URL(fileURLWithPath: output ?? defaultName)
        let stagingURL = URL(
            fileURLWithPath: staging ?? archiveURL.path + ".staging", isDirectory: true)

        let result: DistributionResult
        do {
            result = try DistributionBuilder.build(
                source: source, staging: stagingURL, archiveURL: archiveURL,
                signingKeyBase64: signingKey)
        } catch {
            throw ValidateCommand.toolFailure("\(error)")
        }

        var out = "packtool build — \(result.manifest.packID.rawValue)@\(result.manifest.version)\n"
        out += "벗긴 파일 \(result.strippedPaths.count)개:\n"
        for path in result.strippedPaths { out += "  − \(path)\n" }
        out += "남은 파일 \(result.manifest.files.count)개"
        out += result.signed ? " + 서명\n" : "\n"
        out += "\(archiveURL.path) (\(result.archiveBytes)B, 루트 \(result.rootName)/)\n"
        // 스테이징을 지우지 않고 경로를 알려 준다 — `packtool verify` 가 보는 것은
        // tar 가 아니라 디렉터리라서, 방금 구운 것을 확인하려면 이 경로가 필요하다.
        out += "배포 트리 \(stagingURL.path)\n"
        FileHandle.standardOutput.write(Data(out.utf8))
    }
}
