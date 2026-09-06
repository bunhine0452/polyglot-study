internal import ArgumentParser
internal import ContentKit
internal import Foundation
internal import PackBuild

struct SignCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "팩의 정규 매니페스트 바이트에 분리 서명한다",
        discussion: """
            \(PackLayout.manifestFileName) 의 바이트 그대로에 Ed25519 로 서명해
            \(PackLayout.signatureFileName) 을 옆에 쓴다. 매니페스트를 다시 굽지 않는다 —
            서명 대상은 **디스크에 있는 그 바이트열**이어야 한다.

            매니페스트가 정규형이 아니면 서명하지 않고 거부한다. 정규형이 아닌 바이트에
            서명하면 "무엇에 서명했는가" 가 인코더 설정에 달리게 된다.

            개인키는 \(SigningEnvironment.privateKeyVariable) 에서만 읽는다.
            플래그로 받지 않는 이유는 셸 히스토리·ps 출력·CI 로그다.

            종료 코드: 0 성공 · 2 사용법·키·입출력 오류.
            """
    )

    @Argument(help: "팩 디렉터리 경로")
    var packPath: String

    @Flag(name: .long, help: "이미 서명이 있어도 덮어쓴다")
    var force = false

    func run() async throws {
        let directory = URL(fileURLWithPath: packPath, isDirectory: true)
        let signatureURL = PackSignatureVerification.signatureURL(in: directory)
        if !force, FileManager.default.fileExists(atPath: signatureURL.path) {
            throw ValidateCommand.toolFailure(
                "이미 서명이 있다: \(signatureURL.path) (덮어쓰려면 --force)")
        }

        let bytes: Data
        do {
            bytes = try PackSignatureVerification.canonicalManifestBytes(in: directory)
        } catch {
            throw ValidateCommand.toolFailure("\(error)")
        }

        let key: String
        do {
            key = try SigningEnvironment.privateKey()
        } catch {
            throw ValidateCommand.toolFailure("\(error)")
        }

        let signature: PackSignature
        do {
            signature = try PackSigning.sign(manifestBytes: bytes, privateKeyBase64: key)
        } catch {
            throw ValidateCommand.toolFailure("\(error)")
        }

        do {
            try Data(signature.canonicalText().utf8).write(to: signatureURL, options: .atomic)
        } catch {
            throw ValidateCommand.toolFailure("서명을 쓸 수 없다 (\(signatureURL.path)): \(error)")
        }

        let out = """
            packtool sign — \(signatureURL.path)
            공개키 \(signature.publicKeyBase64)

            """
        FileHandle.standardOutput.write(Data(out.utf8))
    }
}

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "서명과 파일 해시를 함께 검증한다",
        discussion: """
            둘 다 본다.

              1. \(PackLayout.signatureFileName) 이 \(SigningEnvironment.publicKeyVariable) 의
                 공개키로 만든 것이고 정규 매니페스트 바이트에 맞는가.
              2. files[] 의 모든 항목이 디스크와 크기·sha256 까지 일치하는가.

            서명만 보면 안 된다. 서명 대상은 매니페스트 한 파일이라, 레슨 본문을 바꿔도
            서명은 그대로 통과한다. 그 변조를 잡는 것은 해시 대조이고, 그 대조표가
            진짜인지를 보장하는 것이 서명이다. 둘은 한 쌍이다.

            서명이 없는 팩은 거부한다 — "서명이 없으면 통과" 는 게이트가 아니다.

            종료 코드: 0 통과 · 1 검증 실패 · 2 사용법·키 오류.
            """
    )

    @Argument(help: "팩 디렉터리 경로")
    var packPath: String

    func run() async throws {
        let directory = URL(fileURLWithPath: packPath, isDirectory: true)

        let publicKey: String
        do {
            publicKey = try SigningEnvironment.publicKey()
        } catch {
            throw ValidateCommand.toolFailure("\(error)")
        }

        do {
            try PackSignatureVerification.verifyPack(
                at: directory, expectedPublicKeyBase64: publicKey)
        } catch {
            FileHandle.standardError.write(
                Data("packtool verify: 거부 — \(error)\n".utf8))
            throw ExitCode(1)
        }

        FileHandle.standardOutput.write(
            Data("packtool verify — 서명·해시 모두 통과: \(directory.path)\n".utf8))
    }
}

struct KeygenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keygen",
        abstract: "서명 키 쌍을 만든다 — 개인키는 파일로만, 공개키만 stdout 으로",
        discussion: """
            개인키는 stdout 에 **절대 찍지 않는다.** 0600 파일로만 나가고, 그 파일이
            이미 있으면 덮어쓰지 않고 거부한다.

            쓰는 법:

              packtool keygen --private-key-out ~/.config/polyglot/pack-signing.key
              export \(SigningEnvironment.privateKeyVariable)="$(cat ~/.config/polyglot/pack-signing.key)"
              export \(SigningEnvironment.publicKeyVariable)="<위에서 찍힌 공개키>"

            종료 코드: 0 성공 · 2 사용법·입출력 오류.
            """
    )

    @Option(name: .long, help: "개인키를 쓸 파일 경로 (0600, 덮어쓰지 않음)")
    var privateKeyOut: String

    func run() async throws {
        let url = URL(fileURLWithPath: privateKeyOut)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw ValidateCommand.toolFailure(
                "이미 파일이 있다: \(url.path) — 덮어쓰지 않는다. 다른 경로를 주거나 직접 지워라")
        }

        let pair = PackSigning.generateKeyPair()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // 파일을 만들 때부터 0600 이어야 한다. 쓰고 나서 chmod 하면 그 사이가 열려 있다.
            guard
                FileManager.default.createFile(
                    atPath: url.path,
                    contents: Data(pair.privateKeyBase64.utf8),
                    attributes: [.posixPermissions: 0o600])
            else {
                throw ValidateCommand.toolFailure("개인키를 쓸 수 없다: \(url.path)")
            }
        } catch let error as ExitCode {
            throw error
        } catch {
            throw ValidateCommand.toolFailure("개인키를 쓸 수 없다 (\(url.path)): \(error)")
        }

        let out = """
            packtool keygen
            개인키 → \(url.path) (0600)
            공개키   \(pair.publicKeyBase64)

            \(SigningEnvironment.publicKeyVariable) 에 위 공개키를,
            \(SigningEnvironment.privateKeyVariable) 에 그 파일의 내용을 넣어 쓴다.

            """
        FileHandle.standardOutput.write(Data(out.utf8))
    }
}
