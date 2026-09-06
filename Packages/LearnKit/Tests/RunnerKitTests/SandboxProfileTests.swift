import Testing
import Foundation
import LanguageKit
@testable import RunnerKit

/// 프로세스를 하나도 띄우지 않는 프로파일 조립 규칙.
@Suite("샌드박스 프로파일 조립")
struct SandboxProfileTests {
    /// 매 테스트가 자기 디렉터리를 만든다. `realpath` 가 통과하려면 실재해야 한다.
    static func makeDirectory(_ name: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-sandbox-tests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeProfile(
        workspaceName: String = "ws",
        deniedAbsoluteSubpaths: [String] = SandboxProfile.defaultDeniedAbsoluteSubpaths
    ) throws -> (profile: SandboxProfile, workspace: URL, temporary: URL) {
        let workspace = try makeDirectory(workspaceName)
        let temporary = workspace.appendingPathComponent(".tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        let profile = try SandboxProfile(
            workspaceRoot: workspace,
            temporaryDirectory: temporary,
            deniedAbsoluteSubpaths: deniedAbsoluteSubpaths
        )
        return (profile, workspace, temporary)
    }

    @Test("경로는 realpath 를 거쳐 저장된다 — 규칙은 심링크가 풀린 형태여야 매치한다")
    func resolvesSymlinks() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        // macOS 의 임시 디렉터리는 /var → /private/var 심링크 밑에 있다.
        #expect(profile.workspaceRoot.hasPrefix("/private/"))
        #expect(!profile.workspaceRoot.hasPrefix("/var/"))
        // Foundation 의 `resolvingSymlinksInPath` 는 realpath 가 아니다 — /var 를 풀어 주지
        // 않고 오히려 /private 접두사를 떼어 낸다. 프로파일이 realpath(3) 를 쓰는 이유다.
        #expect(profile.workspaceRoot == (try SandboxPath.resolve(workspace)))
        #expect((workspace.path as NSString).resolvingSymlinksInPath != profile.workspaceRoot)
    }

