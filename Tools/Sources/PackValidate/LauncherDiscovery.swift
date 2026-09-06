public import Foundation
internal import RunnerKit

/// `learn-launcher` 를 찾는다 — `packtool` 이 실행 게이트를 태우려면 반드시 있어야 한다.
///
/// ``LauncherLocator`` 가 이미 세 곳(환경변수·앱 번들·실행 파일 형제)을 본다. 그런데
/// **`Tools` 패키지를 빌드해도 런처는 만들어지지 않는다** — 런처는 `LearnKit` 의
/// 실행 타깃이고 라이브러리 프로덕트로 노출돼 있지 않아서, `Tools` 의 의존성 그래프에
/// 들어오지 않는다(실측: `Tools/.build/debug` 에 `learn-launcher` 가 없다).
///
/// 그래서 네 번째 후보를 더한다 — 현재 디렉터리와 실행 파일에서 위로 올라가며
/// `Packages/LearnKit/.build/*/learn-launcher` 를 찾는다. 개발 체크아웃과 CI 워크스페이스
/// 둘 다 이 배치다. 못 찾으면 **조용히 격리 없는 실행으로 강등하지 않고** 실패한다.
///
/// - Note: 위로 올라가므로 git 워크트리 안에서 돌리면 **부모 체크아웃의 산출물**을 집을
///   수 있다(실측). 가까운 쪽이 항상 먼저이므로 워크트리가 자기 것을 빌드해 두면 그쪽이
///   이기고, 없을 때만 부모 것을 쓴다. 런처는 소스가 같으면 바이트가 같은 작은 C 프로그램이라
///   그 대체를 허용한다 — 대신 "런처가 없어서 못 돌았다"가 조용히 통과가 되는 일이 없다.
public enum LauncherDiscovery {
    public static func locate() -> URL? { locate(startingFrom: defaultStarts()) }

    static func locate(startingFrom directories: [URL]) -> URL? {
        if let standard = try? LauncherLocator.locate() { return standard }
        for start in directories {
            if let found = searchUpward(from: start) { return found }
        }
        return nil
    }

    public static let hint = """
        learn-launcher 를 찾지 못했다. Tools 패키지를 빌드해도 런처는 만들어지지 않는다 \
        (LearnKit 의 실행 타깃이라 Tools 의 의존성 그래프 밖이다). \
        `swift build --package-path Packages/LearnKit` 를 한 번 돌리거나 \
        LEARN_LAUNCHER_PATH 로 경로를 직접 지정해라.
        """

    static func defaultStarts() -> [URL] {
        var starts = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            starts.append(executable)
        }
        return starts
    }

    /// `<dir>/Packages/LearnKit/.build/**/learn-launcher` 를 위로 올라가며 찾는다.
    static func searchUpward(from start: URL) -> URL? {
        var directory = start.standardizedFileURL
        // 루트까지 올라가되 상한을 둔다 — 심볼릭 링크 고리에 걸려 무한 루프에 빠지지 않게.
        for _ in 0..<12 {
            if let found = launcher(under: directory.appendingPathComponent("Packages/LearnKit")) {
                return found
            }
            if let found = launcher(under: directory) { return found }
            let parent = directory.deletingLastPathComponent().standardizedFileURL
            if parent == directory { break }
            directory = parent
        }
        return nil
    }

    private static func launcher(under packageRoot: URL) -> URL? {
        let build = packageRoot.appendingPathComponent(".build")
        var candidates: [URL] = [
            build.appendingPathComponent("debug/\(LauncherLocator.executableName)"),
            build.appendingPathComponent("release/\(LauncherLocator.executableName)"),
        ]
        // `.build/debug` 심링크가 없는 배치(`arm64-apple-macosx/debug`)도 훑는다.
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: build.path) {
            for entry in entries.sorted() {
                candidates.append(
                    build.appendingPathComponent("\(entry)/debug/\(LauncherLocator.executableName)"))
                candidates.append(
                    build.appendingPathComponent("\(entry)/release/\(LauncherLocator.executableName)"))
            }
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
