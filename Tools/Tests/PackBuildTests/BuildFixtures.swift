import ContentKit
import Foundation

/// 픽스처 팩과 임시 작업 공간. `PackValidateTests` 의 `FixturePacks` 와 같은 팩을 본다 —
/// 굽는 쪽과 검증하는 쪽이 다른 팩을 보면 두 테스트가 서로를 지켜 주지 못한다.
enum BuildFixtures {
    /// `Tools/Tests`
    static let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // PackBuildTests
        .deletingLastPathComponent()  // Tests

    /// 네 단계를 전부 통과하는 기준 팩 (python + sql).
    static let sourcePack = testsRoot.appendingPathComponent(
        "Fixtures/packs/fixture-mvp", isDirectory: true)

    /// 테스트 하나가 쓰는 임시 디렉터리. 호출자가 ``remove(_:)`` 로 지운다.
    static func workspace(_ label: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("packbuild-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    /// 소스 팩을 임시 공간으로 복사한다. 손대는 테스트는 원본을 건드리면 안 된다.
    static func copySource(into workspace: URL) throws -> URL {
        let destination = workspace.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.copyItem(at: sourcePack, to: destination)
        return destination
    }

    /// 테스트 전용 키 쌍. 매번 새로 만든다 — 저장소에 키가 커밋될 자리를 두지 않는다.
    static func keyPair() -> (private: String, public: String) {
        let pair = PackSigning.generateKeyPair()
        return (pair.privateKeyBase64, pair.publicKeyBase64)
    }

    /// `/usr/bin/tar` 로 풀어 본다. 우리가 만든 헤더를 **남의 구현**이 읽는지 보는 것이
    /// 자기 리더로 왕복하는 것보다 강한 증거다.
    @discardableResult
    static func extract(_ archive: URL, into directory: URL) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xvf", archive.path, "-C", directory.path]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()
        try process.run()
        let listing = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TarFailure(status: process.terminationStatus)
        }
        return String(decoding: listing, as: UTF8.self)
    }

    struct TarFailure: Error { let status: Int32 }
}
