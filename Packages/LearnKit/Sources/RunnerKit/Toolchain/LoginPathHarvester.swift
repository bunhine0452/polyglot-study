internal import Foundation

/// 로그인 셸의 `PATH` 를 수확한다.
///
/// GUI 앱은 launchd 에서 뜨므로 `.zshrc` / `.zprofile` 이 만든 PATH 를 **상속하지 않는다.**
/// `/usr/bin:/bin:/usr/sbin:/sbin` 정도만 보이는 게 정상이라, 그대로 두면 homebrew ·
/// cargo · conda · fnm 에 설치된 툴체인이 전부 "없음" 으로 보인다.
///
/// 함정은 rc 파일이 조용하지 않다는 것이다. 이 머신의 powerlevel10k 는 rc 에서 경고를
/// 뱉고, instant prompt 는 stdout 까지 오염시킨다. 그래서 **센티널로 감싼 값만** 뽑는다 —
/// "마지막 줄을 읽는다" 류의 휴리스틱은 여기서 반드시 깨진다.
public struct LoginPathHarvest: Sendable, Hashable {
    /// 존재가 확인된 디렉터리들. 중복 제거 + 원래 순서 유지.
    public var directories: [String]
    /// 셸이 돌려준 원문 PATH. 프로브 캐시 키에 들어간다.
    public var rawPath: String?
    /// 셸 질의가 실패해 관례 경로로 떨어졌는가.
    public var usedFallback: Bool

    public init(directories: [String], rawPath: String?, usedFallback: Bool) {
        self.directories = directories
        self.rawPath = rawPath
        self.usedFallback = usedFallback
    }
}

public enum LoginPathHarvester {
    static let beginSentinel = "__LEARNKIT_PATH_BEGIN__"
    static let endSentinel = "__LEARNKIT_PATH_END__"

    /// `-l` 로 `.zprofile`, `-i` 로 `.zshrc` 를 둘 다 태운다. 툴체인 PATH 는 보통 rc 쪽에 있다.
    static var probeArguments: [String] {
        ["-lic", "printf '%s' \"\(beginSentinel)$PATH\(endSentinel)\""]
    }

    public static func harvest(
        shell: String = "/bin/zsh",
        timeout: Duration = .seconds(3)
    ) async -> LoginPathHarvest {
        let result = await BoundedCommand.run(
            executable: shell,
            arguments: probeArguments,
            // stderr 는 아래에서 통째로 버린다. rc 경고를 PATH 로 오인하면 안 된다.
            environment: nil,
            timeout: timeout
        )

        if let raw = extractPath(from: result.standardOutput), !raw.isEmpty {
            let entries = directories(fromPathVariable: raw)
            let existing = existingDirectories(entries + conventionalDirectories())
            return LoginPathHarvest(directories: existing, rawPath: raw, usedFallback: false)
        }

        // 셸이 없거나 타임아웃했거나 센티널이 안 나왔다 — 관례 경로만으로 간다.
        return LoginPathHarvest(
            directories: existingDirectories(conventionalDirectories()),
            rawPath: nil,
            usedFallback: true
        )
    }

    /// 센티널 사이만 도려낸다. rc 소음이 앞뒤로 얼마가 붙든 무관하게 만드는 유일한 방법.
    public static func extractPath(from output: String) -> String? {
        guard let start = output.range(of: beginSentinel) else { return nil }
        let remainder = output[start.upperBound...]
        guard let end = remainder.range(of: endSentinel) else { return nil }
        return String(remainder[..<end.lowerBound])
    }

    public static func directories(fromPathVariable value: String) -> [String] {
        value.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
    }

    /// PATH 에 없더라도 툴체인이 실제로 사는 곳들.
    ///
    /// GUI 실행에서 PATH 수확이 실패했을 때의 폴백이자, 성공했을 때도 **덧붙이는** 목록이다.
    /// 사용자가 `.zshrc` 에서 conda 를 지웠어도 바이너리는 여전히 그 자리에 있다.
    public static func conventionalDirectories() -> [String] {
        conventionalDirectories(home: NSHomeDirectory(), fileManager: .default)
    }

    static func conventionalDirectories(home: String, fileManager: FileManager) -> [String] {
        var directories: [String] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/go/bin",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "\(home)/go/bin",
            "\(home)/miniconda3/bin",
            "\(home)/anaconda3/bin",
            "\(home)/miniforge3/bin",
            "\(home)/.pyenv/shims",
            "\(home)/.rbenv/shims",
            "\(home)/.local/share/mise/shims",
            "\(home)/.asdf/shims",
            "\(home)/.sdkman/candidates/java/current/bin",
            "\(home)/.bun/bin",
            "\(home)/.deno/bin",
        ]
        // 버전 매니저는 버전 디렉터리를 하나 더 파고들어야 실행 파일이 나온다.
        directories.append(contentsOf: versionedDirectories(
            root: "\(home)/.local/share/fnm/node-versions",
            suffix: ["installation", "bin"],
            fileManager: fileManager
        ))
        directories.append(contentsOf: versionedDirectories(
            root: "\(home)/.nvm/versions/node",
            suffix: ["bin"],
            fileManager: fileManager
        ))
        return directories
    }

    static func versionedDirectories(
        root: String,
        suffix: [String],
        fileManager: FileManager
    ) -> [String] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: root) else { return [] }
        return names.sorted().map { name in
            ([root, name] + suffix).joined(separator: "/")
        }
    }

    static func existingDirectories(_ candidates: [String]) -> [String] {
        let fileManager = FileManager.default
        var seen = Set<String>()
        var result: [String] = []
        for candidate in candidates {
            let normalized = candidate.hasSuffix("/") && candidate.count > 1
                ? String(candidate.dropLast())
                : candidate
            guard !seen.contains(normalized) else { continue }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: normalized, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }
}
