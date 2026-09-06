public import Foundation
private import Darwin

/// 프로파일을 만들 수 없는 이유. 전부 **스폰 전에** 판정된다.
public struct SandboxProfileError: Error, Hashable, Sendable, CustomStringConvertible {
    public enum Reason: String, Hashable, Sendable {
        /// `realpath(3)` 이 실패했다 — 존재하지 않거나 접근할 수 없는 경로.
        case unresolvable
        /// 해석 결과가 절대경로가 아니다.
        case notAbsolute
        /// SBPL 문자열 리터럴에 넣을 수 없는 제어문자가 들어 있다.
        case controlCharacter

        public var korean: String {
            switch self {
            case .unresolvable: "경로를 해석할 수 없음"
            case .notAbsolute: "절대경로가 아님"
            case .controlCharacter: "제어문자가 포함된 경로"
            }
        }
    }

    public var path: String
    public var reason: Reason
    public var underlying: String?

    public init(path: String, reason: Reason, underlying: String? = nil) {
        self.path = path
        self.reason = reason
        self.underlying = underlying
    }

    public var description: String {
        if let underlying {
            "\(reason.korean): \(path) — \(underlying)"
        } else {
            "\(reason.korean): \(path)"
        }
    }
}

/// 경로를 커널이 보는 형태로 굳힌다.
///
/// 샌드박스 규칙은 **심링크가 풀린 경로**로 평가된다. `/var/folders/...` 를 그대로
/// `(subpath ...)` 에 넣으면 규칙이 아무것도 매치하지 않아 워크스페이스 쓰기까지
/// 조용히 거부된다 — 실측으로 확인했다(2026-09-06, macOS 26.6). 그래서 프로파일에
/// 들어가는 모든 경로는 `realpath(3)` 를 거친다.
///
/// 반대 방향은 신경 쓸 필요가 없다. **규칙**만 해석돼 있으면 사용자 코드가 여는 경로는
/// `/var/folders/...` 든 `/private/var/folders/...` 든 상대경로든 전부 통과한다 —
/// 커널이 대상 vnode 를 먼저 풀고 나서 규칙과 맞추기 때문이다.
///
/// - Warning: Foundation 의 `resolvingSymlinksInPath` 로는 안 된다. 그건 realpath 가
///   아니라 표준화 함수라서 `/var` 를 풀어 주지 않고 오히려 `/private` 접두사를 떼어 낸다.
public enum SandboxPath {
    public static func resolve(_ url: URL) throws -> String {
        try resolve(url.path)
    }

    public static func resolve(_ path: String) throws -> String {
        guard let resolved = realpath(path, nil) else {
            throw SandboxProfileError(
                path: path,
                reason: .unresolvable,
                underlying: String(cString: strerror(errno))
            )
        }
        defer { free(resolved) }
        let result = String(cString: resolved)
        guard result.hasPrefix("/") else {
            throw SandboxProfileError(path: path, reason: .notAbsolute)
        }
        return result
    }
}