    @Test("존재하지 않는 경로는 조립 단계에서 거부된다")
    func rejectsMissingPath() throws {
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")
        #expect(throws: SandboxProfileError.self) {
            _ = try SandboxProfile(workspaceRoot: missing, temporaryDirectory: missing)
        }
    }

    @Test("워크스페이스 경로는 SBPL 텍스트에 등장하지 않는다 — 인젝션 표면 자체를 없앤다")
    func pathNeverEntersProfileText() throws {
        // 따옴표·개행·괄호·SBPL 토큰이 전부 섞인 이름.
        let hostile = "ev \"il\n)(allow default)(subpath \"/"
        let parent = try Self.makeDirectory("hostile")
        defer { try? FileManager.default.removeItem(at: parent) }
        let workspace = parent.appendingPathComponent(hostile, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let profile = try SandboxProfile(workspaceRoot: workspace, temporaryDirectory: workspace)

        #expect(!profile.source.contains(profile.workspaceRoot))
        #expect(!profile.source.contains("allow default"))
        // 경로는 오직 -D 값으로만 나간다.
        #expect(profile.parameterArguments.contains("\(SandboxProfile.workspaceParameter)=\(profile.workspaceRoot)"))
    }

    @Test("홈 경로도 텍스트에 박히지 않고 param 으로만 참조된다")
    func homeGoesThroughParameter() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        #expect(!profile.source.contains(profile.homeDirectory))
        #expect(profile.source.contains("(param \"\(SandboxProfile.homeParameter)\")"))
        #expect(profile.parameterArguments.contains("\(SandboxProfile.homeParameter)=\(profile.homeDirectory)"))
    }

    @Test("규칙 순서 — 읽기 허용보다 민감 경로 거부가 뒤에 와야 비밀이 닫힌다")
    func denyRulesComeLast() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = profile.source

        let denyDefault = try #require(source.range(of: "(deny default)"))
        let allowRead = try #require(source.range(of: "(allow file-read*)"))
        let allowWrite = try #require(source.range(of: "(allow file-write*\n"))
        let denySecrets = try #require(source.range(of: "(deny file-read* file-write*"))
        let denyNetwork = try #require(source.range(of: "(deny network*)"))

        #expect(denyDefault.lowerBound < allowRead.lowerBound)
        #expect(allowRead.lowerBound < allowWrite.lowerBound)
        // SBPL 은 마지막 매치가 이긴다 — 이 순서가 깨지면 read 관대가 비밀까지 연다.
        #expect(allowWrite.lowerBound < denySecrets.lowerBound)
        #expect(denySecrets.lowerBound < denyNetwork.lowerBound)
    }

    @Test("쓰기는 두 param 에만 열린다")
    func writeRulesAreLimitedToTwoRoots() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = profile.source

        #expect(source.contains("(subpath (param \"\(SandboxProfile.workspaceParameter)\"))"))
        #expect(source.contains("(subpath (param \"\(SandboxProfile.temporaryDirectoryParameter)\"))"))
        // 쓰기가 열리는 디렉터리는 이 둘뿐 — 나머지 file-write* 허용은 /dev 노드 리터럴이다.
        #expect(source.components(separatedBy: "(subpath (param").count - 1 == 2)
        #expect(!source.contains("(allow file-write* (subpath \"/"))
    }

    @Test("기본 거부 목록에 ssh·aws·gnupg·키체인이 들어 있다")
    func defaultDenyListCoversSecrets() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = profile.source

        for expected in ["/.ssh", "/.aws", "/.gnupg", "/Library/Keychains", "/.netrc"] {
            #expect(source.contains("\"\(expected)\""), "거부 목록에 \(expected) 가 없다")
        }
    }

    @Test("거부 경로의 따옴표와 역슬래시는 SBPL 리터럴로 이스케이프된다")
    func escapesDenyPaths() throws {
        let escaped = try SandboxProfile.sbplStringLiteral(#"/a"b\c"#)
        #expect(escaped == #""/a\"b\\c""#)
    }

    @Test("제어문자가 든 거부 경로는 이스케이프하지 않고 거부한다")
    func rejectsControlCharactersInDenyList() throws {
        #expect(throws: SandboxProfileError.self) {
            _ = try SandboxProfile.sbplStringLiteral("/a\nb")
        }
        let workspace = try Self.makeDirectory("ctrl")
        defer { try? FileManager.default.removeItem(at: workspace) }
        #expect(throws: SandboxProfileError.self) {
            _ = try SandboxProfile(
                workspaceRoot: workspace,
                temporaryDirectory: workspace,
                deniedAbsoluteSubpaths: ["/secret\u{7}dir"]
            )
        }
    }

    @Test("TMPDIR 환경 덮어쓰기는 슬래시로 끝난다")
    func temporaryDirectoryOverrideEndsWithSlash() throws {
        let (profile, workspace, temporary) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let override = try #require(profile.environmentOverrides["TMPDIR"])
        #expect(override.hasSuffix("/"))
        #expect(override == (try SandboxPath.resolve(temporary)) + "/")
    }

    @Test("swiftc 모듈 캐시는 워크스페이스 안을 가리킨다")
    func moduleCacheStaysInsideWorkspace() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        #expect(profile.swiftModuleCachePath.hasPrefix(profile.workspaceRoot + "/"))
        #expect(profile.swiftModuleCacheArguments == ["-module-cache-path", profile.swiftModuleCachePath])
    }

    @Test("argumentPrefix 는 -p 로 프로파일을 싣고 -- 로 끝난다 — 임시 파일을 만들지 않는다")
    func argumentPrefixCarriesProfileInline() throws {
        let (profile, workspace, _) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let prefix = profile.argumentPrefix

        #expect(prefix.last == "--")
        let profileIndex = try #require(prefix.firstIndex(of: "-p"))
        #expect(prefix[prefix.index(after: profileIndex)] == profile.source)
        #expect(prefix.filter { $0 == "-D" }.count == 3)
    }
}

