public import LearnCore

/// 툴체인 하나를 어떻게 찾고 어떻게 판정할지.
public struct ToolSpec: Sendable, Hashable, Identifiable {
    public var id: String
    public var language: LanguageID
    public var displayName: String
    /// 찾아볼 실행 파일 이름들. 앞쪽이 선호되지만 **선택은 이름 순서가 아니라 버전 정책이 한다.**
    public var executableNames: [String]
    /// 버전 질의 인자. `go` 는 `--version` 이 아니라 `version` 이다.
    public var versionArguments: [String]
    /// 버전 정규식. 첫 번째로 매치된 캡처 그룹이 버전 문자열이 된다
    /// (캡처가 없으면 매치 전체).
    public var versionPattern: String
    /// 이 버전 미만이면 `.unsupported`.
    public var minimumVersion: ToolVersion?
    /// 출력에 이 조각이 있으면 "파일은 있지만 동작하지 않는 스텁".
    public var stubMarkers: [String]
    /// `xcode-select` 활성 개발자 디렉터리에 의존하는 도구인가.
    ///
    /// 참이면 개발자 디렉터리가 없을 때 `/usr/bin` 아래 후보를 **실행하지 않는다** —
    /// 실행하면 macOS 가 CLT 설치 다이얼로그를 띄운다.
    public var needsDeveloperDirectory: Bool
    /// `xcrun --find <이름>` 으로도 찾아본다.
    public var searchViaXcrun: Bool
    /// PATH·관례 경로 밖의 추가 탐색 디렉터리.
    public var additionalDirectories: [String]
    /// 한 단계 `*` 만 지원하는 디렉터리 패턴. JDK 처럼 버전 디렉터리가 끼는 배치용.
    public var additionalDirectoryPatterns: [String]
    public var installHint: String

    public init(
        id: String,
        language: LanguageID,
        displayName: String,
        executableNames: [String],
        versionArguments: [String] = ["--version"],
        versionPattern: String,
        minimumVersion: ToolVersion? = nil,
        stubMarkers: [String] = ToolSpec.commonStubMarkers,
        needsDeveloperDirectory: Bool = false,
        searchViaXcrun: Bool = false,
        additionalDirectories: [String] = [],
        additionalDirectoryPatterns: [String] = [],
        installHint: String
    ) {
        self.id = id
        self.language = language
        self.displayName = displayName
        self.executableNames = executableNames
        self.versionArguments = versionArguments
        self.versionPattern = versionPattern
        self.minimumVersion = minimumVersion
        self.stubMarkers = stubMarkers
        self.needsDeveloperDirectory = needsDeveloperDirectory
        self.searchViaXcrun = searchViaXcrun
        self.additionalDirectories = additionalDirectories
        self.additionalDirectoryPatterns = additionalDirectoryPatterns
        self.installHint = installHint
    }

    /// 어떤 도구에서든 "파일은 있는데 못 쓴다"는 뜻인 문구들.
    ///
    /// `Unable to locate a Java Runtime` 이 대표 사례다 — `/usr/bin/java` 는 실재하는
    /// 파일이라 `command -v` 는 통과시키지만 실행하면 종료코드 1 로 이 문구를 낸다.
    public static let commonStubMarkers: [String] = [
        "Unable to locate a Java Runtime",
        "no developer tools were found",
        "invalid active developer path",
        "requires the command line developer tools",
        "xcrun: error",
        "command not found",
    ]
}

/// 10 개 트랙의 툴 카탈로그.
public enum ToolchainCatalog {
    public static let python = ToolSpec(
        id: "python3",
        language: LanguageID("python"),
        displayName: "Python",
        // 3.9 는 `/usr/bin`, 3.13 은 conda 쪽 — 둘 다 열거해야 버전 정책이 의미를 갖는다.
        executableNames: ["python3", "python3.14", "python3.13", "python3.12", "python3.11", "python"],
        versionPattern: #"(?i)Python\s+(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: ToolVersion(components: [3, 9]),
        installHint: "brew install python@3.13"
    )

    public static let sqlite = ToolSpec(
        id: "sqlite3",
        language: LanguageID("sql"),
        displayName: "SQLite",
        executableNames: ["sqlite3"],
        versionPattern: #"^\s*(\d+\.\d+\.\d+)"#,
        minimumVersion: ToolVersion(components: [3, 35]),
        installHint: "brew install sqlite"
    )