/// 사용자 코드를 가두는 `sandbox-exec` SBPL 프로파일 v1.
///
/// 세 문장으로 요약된다.
///   1. **네트워크 전면 차단** — `(deny network*)`. 아웃바운드·바인드·유닉스 소켓 전부.
///   2. **쓰기는 워크스페이스와 실행 전용 TMPDIR 만** — 그 밖은 전부 거부.
///   3. **읽기는 관대하되 비밀은 예외** — 툴체인이 SDK·모듈 캐시·`/usr/lib` 를 광범위하게
///      읽어야 하므로 `file-read*` 를 통째로 열고, `~/.ssh`·`~/.aws`·키체인 같은
///      민감 경로만 뒤에서 명시적으로 되막는다.
///
/// ## 프로파일 인젝션
///
/// 워크스페이스 경로는 **SBPL 텍스트에 절대 끼워 넣지 않는다.** `sandbox-exec -D KEY=VALUE`
/// 로 넘기고 프로파일 안에서는 `(param "KEY")` 로만 받는다. `-D` 값은 argv 원소 하나라
/// 따옴표·개행·괄호가 섞여도 SBPL 파서에 도달하지 않는다. 실측으로 확인했다 —
/// `ev "il\n)(allow default)(subpath "/` 라는 이름의 디렉터리를 워크스페이스로 줘도
/// 샌드박스는 그대로 닫혀 있었다.
///
/// 반대로 **거부 목록**은 SBPL 텍스트에 들어간다(호출자가 바꿀 수 있으므로). 그쪽은
/// `sbplStringLiteral(_:)` 로 이스케이프하고 제어문자는 아예 거부한다.
///
/// ## 규칙 순서
///
/// SBPL 은 **마지막에 매치한 규칙이 이긴다.** 그래서 순서가 곧 정책이다 —
/// `allow file-read*` → `allow file-write*(워크스페이스)` → `deny(민감 경로)` →
/// `deny network*`. 민감 경로 거부가 쓰기 허용보다 뒤에 있으므로, 실수로 워크스페이스를
/// `~/.ssh` 밑에 잡아도 비밀은 여전히 닫혀 있다.
///
/// ## `sandbox-exec` 의 지위
///
/// `sandbox-exec(1)` 은 man 페이지에 **deprecated** 로 표시돼 있지만 macOS 26.6 에서
/// 여전히 동작하고(이 파일의 모든 규칙을 실측으로 확인했다), Apple 이 내놓은 **공식
/// 대체재는 아직 없다.** App Sandbox 는 컨테이너 밖 툴체인 바이너리를 읽지도 못해
/// 로컬 툴체인 노선과 양립하지 않는다. 장기 대체 후보는 Apple Containerization
/// (경량 VM) 이고, 그쪽으로 옮기면 이 파일 대신 `RemoteRunner` 계열 백엔드가 된다.
/// 그때까지는 `sandbox-exec` + `learn-launcher` 이중 격리가 실무 정답이다.
public struct SandboxProfile: Sendable, Hashable {
    /// 체인의 앞단. 이 경로가 없으면 런처 단독 격리로 강등한다.
    public static let executablePath = "/usr/bin/sandbox-exec"

    public static let workspaceParameter = "LEARNKIT_WORKSPACE"
    public static let temporaryDirectoryParameter = "LEARNKIT_TMPDIR"
    public static let homeParameter = "LEARNKIT_HOME"

    /// 홈 아래에서 읽기·쓰기를 모두 막을 디렉터리. 선행 `/` 없이 적는다.
    public static let defaultDeniedHomeSubpaths = [
        ".ssh",
        ".aws",
        ".gnupg",
        ".kube",
        ".docker",
        ".config/gcloud",
        ".config/gh",
        "Library/Keychains",
        "Library/Cookies",
        "Library/Mail",
        "Library/Messages",
        "Library/Safari",
        "Library/Application Support/com.apple.TCC",
    ]

    /// 홈 아래에서 막을 개별 파일.
    public static let defaultDeniedHomeFiles = [
        ".netrc",
        ".npmrc",
        ".pypirc",
        ".git-credentials",
    ]

    /// 홈 밖의 민감 경로.
    public static let defaultDeniedAbsoluteSubpaths = [
        "/Library/Keychains",
        "/private/var/db/TCC",
        "/private/etc/ssh",
    ]

    /// 쓰기가 허용되는 유일한 두 곳 중 하나. `realpath` 를 통과한 절대경로다.
    public let workspaceRoot: String
    /// 실행 전용 TMPDIR. 워크스페이스 안이어도 되고 밖이어도 된다.
    public let temporaryDirectory: String
    /// 민감 경로 거부의 기준이 되는 홈 디렉터리.
    public let homeDirectory: String

    public let deniedHomeSubpaths: [String]
    public let deniedHomeFiles: [String]
    public let deniedAbsoluteSubpaths: [String]

    public init(
        workspaceRoot: URL,
        temporaryDirectory: URL,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        deniedHomeSubpaths: [String] = SandboxProfile.defaultDeniedHomeSubpaths,
        deniedHomeFiles: [String] = SandboxProfile.defaultDeniedHomeFiles,
        deniedAbsoluteSubpaths: [String] = SandboxProfile.defaultDeniedAbsoluteSubpaths
    ) throws {
        self.workspaceRoot = try SandboxPath.resolve(workspaceRoot)
        self.temporaryDirectory = try SandboxPath.resolve(temporaryDirectory)
        self.homeDirectory = try SandboxPath.resolve(homeDirectory)
        self.deniedHomeSubpaths = deniedHomeSubpaths
        self.deniedHomeFiles = deniedHomeFiles
        self.deniedAbsoluteSubpaths = deniedAbsoluteSubpaths
        // 거부 목록만 SBPL 텍스트에 들어간다 — 여기서 한 번 검증해 두면
        // `source` 는 던지지 않는 순수 계산 속성으로 남는다.
        for path in deniedHomeSubpaths + deniedHomeFiles + deniedAbsoluteSubpaths {
            _ = try Self.sbplStringLiteral(path)
        }
    }

