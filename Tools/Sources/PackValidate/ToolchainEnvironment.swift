internal import Darwin
internal import Foundation
internal import RunnerKit

/// `swiftc` 가 SDK 를 찾을 수 있도록 프로세스 환경에 `SDKROOT` 을 채운다.
///
/// ## 왜 필요한가 (실측 2026-09-06, Xcode 26.6 / macOS 26.6)
///
/// `xcrun --find swiftc` 가 준 절대경로를 **환경 없이 그대로 실행하면** 컴파일이 이렇게 죽는다.
///
/// ```
/// <unknown>:0: error: unable to load standard library for target 'arm64-apple-macosx26.0'
/// ```
///
/// `swift build` / `swift test` 아래에서는 SwiftPM 이 `SDKROOT` 을 넣어 주기 때문에 이 실패가
/// 보이지 않는다. 그래서 `swift run packtool …` 은 통과하고 **같은 바이너리를 직접 실행하면
/// Swift 예제 전부가 "컴파일 실패"로 뒤집힌다.** 실제로 그 차이를 봤다 — 2건 실패가 4건이 됐다.
///
/// 이것은 콘텐츠의 결함이 아니라 실행 환경의 결함이므로, 게이트가 여기서 채워 넣지 않으면
/// 멀쩡한 레슨을 `lessongen repair` 에게 고치라고 돌려보내게 된다. 가장 나쁜 종류의 오탐이다.
///
/// - Important: 근본 원인은 `RunnerKit.SwiftProgram` 이 컴파일러를 **부모 프로세스 환경 그대로**
///   띄운다는 것이고, 그 코드는 이 작업의 소유가 아니다(`Packages/LearnKit` 은 읽기 전용).
///   앱도 같은 문제를 만난다 — Finder 로 띄운 `.app` 에는 `SDKROOT` 이 없다. 위로 보고할 것.
enum ToolchainEnvironment {
    static let key = "SDKROOT"

    /// 지금 이 프로세스의 `SDKROOT`. `ProcessInfo.environment` 가 아니라 `getenv` 를 읽는다 —
    /// 우리가 `setenv` 로 바꾼 값을 스냅샷 캐시 없이 그대로 보기 위해서다.
    static var current: String? {
        guard let raw = getenv(key) else { return nil }
        return String(cString: raw)
    }

    /// 프로세스 환경에 `SDKROOT` 이 없으면 `xcrun` 으로 채운다. 이미 있으면 손대지 않는다.
    ///
    /// `setenv(3)` 는 다른 스레드의 `getenv` 와 경쟁할 수 있으므로 **정확히 한 번만** 부른다 —
    /// 그 "한 번"을 보장하는 것이 이 액터고, 진행 중인 작업을 캐시해 재진입에도 한 번을 지킨다.
    static func ensureSDKRoot() async {
        await Resolver.shared.ensure()
    }

    private actor Resolver {
        static let shared = Resolver()
        private var inFlight: Task<Void, Never>?

        func ensure() async {
            if let inFlight { return await inFlight.value }
            let task = Task { await Resolver.resolveAndSet() }
            inFlight = task
            await task.value
        }

        private static func resolveAndSet() async {
            guard current?.isEmpty != false else { return }
            let result = await BoundedCommand.run(
                executable: "/usr/bin/xcrun",
                arguments: ["--sdk", "macosx", "--show-sdk-path"],
                timeout: .seconds(15))
            let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.succeeded, !path.isEmpty,
                FileManager.default.fileExists(atPath: path)
            else { return }
            setenv(key, path, 1)
        }
    }
}
