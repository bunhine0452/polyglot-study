import Testing
import Foundation
import Darwin
import LanguageKit
@testable import RunnerKit

/// 프로파일을 **실제로 커널에 걸어** 확인한다.
///
/// 여기 있는 것 중 모킹으로 대체 가능한 건 하나도 없다. "네트워크가 막혔다"를 아는 방법은
/// 연결을 시도해 보는 것뿐이고, "쓰기가 워크스페이스로 한정됐다"를 아는 방법은
/// 밖에다 써 보는 것뿐이다.
@Suite("샌드박스 실측", .serialized)
struct SandboxProcessTests {
    static let python = "/usr/bin/python3"

    struct Fixture {
        var profile: SandboxProfile
        var workspace: URL
        var temporary: URL
        var container: URL

        func remove() { try? FileManager.default.removeItem(at: container) }

        /// 워크스페이스 안에 파이썬 스크립트를 놓고 절대경로를 돌려준다.
        func script(_ name: String, _ body: String) throws -> String {
            let url = workspace.appendingPathComponent(name)
            try body.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        }
    }

    static func makeFixture(
        deniedAbsoluteSubpaths: [String] = SandboxProfile.defaultDeniedAbsoluteSubpaths,
        workspaceName: String = "run"
    ) throws -> Fixture {
        let container = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-sandbox-process", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent(workspaceName, isDirectory: true)
        let temporary = workspace.appendingPathComponent(".tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        let profile = try SandboxProfile(
            workspaceRoot: workspace,
            temporaryDirectory: temporary,
            deniedAbsoluteSubpaths: deniedAbsoluteSubpaths
        )
        return Fixture(profile: profile, workspace: workspace, temporary: temporary, container: container)
    }

    /// 런처 없이 `sandbox-exec` 만 걸고 돌린다 — 프로파일 자체를 보는 테스트용.
    static func runSandboxed(
        _ fixture: Fixture,
        executable: String,
        arguments: [String],
        timeout: Duration = .seconds(60)
    ) async -> BoundedCommandResult {
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in fixture.profile.environmentOverrides { environment[key] = value }
        return await BoundedCommand.run(
            executable: SandboxProfile.executablePath,
            arguments: fixture.profile.argumentPrefix + [executable] + arguments,
            environment: environment,
            workingDirectory: fixture.workspace.path,
            timeout: timeout
        )
    }

    static func requireTools() throws {
        try #require(FileManager.default.isExecutableFile(atPath: SandboxProfile.executablePath))
        try #require(FileManager.default.isExecutableFile(atPath: python))
    }

    // MARK: - 툴체인이 프로파일 하에서 살아 있는가

    @Test("python3 가 프로파일 하에서 정상 실행된다")
    func pythonRuns() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let script = try fixture.script("hello.py", """
        import json, re, sqlite3, threading
        rows = sqlite3.connect(":memory:").execute("select 1 + 1").fetchone()
        box = []
        thread = threading.Thread(target=lambda: box.append(re.findall(r"\\d+", "a12b")))
        thread.start(); thread.join()
        print(json.dumps({"sum": rows[0], "re": box[0]}))
        """)

