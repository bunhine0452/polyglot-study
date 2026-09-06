import Testing
import Foundation
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("swiftc 진단 정규화")
struct SwiftDiagnosticParserTests {

    @Test("파일·행·열·심각도·메시지를 뽑는다")
    func parsesLocatedDiagnostics() {
        let text = """
            main.swift:1:14: error: cannot convert value of type 'String' to specified type 'Int'
            let x: Int = "hello"
                         ^~~~~~~
            main.swift:4:7: error: cannot find 'undefinedThing' in scope
            print(undefinedThing)
                  ^~~~~~~~~~~~~~
            """
        let diagnostics = SwiftDiagnosticParser.parse(text)
        #expect(diagnostics.count == 2)
        #expect(diagnostics[0].file == "main.swift")
        #expect(diagnostics[0].line == 1)
        #expect(diagnostics[0].column == 14)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].message.contains("cannot convert value"))
        // 캐럿·스니펫 줄은 진단이 아니다.
        #expect(diagnostics[1].line == 4)
    }

    @Test("진단 그룹은 ruleID 로 들어가고 메시지에서 빠진다")
    func diagnosticGroupBecomesRuleID() {
        let text = "bad.swift:3:16: warning: initialization of immutable value 'y' was never used;"
            + " consider replacing with assignment to '_' or removing it [#no-usage]"
        let diagnostics = SwiftDiagnosticParser.parse(text)
        let diagnostic = try! #require(diagnostics.first)
        #expect(diagnostic.severity == .warning)
        #expect(diagnostic.ruleID == "no-usage")
        #expect(!diagnostic.message.contains("[#"))
        #expect(diagnostic.message.hasSuffix("removing it"))
    }

    @Test("위치 없는 드라이버 오류도 진단이다")
    func parsesBareDiagnostics() {
        let diagnostics = SwiftDiagnosticParser.parse("error: link command failed with exit code 1")
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].file == nil)
        #expect(diagnostics[0].line == nil)
        #expect(diagnostics[0].severity == .error)
    }

    @Test("절대경로는 워크스페이스 기준 상대경로로 접힌다")
    func absolutePathsBecomeRelative() {
        let text = "/tmp/learnkit-run/run-1/main.swift:2:3: error: boom"
        let diagnostics = SwiftDiagnosticParser.parse(text, workspaceRoot: "/tmp/learnkit-run/run-1")
        #expect(diagnostics.first?.file == "main.swift")
    }

    @Test("note 는 error 로 승격되지 않는다")
    func notesStayNotes() {
        let diagnostics = SwiftDiagnosticParser.parse("main.swift:1:1: note: 여기서 선언됨")
        #expect(diagnostics.first?.severity == .note)
    }
}

@Suite("Swift 어댑터 실측", .serialized)
struct LanguageSwiftTests {

    private func runner() throws -> SubprocessRunner {
        try SubprocessTestSupport.runner(program: SwiftProgram())
    }

    /// swiftc 를 도는 관측. 컴파일 부하를 다른 스위트와 겹치지 않게 묶는다.
    private func compileAndObserve(_ request: RunRequest) async throws -> SubprocessTestSupport.Observation {
        let runner = try runner()
        return await CompilerLoadGate.shared.withAccess {
            await SubprocessTestSupport.observe(runner, request)
        }
    }