/// 런처 호출에 샌드박스를 끼우는 argv 조립.
@Suite("샌드박스 체인 argv")
struct SandboxedInvocationTests {
    static func makeInvocation() -> LauncherInvocation {
        LauncherInvocation(
            launcherPath: "/opt/learn/learn-launcher",
            executablePath: "/usr/bin/python3",
            arguments: ["main.py", "--flag"],
            workingDirectory: "/work",
            limits: ResourceLimits(wallClockSeconds: 7, cpuSeconds: 3, maxProcesses: 12),
            statusFileDescriptor: 3
        )
    }

    @Test("wrap 은 sandbox-exec 를 앞단에 두고 원래 프로그램을 뒤로 민다")
    func wrapsExecutable() throws {
        let (profile, workspace, _) = try SandboxProfileTests.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let wrapped = SandboxedInvocation.wrap(Self.makeInvocation(), profile: profile)
        #expect(wrapped.executablePath == SandboxProfile.executablePath)
        #expect(wrapped.arguments.last == "--flag")
        let separator = try #require(wrapped.arguments.firstIndex(of: "--"))
        #expect(wrapped.arguments[wrapped.arguments.index(after: separator)] == "/usr/bin/python3")
    }

    @Test("rlimit·cwd·status fd 는 체인 후에도 런처 인자로 남는다")
    func preservesLauncherContract() throws {
        let (profile, workspace, _) = try SandboxProfileTests.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let wrapped = SandboxedInvocation.wrap(Self.makeInvocation(), profile: profile)
        let argv = wrapped.argumentVector

        // 런처 자신의 인자는 첫 `--` 앞에 전부 있어야 한다.
        let separator = try #require(argv.firstIndex(of: "--"))
        let launcherArguments = Array(argv[..<separator])
        #expect(launcherArguments.contains("--cpu"))
        #expect(launcherArguments.contains("3"))
        #expect(launcherArguments.contains("--wall"))
        #expect(launcherArguments.contains("7"))
        #expect(launcherArguments.contains("--nproc"))
        #expect(launcherArguments.contains("--status-fd"))
        #expect(launcherArguments.contains("--cwd"))
        #expect(launcherArguments.contains("/work"))
        #expect(argv[argv.index(after: separator)] == SandboxProfile.executablePath)
        #expect(wrapped.limits == Self.makeInvocation().limits)
        #expect(wrapped.statusFileDescriptor == 3)
    }

    @Test("강등된 판정은 호출을 그대로 통과시킨다")
    func degradedDecisionLeavesInvocationAlone() {
        let original = Self.makeInvocation()
        let decision = SandboxDecision.degraded(SandboxDegradation(.executableMissing(path: "/nope")))
        #expect(SandboxedInvocation.apply(decision, to: original) == original)
    }

    @Test("sandbox-exec 자신의 실패는 종료코드와 stderr 접두사를 함께 봐야 판정된다")
    func classifiesSandboxExecFailures() {
        let rejected = SandboxExecFailure.classify(
            exitCode: 65,
            standardError: "sandbox-exec: unbound variable: bogus at <input string>\n"
        )
        #expect(rejected?.kind == .profileRejected)
        #expect(rejected?.message.hasPrefix("unbound variable") == true)

        let execFailed = SandboxExecFailure.classify(
            exitCode: 71,
            standardError: "sandbox-exec: execvp() of '/nope' failed: No such file or directory\n"
        )
        #expect(execFailed?.kind == .executionFailed)

        // 사용자 코드가 우연히 65 로 끝난 것은 샌드박스 실패가 아니다.
        #expect(SandboxExecFailure.classify(exitCode: 65, standardError: "SyntaxError\n") == nil)
        // 접두사가 있어도 종료코드가 다르면 아니다.
        #expect(SandboxExecFailure.classify(exitCode: 0, standardError: "sandbox-exec: hi\n") == nil)
    }

    @Test("/usr/bin 의 xcrun 셰이더에는 주의사항이 붙는다")
    func flagsXcrunShims() {
        #expect(SandboxAdvisory.advisories(forExecutable: "/usr/bin/swiftc")
            == [.xcrunShimTarget(path: "/usr/bin/swiftc")])
        #expect(SandboxAdvisory.advisories(
            forExecutable: "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
        ).isEmpty)
        #expect(SandboxAdvisory.advisories(forExecutable: "/opt/homebrew/bin/python3").isEmpty)
    }
}