    public static let swift = ToolSpec(
        id: "swiftc",
        language: LanguageID("swift"),
        displayName: "Swift",
        executableNames: ["swiftc"],
        versionPattern: #"(?i)Swift\s+version\s+(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: ToolVersion(components: [5, 9]),
        needsDeveloperDirectory: true,
        searchViaXcrun: true,
        additionalDirectories: [
            "/Library/Developer/CommandLineTools/usr/bin",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin",
        ],
        additionalDirectoryPatterns: ["/Library/Developer/Toolchains/*/usr/bin"],
        installHint: "xcode-select --install (또는 Xcode 설치 후 xcode-select -s)"
    )

    public static let rust = ToolSpec(
        id: "rustc",
        language: LanguageID("rust"),
        displayName: "Rust",
        executableNames: ["rustc"],
        versionPattern: #"(?i)rustc\s+(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: ToolVersion(components: [1, 70]),
        installHint: "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    )

    public static let cpp = ToolSpec(
        id: "clang++",
        language: LanguageID("cpp"),
        displayName: "C++",
        executableNames: ["clang++", "g++"],
        versionPattern: #"(?i)clang version (\d+\.\d+(?:\.\d+)?)|\(.*?gcc.*?\)\s+(\d+\.\d+\.\d+)"#,
        minimumVersion: ToolVersion(components: [14]),
        needsDeveloperDirectory: true,
        searchViaXcrun: true,
        additionalDirectories: ["/Library/Developer/CommandLineTools/usr/bin"],
        installHint: "xcode-select --install"
    )

    public static let go = ToolSpec(
        id: "go",
        language: LanguageID("go"),
        displayName: "Go",
        executableNames: ["go"],
        // `go --version` 은 에러다. 하위 명령이어야 한다.
        versionArguments: ["version"],
        versionPattern: #"(?i)go\s+version\s+go(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: ToolVersion(components: [1, 21]),
        installHint: "brew install go"
    )

    public static let java = ToolSpec(
        id: "javac",
        language: LanguageID("java"),
        displayName: "Java",
        // `java` 도 같이 열거해 CLT 스텁이 어디에 있는지 진단에 남긴다.
        executableNames: ["javac", "java"],
        versionPattern: #"(?i)(?:javac|openjdk|java)\s+(?:version\s+)?"?(\d+(?:\.\d+)*)"#,
        minimumVersion: ToolVersion(components: [17]),
        additionalDirectoryPatterns: [
            "/Library/Java/JavaVirtualMachines/*/Contents/Home/bin",
            "~/.sdkman/candidates/java/*/bin",
        ],
        installHint: "brew install --cask temurin"
    )

    public static let typescript = ToolSpec(
        id: "tsc",
        language: LanguageID("typescript"),
        displayName: "TypeScript",
        executableNames: ["tsc"],
        versionPattern: #"(?i)Version\s+(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: ToolVersion(components: [5, 0]),
        installHint: "npm install -g typescript"
    )

    public static let node = ToolSpec(
        id: "node",
        language: LanguageID("nextjs"),
        displayName: "Node.js",
        executableNames: ["node"],
        versionPattern: #"v?(\d+\.\d+\.\d+)"#,
        minimumVersion: ToolVersion(components: [18]),
        installHint: "brew install node"
    )

    public static let assembler = ToolSpec(
        id: "as",
        language: LanguageID("assembly"),
        displayName: "Assembler",
        executableNames: ["as", "nasm"],
        versionPattern: #"(?i)version\s+(\d+\.\d+(?:\.\d+)?)"#,
        minimumVersion: nil,
        needsDeveloperDirectory: true,
        searchViaXcrun: true,
        additionalDirectories: ["/Library/Developer/CommandLineTools/usr/bin"],
        installHint: "xcode-select --install"
    )

    /// 카탈로그 순서 = 온보딩 화면에 보여줄 순서. MVP 3종이 앞이다.
    public static let all: [ToolSpec] = [
        python, sqlite, swift,
        rust, cpp, go, java, typescript, node, assembler,
    ]

    public static func spec(id: String) -> ToolSpec? {
        all.first { $0.id == id }
    }
}
