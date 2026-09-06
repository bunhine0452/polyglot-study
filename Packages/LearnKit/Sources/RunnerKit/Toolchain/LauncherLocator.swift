public import Foundation
internal import LanguageKit

/// `learn-launcher` 헬퍼를 찾는다.
///
/// 탐색 순서는 셋이고 이유가 각각 다르다.
///   1. `LEARN_LAUNCHER_PATH` — 테스트와 CI 가 빌드 산출물을 직접 가리킨다.
///   2. 앱 번들의 보조 실행 파일 (`Contents/MacOS`, 그리고 `Contents/Helpers`) —
///      배포 형태. 여기 들어간 바이너리만 앱과 같은 Team ID 로 서명돼 있다.
///   3. 현재 실행 파일의 형제 — `swift run` / `swift build` 산출물 레이아웃.
///
/// 셋 다 실패하면 `RunFailure.toolchainMissing` 을 던진다. 서브프로세스 백엔드는
/// 런처 없이 동작하면 안 된다 — 격리 없는 실행으로 조용히 강등되는 것이 최악이다.
public enum LauncherLocator {
    public static let executableName = "learn-launcher"
    public static let environmentKey = "LEARN_LAUNCHER_PATH"

    /// 탐색 입력. 테스트가 파일 시스템만 준비하고 나머지를 주입할 수 있게 값으로 받는다.
    public struct Sources: Sendable {
        public var environment: [String: String]
        /// `Bundle.main.url(forAuxiliaryExecutable:)` 결과.
        public var bundleAuxiliary: URL?
        /// `Contents/Helpers/learn-launcher`.
        public var bundleHelpers: URL?
        /// 현재 실행 파일이 있는 디렉터리.
        public var siblingDirectory: URL?

        public init(
            environment: [String: String] = [:],
            bundleAuxiliary: URL? = nil,
            bundleHelpers: URL? = nil,
            siblingDirectory: URL? = nil
        ) {
            self.environment = environment
            self.bundleAuxiliary = bundleAuxiliary
            self.bundleHelpers = bundleHelpers
            self.siblingDirectory = siblingDirectory
        }
    }

    /// 실행 가능한 후보를 순서대로 돌려준다. 존재 여부는 확인하지 않는다.
    public static func candidates(_ sources: Sources) -> [URL] {
        var result: [URL] = []
        if let override = sources.environment[environmentKey], !override.isEmpty {
            result.append(URL(fileURLWithPath: override))
        }
        if let auxiliary = sources.bundleAuxiliary {
            result.append(auxiliary)
        }
        if let helpers = sources.bundleHelpers {
            result.append(helpers)
        }
        if let sibling = sources.siblingDirectory {
            result.append(sibling.appendingPathComponent(executableName))
        }
        return result
    }

    public static func locate(_ sources: Sources) throws -> URL {
        let manager = FileManager.default
        for candidate in candidates(sources) where manager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        throw RunFailure.toolchainMissing(hint: hint(sources))
    }

    public static func locate() throws -> URL {
        try locate(standardSources())
    }

    public static func standardSources() -> Sources {
        let bundle = Bundle.main
        var helpers: URL?
        if bundle.bundleURL.pathExtension == "app" {
            helpers = bundle.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Helpers")
                .appendingPathComponent(executableName)
        }
        return Sources(
            environment: ProcessInfo.processInfo.environment,
            bundleAuxiliary: bundle.url(forAuxiliaryExecutable: executableName),
            bundleHelpers: helpers,
            siblingDirectory: bundle.executableURL?.deletingLastPathComponent()
        )
    }

    static func hint(_ sources: Sources) -> String {
        let searched = candidates(sources).map(\.path)
        if searched.isEmpty {
            return "\(executableName) 를 찾을 수 없다. \(environmentKey) 로 경로를 지정하거나 앱 번들 Contents/Helpers 에 넣어라."
        }
        return "\(executableName) 를 찾을 수 없다 (확인한 경로: \(searched.joined(separator: ", "))). "
            + "\(environmentKey) 로 경로를 지정하거나 앱 번들 Contents/Helpers 에 넣어라."
    }
}
