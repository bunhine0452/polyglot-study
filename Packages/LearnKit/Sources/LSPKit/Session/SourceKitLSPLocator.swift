internal import Foundation
internal import RunnerKit

/// `sourcekit-lsp` 실행 경로와 그 서버가 필요로 하는 환경.
public struct SourceKitLSPInstallation: Hashable, Sendable {
    /// 실제 바이너리 절대경로. `/usr/bin` 의 xcrun 셰이더가 아니다.
    public var executablePath: String
    /// `xcrun --show-sdk-path` 로 해석한 SDK 루트.
    public var sdkRoot: String?
    /// `xcode-select -p` 가 가리키는 개발자 디렉터리.
    public var developerDirectory: String?

    public init(executablePath: String, sdkRoot: String? = nil, developerDirectory: String? = nil) {
        self.executablePath = executablePath
        self.sdkRoot = sdkRoot
        self.developerDirectory = developerDirectory
    }
}

/// `sourcekit-lsp` 를 찾는다.
///
/// `ToolchainProbe` 를 재사용하지 않는 이유: 그쪽은 **사용자 코드**를 돌릴 툴체인을
/// 버전 정책과 함께 고르는 장치다(파이썬 3.9 를 버리고 3.14 를 고르는 것 같은).
/// 언어 서버는 정책 선택지가 없다 — Xcode 에 동봉된 것 하나뿐이고, 우리는 그것을
/// 띄우거나 못 띄우거나 둘 중 하나다. 짧은 명령 실행기(`BoundedCommand`)만 빌려 쓴다.
public enum SourceKitLSPLocator {
    /// `xcrun` 이 개발자 디렉터리 없이 불리면 GUI 다이얼로그를 띄운다. 먼저 확인한다.
    static let xcrunPath = "/usr/bin/xcrun"
    static let xcodeSelectPath = "/usr/bin/xcode-select"

    /// 이 머신에서 Swift 언어 서버를 쓸 수 있는지 확인한다.
    ///
    /// 못 찾으면 던진다. 호출하는 쪽(`SwiftLanguageService`)은 이 실패를 **정상 경로**로
    /// 다룬다 — 서버가 없는 머신에서도 에디터는 그대로 동작해야 하고, swiftc 진단은
    /// 실행 시점에 따로 온다.
    public static func locate(timeout: Duration = .seconds(10)) async throws -> SourceKitLSPInstallation {
        let developerDirectory = await run(Self.xcodeSelectPath, ["-p"], timeout: timeout)
        guard let developerDirectory, !developerDirectory.isEmpty else {
            throw LSPTransportError.serverUnavailable(
                "xcode-select -p 가 개발자 디렉터리를 주지 않는다 — Xcode 나 커맨드라인 도구가 없다."
            )
        }

        guard let executable = await run(Self.xcrunPath, ["--find", "sourcekit-lsp"], timeout: timeout),
              FileManager.default.isExecutableFile(atPath: executable)
        else {
            throw LSPTransportError.serverUnavailable(
                "xcrun --find sourcekit-lsp 가 실행 가능한 경로를 주지 않는다."
            )
        }

        // SDKROOT 가 비어 있으면 **swiftc 가 표준 라이브러리를 못 찾는다** — 이 저장소가
        // 실행 게이트에서 이미 밟은 함정이고, sourcekit-lsp 도 같은 것을 본다.
        // 없다고 실패시키지는 않는다(서버가 스스로 찾는 경로도 있다).
        let sdkRoot = await run(Self.xcrunPath, ["--show-sdk-path"], timeout: timeout)

        return SourceKitLSPInstallation(
            executablePath: executable,
            sdkRoot: sdkRoot.flatMap { $0.isEmpty ? nil : $0 },
            developerDirectory: developerDirectory
        )
    }

    /// 못 찾아도 던지지 않는 판정. 테스트가 서버 유무로 갈라질 때 쓴다.
    public static func isAvailable() async -> Bool {
        (try? await locate()) != nil
    }

    private static func run(_ executable: String, _ arguments: [String], timeout: Duration) async -> String? {
        let result = await BoundedCommand.run(
            executable: executable,
            arguments: arguments,
            timeout: timeout
        )
        guard result.succeeded else { return nil }
        return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