        let result = await Self.runSandboxed(fixture, executable: Self.python, arguments: [script])
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("\"sum\": 2"))
        #expect(result.standardOutput.contains("\"12\""))
    }

    @Test("multiprocessing 도 돈다 — POSIX 세마포어를 막으면 여기서 깨진다")
    func pythonMultiprocessingRuns() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let script = try fixture.script("mp.py", """
        import multiprocessing as mp
        mp.set_start_method("fork")
        with mp.Pool(2) as pool:
            print("MP", pool.map(abs, [-3, -4]))
        """)
        let result = await Self.runSandboxed(fixture, executable: Self.python, arguments: [script])
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("MP [3, 4]"))
    }

    @Test("swiftc 가 프로파일 하에서 컴파일하고, 산출물이 다시 프로파일 하에서 돈다")
    func swiftCompilesAndRuns() async throws {
        try Self.requireTools()
        // 셰이더가 아니라 해석된 실제 컴파일러를 쓴다 — SandboxAdvisory.xcrunShimTarget 참고.
        let found = await BoundedCommand.run(
            executable: "/usr/bin/xcrun",
            arguments: ["--find", "swiftc"],
            timeout: .seconds(10)
        )
        try #require(found.succeeded, "xcrun --find swiftc 실패: \(found.combinedOutput)")
        let swiftc = found.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        try #require(FileManager.default.isExecutableFile(atPath: swiftc))

        let sdkResult = await BoundedCommand.run(
            executable: "/usr/bin/xcrun",
            arguments: ["--show-sdk-path"],
            timeout: .seconds(10)
        )
        try #require(sdkResult.succeeded)
        let sdk = sdkResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        let fixture = try Self.makeFixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            atPath: fixture.profile.swiftModuleCachePath,
            withIntermediateDirectories: true
        )

        let source = try fixture.script("main.swift", """
        import Foundation
        let parts = ["swift", "sandbox", "ok"]
        print(parts.joined(separator: " "), [3, 1, 2].sorted())
        """)
        let binary = fixture.workspace.appendingPathComponent("prog").path

        let compile = await Self.runSandboxed(
            fixture,
            executable: swiftc,
            arguments: ["-sdk", sdk] + fixture.profile.swiftModuleCacheArguments + ["-o", binary, source],
            timeout: .seconds(180)
        )
        #expect(compile.exitCode == 0, "컴파일 실패: \(compile.combinedOutput)")
        // 해석된 컴파일러를 쓰면 xcrun 캐시 잡음이 없어야 한다.
        #expect(!compile.standardError.contains(SandboxAdvisory.xcrunCacheDenialMarker))
        #expect(FileManager.default.isExecutableFile(atPath: binary))
        // 모듈 캐시가 워크스페이스 안에 실제로 쌓였다.
        let cached = (try? FileManager.default.contentsOfDirectory(atPath: fixture.profile.swiftModuleCachePath)) ?? []
        #expect(!cached.isEmpty)

        let run = await Self.runSandboxed(fixture, executable: binary, arguments: [], timeout: .seconds(60))
        #expect(run.exitCode == 0, "stderr: \(run.standardError)")
        #expect(run.standardOutput.contains("swift sandbox ok [1, 2, 3]"))
    }

    @Test("컴파일 진단은 샌드박스 안에서도 그대로 나온다")
    func swiftDiagnosticsSurvive() async throws {
        try Self.requireTools()
        let found = await BoundedCommand.run(
            executable: "/usr/bin/xcrun", arguments: ["--find", "swiftc"], timeout: .seconds(10)
        )
        try #require(found.succeeded)
        let swiftc = found.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let sdkResult = await BoundedCommand.run(
            executable: "/usr/bin/xcrun", arguments: ["--show-sdk-path"], timeout: .seconds(10)
        )
        try #require(sdkResult.succeeded)
        let sdk = sdkResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        let fixture = try Self.makeFixture()
        defer { fixture.remove() }
        let source = try fixture.script("bad.swift", "let x: Int = \"nope\"\n")

        let compile = await Self.runSandboxed(
            fixture,
            executable: swiftc,
            arguments: ["-sdk", sdk, "-diagnostic-style", "llvm", "-no-color-diagnostics",
                        "-o", fixture.workspace.appendingPathComponent("bad").path, source],
            timeout: .seconds(180)
        )
        #expect(compile.exitCode != 0)
        #expect(compile.standardError.contains("bad.swift:1:14: error:"))
    }

    // MARK: - 네트워크

    @Test("아웃바운드 연결만 실패하고 나머지는 그대로 돈다")
    func outboundNetworkIsBlocked() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let script = try fixture.script("net.py", """
        import socket
        print("ALIVE")
        sock = socket.socket(); sock.settimeout(5)
        try:
            sock.connect(("1.1.1.1", 80)); print("CONNECTED")
        except OSError as error:
            print("CONNECT_DENIED", error.errno)
        try:
            print("DNS", socket.gethostbyname("example.com"))
        except OSError:
            print("DNS_DENIED")
        listener = socket.socket()
        try:
            listener.bind(("127.0.0.1", 0)); listener.listen(1); print("LISTENING")
        except OSError:
            print("BIND_DENIED")
        left, right = socket.socketpair()
        left.send(b"x"); print("SOCKETPAIR", right.recv(1).decode())
        """)

        let result = await Self.runSandboxed(fixture, executable: Self.python, arguments: [script])
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("ALIVE"))
        #expect(result.standardOutput.contains("CONNECT_DENIED 1"))  // EPERM
        #expect(result.standardOutput.contains("DNS_DENIED"))
        #expect(result.standardOutput.contains("BIND_DENIED"))
        #expect(!result.standardOutput.contains("CONNECTED"))
        #expect(!result.standardOutput.contains("LISTENING"))
        // socketpair 는 파일시스템·네트워크 스택을 타지 않으므로 살아 있어야 한다.
        #expect(result.standardOutput.contains("SOCKETPAIR x"))
    }

    // MARK: - 쓰기 경계

    @Test("쓰기는 워크스페이스와 TMPDIR 안에서만 성공한다")
    func writesAreConfined() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let outside = fixture.container.appendingPathComponent("escape.txt").path
        let home = (NSHomeDirectory() as NSString).appendingPathComponent("learnkit-should-never-exist.txt")
        let script = try fixture.script("write.py", """
        import os, sys, tempfile
        for target in sys.argv[1:]:
            try:
                open(target, "w").write("x")
                print("WROTE", target)
            except OSError:
                print("DENIED", target)
        handle = tempfile.NamedTemporaryFile(delete=False)
        handle.write(b"x"); handle.close()
        print("TMP", handle.name)
        """)

        let inside = fixture.workspace.appendingPathComponent("inside.txt").path
        let result = await Self.runSandboxed(
            fixture,
            executable: Self.python,
            arguments: [script, inside, outside, home, "/etc/learnkit-nope"]
        )
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("WROTE \(inside)"))
        #expect(result.standardOutput.contains("DENIED \(outside)"))
        #expect(result.standardOutput.contains("DENIED \(home)"))
        #expect(result.standardOutput.contains("DENIED /etc/learnkit-nope"))
        // TMPDIR 은 실행 전용 디렉터리로 돌려놨으므로 mkstemp 계열이 살아 있어야 한다.
        #expect(result.standardOutput.contains("TMP \(fixture.profile.temporaryDirectory)/"))
        #expect(!FileManager.default.fileExists(atPath: outside))
        #expect(!FileManager.default.fileExists(atPath: home))
    }

    @Test("규칙은 realpath 로 걸지만 대상은 심링크 경로여도 통과한다")
    func ruleNeedsResolvedPathButTargetDoesNot() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        // /var/folders/... (심링크 경유) 와 /private/var/folders/... 둘 다 같은 파일이다.
        let unresolved = fixture.workspace.path
        let resolved = fixture.profile.workspaceRoot
        try #require(unresolved != resolved, "임시 디렉터리가 심링크를 타지 않아 이 테스트는 무의미하다")

        let script = try fixture.script("both.py", """
        import sys
        for target in sys.argv[1:]:
            try:
                open(target, "w").write("x"); print("WROTE")
            except OSError:
                print("DENIED")
        """)
        let result = await Self.runSandboxed(
            fixture,
            executable: Self.python,
            arguments: [script, unresolved + "/a.txt", resolved + "/b.txt"]
        )
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.split(separator: "\n").allSatisfy { $0 == "WROTE" })
    }

    // MARK: - 민감 경로

    @Test("~/.ssh 읽기가 거부된다")
    func homeSecretsAreDenied() async throws {
        try Self.requireTools()
        let sshPath = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh")
        try #require(FileManager.default.fileExists(atPath: sshPath), "이 머신에 ~/.ssh 가 없어 검증할 수 없다")

        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let script = try fixture.script("secrets.py", """
        import errno, os, sys
        for target in sys.argv[1:]:
            try:
                os.listdir(target)
                print("READ", target)
            except PermissionError:
                print("DENIED", target)
            except FileNotFoundError:
                print("ABSENT", target)
        """)
        let keychains = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Keychains")
        let result = await Self.runSandboxed(
            fixture,
            executable: Self.python,
            arguments: [script, sshPath, keychains]
        )
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("DENIED \(sshPath)"))
        #expect(!result.standardOutput.contains("READ \(sshPath)"))
        if FileManager.default.fileExists(atPath: keychains) {
            #expect(result.standardOutput.contains("DENIED \(keychains)"))
        }
    }

    @Test("거부 목록에 추가한 임의 경로도 읽기가 막힌다")
    func customDenyListIsEnforced() async throws {
        try Self.requireTools()
        // 사용자 홈을 건드리지 않고 거부 메커니즘 자체를 검증한다.
        let secretDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-secret-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: secretDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: secretDirectory) }
        let secretFile = secretDirectory.appendingPathComponent("token.txt")
        try "s3cret".write(to: secretFile, atomically: true, encoding: .utf8)
        let resolvedSecret = try SandboxPath.resolve(secretDirectory)

        let fixture = try Self.makeFixture(deniedAbsoluteSubpaths: [resolvedSecret])
        defer { fixture.remove() }

        let script = try fixture.script("read.py", """
        import sys
        try:
            print("READ", open(sys.argv[1]).read())
        except PermissionError:
            print("DENIED")
        """)
        let result = await Self.runSandboxed(
            fixture,
            executable: Self.python,
            arguments: [script, secretFile.path]
        )
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("DENIED"))
        #expect(!result.standardOutput.contains("s3cret"))
    }

    @Test("읽기는 관대하다 — /etc·/usr·SDK 는 그대로 열려 있다")
    func readsStayPermissive() async throws {
        try Self.requireTools()
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let script = try fixture.script("read_wide.py", """
        import os
        print("HOSTS", len(open("/etc/hosts").read()) > 0)
        print("USRBIN", len(os.listdir("/usr/bin")) > 10)
        print("USRLIB", os.path.isdir("/usr/lib"))
        """)
        let result = await Self.runSandboxed(fixture, executable: Self.python, arguments: [script])
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("HOSTS True"))
        #expect(result.standardOutput.contains("USRBIN True"))
        #expect(result.standardOutput.contains("USRLIB True"))
    }

    // MARK: - 인젝션

    @Test("따옴표·개행·SBPL 토큰이 섞인 워크스페이스 경로로도 샌드박스가 열리지 않는다")
    func hostileWorkspacePathCannotOpenTheSandbox() async throws {
        try Self.requireTools()
        let container = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-sandbox-process", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let hostile = container.appendingPathComponent("ev \"il\n)(allow default)(subpath \"/", isDirectory: true)
        let temporary = hostile.appendingPathComponent(".tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }

        let profile = try SandboxProfile(workspaceRoot: hostile, temporaryDirectory: temporary)
        let fixture = Fixture(profile: profile, workspace: hostile, temporary: temporary, container: container)

        let outside = container.appendingPathComponent("escape.txt").path
        let script = try fixture.script("evil.py", """
        import socket, sys
        try:
            open(sys.argv[1], "w").write("x"); print("WROTE_INSIDE")
        except OSError:
            print("INSIDE_DENIED")
        try:
            open(sys.argv[2], "w").write("x"); print("ESCAPED")
        except OSError:
            print("ESCAPE_DENIED")
        sock = socket.socket(); sock.settimeout(3)
        try:
            sock.connect(("1.1.1.1", 80)); print("CONNECTED")
        except OSError:
            print("NET_DENIED")
        """)
        let result = await Self.runSandboxed(
            fixture,
            executable: Self.python,
            arguments: [script, hostile.appendingPathComponent("inside.txt").path, outside]
        )
        #expect(result.exitCode == 0, "stderr: \(result.standardError)")
        #expect(result.standardOutput.contains("WROTE_INSIDE"))
        #expect(result.standardOutput.contains("ESCAPE_DENIED"))
        #expect(result.standardOutput.contains("NET_DENIED"))
        #expect(!result.standardOutput.contains("ESCAPED"))
        #expect(!result.standardOutput.contains("CONNECTED"))
    }

    // MARK: - 강등 관측

    @Test("진짜 sandbox-exec 는 망가진 프로파일을 65 로 거부하고, 그걸 분류할 수 있다")
    func brokenProfileIsObservable() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: SandboxProfile.executablePath))
        let result = await BoundedCommand.run(
            executable: SandboxProfile.executablePath,
            arguments: ["-p", "(version 1)(allow learnkit-not-an-operation)", "/usr/bin/true"],
            timeout: .seconds(10)
        )
        #expect(result.exitCode == SandboxExecFailure.profileRejectedExitCode)
        let failure = try #require(
            SandboxExecFailure.classify(exitCode: result.exitCode, standardError: result.standardError)
        )
        #expect(failure.kind == .profileRejected)
    }
}