    // MARK: - 자식에게 줄 부가 정보

    /// 자식 환경에 덮어써야 하는 변수.
    ///
    /// `TMPDIR` 을 실행 전용 디렉터리로 돌려두지 않으면 `tempfile`·`mkstemp` 계열이
    /// 시스템 기본 임시 디렉터리를 노리다가 전부 EPERM 을 맞는다.
    public var environmentOverrides: [String: String] {
        ["TMPDIR": temporaryDirectory.hasSuffix("/") ? temporaryDirectory : temporaryDirectory + "/"]
    }

    /// `swiftc` 모듈 캐시를 워크스페이스 안으로 유도하는 경로.
    ///
    /// 실측: 이 인자가 없어도 컴파일은 **성공한다** — 기본 캐시 경로
    /// (`<DARWIN_USER_CACHE_DIR>/clang/ModuleCache`) 쓰기가 거부돼도 SDK 의
    /// 프리빌트 모듈로 넘어가기 때문이다. 다만 그러면 매 실행이 캐시 미스라 느리고,
    /// 실패가 조용해서 원인 추적이 어렵다. 명시적으로 워크스페이스 안을 가리키면
    /// 캐시가 실제로 쌓이고(실측 20개 엔트리) 실행 간 격리도 유지된다.
    public var swiftModuleCachePath: String {
        workspaceRoot + "/.swift-module-cache"
    }

    public var swiftModuleCacheArguments: [String] {
        ["-module-cache-path", swiftModuleCachePath]
    }

    // MARK: - argv

    /// `-D` 파라미터. 경로가 SBPL 파서에 닿지 않는 유일한 이유가 이것이다.
    public var parameterArguments: [String] {
        [
            "-D", "\(Self.workspaceParameter)=\(workspaceRoot)",
            "-D", "\(Self.temporaryDirectoryParameter)=\(temporaryDirectory)",
            "-D", "\(Self.homeParameter)=\(homeDirectory)",
        ]
    }

    /// `sandbox-exec` 에 넘길 인자 중 대상 프로그램 **앞**에 오는 전부.
    ///
    /// 프로파일을 파일로 떨구지 않고 `-p` 로 argv 에 실어 보낸다 — 임시 파일이 없으면
    /// 정리할 것도, 사용자 코드가 바꿔치기할 표적도 없다.
    public var argumentPrefix: [String] {
        parameterArguments + ["-p", source, "--"]
    }

    // MARK: - SBPL

    /// TinyScheme 문자열 리터럴로 안전하게 감싼다. 제어문자는 이스케이프하지 않고 거부한다 —
    /// 경로에 제어문자가 있다는 건 규칙을 우회하려는 시도이거나 버그다.
    static func sbplStringLiteral(_ value: String) throws -> String {
        var escaped = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            default:
                guard scalar.value >= 0x20, scalar.value != 0x7F else {
                    throw SandboxProfileError(path: value, reason: .controlCharacter)
                }
                escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped + "\""
    }

    /// 홈 기준 상대 경로를 `(string-append (param "LEARNKIT_HOME") "/…")` 로 만든다.
    private static func homeRelative(_ component: String) -> String {
        let normalized = component.hasPrefix("/") ? component : "/" + component
        // init 에서 이미 검증했으므로 여기서 던질 일이 없다.
        let literal = (try? sbplStringLiteral(normalized)) ?? "\"/__invalid__\""
        return "(string-append (param \"\(homeParameter)\") \(literal))"
    }