    @Test("컴파일하고 실행해 stdout 을 낸다")
    func compilesAndRuns() async throws {
        let observation = try await compileAndObserve(
            RunRequest(files: [SourceFile(path: "main.swift", contents: "print(6 * 7)\n")],
                       limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30))
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.stdoutText.contains("42"))
        // `.compiling` 은 `.running` 보다 반드시 먼저다.
        #expect(observation.phases == [.preparing, .compiling, .running])
    }

    @Test("import 없이 Foundation 을 써도 컴파일된다 — 줄 번호는 밀리지 않는다")
    func implicitFoundationKeepsLineNumbers() async throws {
        // 1줄: Foundation 사용, 2줄: 컴파일 오류. 오류가 2행으로 보고돼야 한다.
        let source = """
            FileHandle.standardOutput.write(Data([0x41, 0x0A]))
            let broken: Int = "문자열"
            """
        let observation = try await compileAndObserve(
            RunRequest(files: [SourceFile(path: "main.swift", contents: source)],
                       limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30))
        )
        let errors = observation.diagnostics.filter { $0.severity == .error }
        #expect(!errors.isEmpty)
        #expect(errors.first?.line == 2, "\(observation.diagnostics)")
        #expect(errors.first?.file == "main.swift")
    }

    @Test("컴파일 실패는 예외가 아니라 실패 종료다")
    func compileFailureIsATermination() async throws {
        let observation = try await compileAndObserve(
            RunRequest(files: [SourceFile(path: "main.swift", contents: "let x: Int = \"nope\"\n")],
                       limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30))
        )
        #expect(observation.failure == nil)
        #expect(observation.termination?.succeeded == false)
        #expect(observation.diagnostics.contains { $0.severity == .error })
        // 돌지 않았으니 `.running` 도 없어야 한다.
        #expect(!observation.phases.contains(.running))
        #expect(observation.phases == [.preparing, .compiling])
    }

    @Test("stdin 이 연결되고 종료 코드가 전달된다")
    func standardInputAndExitCode() async throws {
        let source = """
            let line = readLine() ?? ""
            print(line.uppercased())
            exit(7)
            """
        let observation = try await compileAndObserve(
            RunRequest(
                files: [SourceFile(path: "main.swift", contents: source)],
                standardInput: Data("hello\n".utf8),
                limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30)
            )
        )
        #expect(observation.stdoutText.contains("HELLO"))
        #expect(observation.termination?.status == .failed(code: 7))
    }

    @Test("컴파일 인자는 파싱 가능한 진단을 위한 세 플래그를 포함한다")
    func compilerArgumentsCarryDiagnosticFlags() {
        let argv = SwiftProgram.compilerArguments(sources: ["main.swift"], output: "prog")
        #expect(argv.contains("-diagnostic-style=llvm"))
        #expect(argv.contains("-no-color-diagnostics"))
        #expect(argv.contains("-print-diagnostic-groups"))
        #expect(argv.last == "main.swift")
    }

    @Test("/usr/bin 셰이더 대신 xcrun 이 해석한 실제 툴체인 경로를 쓴다")
    func resolvesXcrunShim() async throws {
        // `/usr/bin/swiftc` 는 실제 바이너리가 아니라 xcrun 셰이더다. 샌드박스 아래에서
        // 실행하면 `<DARWIN_USER_TEMP_DIR>/xcrun_db-…` 쓰기가 거부되며
        // `couldn't create cache file …` 이 stderr 에 섞이고, 진단 파서가 그 줄을
        // 컴파일러 진단으로 오인한다. 그래서 실행 대상은 해석된 경로여야 한다.
        let resolved = await LanguageToolchain.shared.resolvingShim("/usr/bin/swiftc")
        #expect(!resolved.hasPrefix("/usr/bin/"), "셰이더가 그대로 남았다: \(resolved)")
        #expect(resolved.hasSuffix("/swiftc"))
        #expect(FileManager.default.isExecutableFile(atPath: resolved))

        // `/usr/bin` 밖의 후보는 셰이더가 아니므로 손대지 않는다.
        let untouched = await LanguageToolchain.shared.resolvingShim("/opt/homebrew/bin/python3")
        #expect(untouched == "/opt/homebrew/bin/python3")

        let chosen = try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.swift)
        #expect(!chosen.hasPrefix("/usr/bin/"), "감지가 셰이더를 골랐다: \(chosen)")
    }

    @Test("진입점이 목록 맨 앞에 온다")
    func entryPointComesFirst() throws {
        let request = RunRequest(
            files: [
                SourceFile(path: "helper.swift", contents: ""),
                SourceFile(path: "main.swift", contents: ""),
            ]
        )
        #expect(try SwiftProgram.sourcePaths(for: request, fallback: "main.swift")
            == ["main.swift", "helper.swift"])
    }
}