/// 런처 → `sandbox-exec` → 사용자 코드 체인. 격리가 **둘 다** 살아 있는지 본다.
@Suite("런처 + 샌드박스 체인 실측", .serialized)
struct SandboxLauncherChainTests {
    static func makeFixture() throws -> SandboxProcessTests.Fixture {
        try SandboxProcessTests.makeFixture()
    }

    static func chained(
        program: String,
        arguments: [String] = [],
        profile: SandboxProfile,
        cpuSeconds: Int = 0,
        wallClockSeconds: Int = 0,
        maxProcesses: Int = 0,
        fileSizeBytes: Int = 0,
        workingDirectory: String? = nil
    ) throws -> LauncherInvocation {
        let base = try ToolchainLauncherHarness.invocation(
            program: program,
            arguments: arguments,
            cpuSeconds: cpuSeconds,
            wallClockSeconds: wallClockSeconds,
            maxProcesses: maxProcesses,
            fileSizeBytes: fileSizeBytes,
            workingDirectory: workingDirectory
        )
        return SandboxedInvocation.wrap(base, profile: profile)
    }

    @Test("종료코드는 체인을 지나도 그대로 전달된다")
    func exitCodeStaysTransparent() throws {
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: "/bin/sh", arguments: ["-c", "exit 7"],
                         profile: fixture.profile, wallClockSeconds: 30)
        )
        #expect(run.outcome.termination == .exited(code: 7))
        #expect(run.launcherExitCode == 7)
    }

    @Test("자식은 여전히 새 세션의 프로세스 그룹 리더다 — sandbox-exec 는 같은 프로세스에서 exec 한다")
    func setsidSurvivesTheChain() throws {
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: "/bin/echo", arguments: ["x"], profile: fixture.profile, wallClockSeconds: 30)
        )
        #expect(run.outcome.processIdentifier != nil)
        #expect(run.outcome.processGroup == run.outcome.processIdentifier)
        #expect(run.outcome.processGroup != getpgrp())
        #expect(run.standardOutput == "x\n")
    }

    @Test("--cpu 상한은 체인 후에도 SIGXCPU 로 걸린다")
    func cpuLimitSurvivesTheChain() throws {
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: "/bin/sh", arguments: ["-c", "while :; do :; done"],
                         profile: fixture.profile, cpuSeconds: 1, wallClockSeconds: 30)
        )
        #expect(run.outcome.termination == .signalled(number: SIGXCPU))
        #expect(run.outcome.cpuExceeded)
        #expect(!run.outcome.wallClockExceeded)
        #expect(run.elapsed < .seconds(10))
    }

    @Test("--wall 초과는 체인 후에도 프로세스 그룹째 정리한다")
    func wallClockKillSurvivesTheChain() throws {
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: "/bin/sh", arguments: ["-c", "sleep 120 & echo $!; sleep 120"],
                         profile: fixture.profile, wallClockSeconds: 2)
        )
        #expect(run.outcome.wallClockExceeded)
        #expect(run.outcome.termination == .signalled(number: SIGKILL))
        #expect(run.elapsed < .seconds(6))

        let grandchild = try #require(Int32(run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
        let group = try #require(run.outcome.processGroup)
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(group))
        #expect(!ToolchainLauncherHarness.processExists(grandchild))
    }

    @Test("체인 전체에서 네트워크와 워크스페이스 밖 쓰기가 동시에 막힌다")
    func sandboxRulesApplyThroughTheChain() throws {
        try #require(FileManager.default.isExecutableFile(atPath: SandboxProcessTests.python))
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let outside = fixture.container.appendingPathComponent("chain-escape.txt").path
        let script = try fixture.script("chain.py", """
        import socket, sys
        try:
            open(sys.argv[1], "w").write("x"); print("ESCAPED")
        except OSError:
            print("ESCAPE_DENIED")
        sock = socket.socket(); sock.settimeout(3)
        try:
            sock.connect(("1.1.1.1", 80)); print("CONNECTED")
        except OSError:
            print("NET_DENIED")
        """)

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: SandboxProcessTests.python, arguments: [script, outside],
                         profile: fixture.profile, cpuSeconds: 10, wallClockSeconds: 30,
                         workingDirectory: fixture.workspace.path)
        )
        #expect(run.outcome.termination == .exited(code: 0), "stderr: \(run.standardError)")
        #expect(run.standardOutput.contains("ESCAPE_DENIED"))
        #expect(run.standardOutput.contains("NET_DENIED"))
        #expect(!FileManager.default.fileExists(atPath: outside))
    }

    @Test("--fsize 는 체인 후에도 워크스페이스 안 쓰기에 걸린다")
    func fileSizeLimitSurvivesTheChain() throws {
        try #require(FileManager.default.isExecutableFile(atPath: SandboxProcessTests.python))
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let big = fixture.workspace.appendingPathComponent("big.txt").path
        let script = try fixture.script("big.py", """
        import sys
        try:
            open(sys.argv[1], "w").write("x" * 200000)
            print("WROTE_ALL")
        except OSError as error:
            print("FSIZE_STOPPED", error.errno)
        """)

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: SandboxProcessTests.python, arguments: [script, big],
                         profile: fixture.profile, wallClockSeconds: 30, fileSizeBytes: 4096,
                         workingDirectory: fixture.workspace.path)
        )
        #expect(!run.standardOutput.contains("WROTE_ALL"))
        #expect(run.standardOutput.contains("FSIZE_STOPPED"))
    }

    @Test("샌드박스가 대상 프로그램을 실행하지 못하면 stderr 로 구별된다")
    func execFailureIsDistinguishable() throws {
        let fixture = try Self.makeFixture()
        defer { fixture.remove() }

        let run = try ToolchainLauncherHarness.run(
            Self.chained(program: "/nonexistent-\(UUID().uuidString)",
                         profile: fixture.profile, wallClockSeconds: 30)
        )
        // 런처 입장에서는 sandbox-exec 가 정상 exec 됐으므로 ERR exec 이 아니라 EXIT 71 이다.
        #expect(run.outcome.termination == .exited(code: SandboxExecFailure.executionFailedExitCode))
        #expect(run.outcome.launcherFailure == nil)
        let failure = try #require(
            SandboxExecFailure.classify(exitCode: run.launcherExitCode, standardError: run.standardError)
        )
        #expect(failure.kind == .executionFailed)
    }
}