    /// 완성된 SBPL 프로파일. 경로는 전부 `(param ...)` 또는 이스케이프된 리터럴이다.
    public var source: String {
        var lines: [String] = []

        lines.append("(version 1)")
        lines.append(";; learn-launcher 와 짝을 이루는 사용자 코드 격리 프로파일 v1.")
        lines.append(";; 기본은 전면 거부. 필요한 것만 아래에서 되돌린다.")
        lines.append("(deny default)")
        lines.append("")

        lines.append(";; --- 프로세스 ---")
        lines.append(";; 컴파일러는 clang·ld 를 다시 exec 하고, 채점 하네스는 자식을 띄운다.")
        lines.append(";; 프로세스 수 자체는 런처의 RLIMIT_NPROC 이 막으므로 여기서 세지 않는다.")
        lines.append("(allow process-fork)")
        lines.append("(allow process-exec*)")
        lines.append(";; 자기 프로세스 그룹 안에서만 시그널. 앱이나 다른 사용자 프로세스는 못 건드린다.")
        lines.append("(allow signal (target same-sandbox))")
        lines.append(";; confstr(_CS_DARWIN_USER_TEMP_DIR)·sysconf 가 이걸 쓴다. 막으면 xcrun 계열이")
        lines.append(";; /tmp 로 폴백하다가 치명적 오류로 죽는다 — 실측으로 확인했다.")
        lines.append("(allow sysctl-read)")
        lines.append(";; 로케일·시간대·로깅 데몬. 좁히면 툴체인이 여기저기서 조용히 어긋난다.")
        lines.append("(allow mach-lookup)")
        lines.append(";; POSIX 공유메모리·세마포어 — Python multiprocessing 이 없으면 못 돈다.")
        lines.append("(allow ipc-posix-shm)")
        lines.append("(allow ipc-posix-sem)")
        lines.append("")

        lines.append(";; --- 읽기: 관대 ---")
        lines.append(";; SDK·모듈 캐시·/usr/lib·툴체인 리소스를 광범위하게 읽어야 컴파일러가 산다.")
        lines.append(";; 좁히려던 시도는 전부 '툴체인 업데이트마다 깨지는 목록'으로 끝난다.")
        lines.append("(allow file-read*)")
        lines.append("")

        lines.append(";; --- 쓰기: 워크스페이스와 실행 전용 TMPDIR 만 ---")
        lines.append("(allow file-write*")
        lines.append("  (subpath (param \"\(Self.workspaceParameter)\"))")
        lines.append("  (subpath (param \"\(Self.temporaryDirectoryParameter)\")))")
        lines.append(";; 출력 폐기와 dtrace 헬퍼 초기화. 디렉터리가 아니라 개별 노드만 연다.")
        lines.append("(allow file-write-data")
        lines.append("  (literal \"/dev/null\")")
        lines.append("  (literal \"/dev/zero\")")
        lines.append("  (literal \"/dev/random\")")
        lines.append("  (literal \"/dev/urandom\")")
        lines.append("  (literal \"/dev/dtracehelper\"))")
        lines.append("(allow file-ioctl")
        lines.append("  (literal \"/dev/null\")")
        lines.append("  (literal \"/dev/zero\")")
        lines.append("  (literal \"/dev/dtracehelper\"))")
        lines.append("")

        lines.append(";; --- 민감 경로: 명시적 거부 ---")
        lines.append(";; SBPL 은 마지막 매치가 이긴다. 이 블록이 위의 allow 들보다 뒤에 있어야")
        lines.append(";; 'read 관대'가 비밀까지 열어 주지 않는다.")
        let deniedFilters =
            deniedHomeSubpaths.map { "  (subpath \(Self.homeRelative($0)))" }
            + deniedHomeFiles.map { "  (literal \(Self.homeRelative($0)))" }
            + deniedAbsoluteSubpaths.map { path in
                let literal = (try? Self.sbplStringLiteral(path)) ?? "\"/__invalid__\""
                return "  (subpath \(literal))"
            }
        if deniedFilters.isEmpty {
            lines.append(";; (거부 목록이 비어 있다)")
        } else {
            lines.append("(deny file-read* file-write*")
            lines.append(deniedFilters.joined(separator: "\n") + ")")
        }
        lines.append("")

        lines.append(";; --- 네트워크 전면 차단 ---")
        lines.append(";; 아웃바운드·인바운드·바인드·유닉스 도메인 소켓까지 전부.")
        lines.append(";; 레슨 코드가 네트워크를 쓸 이유가 없고, 열어 두면 채점의 재현성이 사라진다.")
        lines.append("(deny network*)")

        return lines.joined(separator: "\n") + "\n"
    }
}
