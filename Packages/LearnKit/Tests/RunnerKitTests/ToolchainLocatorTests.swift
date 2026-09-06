import Testing
import Foundation
import LanguageKit
@testable import RunnerKit

@Suite("런처 탐색")
struct ToolchainLocatorTests {
    static func makeExecutable(named name: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @Test("환경변수 → 번들 보조 실행파일 → Contents/Helpers → 형제 순으로 본다")
    func searchOrder() {
        let sources = LauncherLocator.Sources(
            environment: [LauncherLocator.environmentKey: "/env/learn-launcher"],
            bundleAuxiliary: URL(fileURLWithPath: "/app/Contents/MacOS/learn-launcher"),
            bundleHelpers: URL(fileURLWithPath: "/app/Contents/Helpers/learn-launcher"),
            siblingDirectory: URL(fileURLWithPath: "/build/debug")
        )
        #expect(LauncherLocator.candidates(sources).map(\.path) == [
            "/env/learn-launcher",
            "/app/Contents/MacOS/learn-launcher",
            "/app/Contents/Helpers/learn-launcher",
            "/build/debug/learn-launcher",
        ])
    }

    @Test("빈 환경변수는 후보로 치지 않는다")
    func emptyOverrideIsIgnored() {
        let sources = LauncherLocator.Sources(environment: [LauncherLocator.environmentKey: ""])
        #expect(LauncherLocator.candidates(sources).isEmpty)
    }

    @Test("환경변수가 다른 후보보다 우선한다")
    func environmentWins() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-locator-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let overridden = try Self.makeExecutable(named: "learn-launcher", in: root.appendingPathComponent("env"))
        let sibling = try Self.makeExecutable(named: "learn-launcher", in: root.appendingPathComponent("build"))

        let sources = LauncherLocator.Sources(
            environment: [LauncherLocator.environmentKey: overridden.path],
            siblingDirectory: sibling.deletingLastPathComponent()
        )
        #expect(try LauncherLocator.locate(sources).path == overridden.path)
    }

    @Test("존재하지 않는 후보는 건너뛰고 다음을 본다")
    func skipsMissingCandidates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-locator-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let sibling = try Self.makeExecutable(named: "learn-launcher", in: root.appendingPathComponent("build"))

        let sources = LauncherLocator.Sources(
            environment: [LauncherLocator.environmentKey: root.appendingPathComponent("nope").path],
            bundleAuxiliary: root.appendingPathComponent("also-nope/learn-launcher"),
            siblingDirectory: sibling.deletingLastPathComponent()
        )
        #expect(try LauncherLocator.locate(sources).path == sibling.path)
    }

    @Test("실행 권한이 없는 파일은 후보가 아니다")
    func requiresExecutableBit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-locator-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("learn-launcher")
        try Data("not executable".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)

        let sources = LauncherLocator.Sources(environment: [LauncherLocator.environmentKey: url.path])
        #expect(throws: RunFailure.self) { try LauncherLocator.locate(sources) }
    }

    @Test("전부 실패하면 toolchainMissing 을 던지고 확인한 경로를 알려준다")
    func throwsToolchainMissing() {
        let sources = LauncherLocator.Sources(
            environment: [LauncherLocator.environmentKey: "/no/such/launcher"],
            siblingDirectory: URL(fileURLWithPath: "/also/nowhere")
        )
        do {
            _ = try LauncherLocator.locate(sources)
            Issue.record("던져야 한다")
        } catch let failure as RunFailure {
            guard case let .toolchainMissing(hint) = failure else {
                Issue.record("toolchainMissing 이어야 한다: \(failure)")
                return
            }
            #expect(hint.contains("/no/such/launcher"))
            #expect(hint.contains(LauncherLocator.environmentKey))
        } catch {
            Issue.record("RunFailure 여야 한다: \(error)")
        }
    }

    @Test("빌드된 런처를 실제로 찾는다")
    func findsRealLauncher() throws {
        let path = try ToolchainLauncherHarness.locateLauncher()
        #expect(FileManager.default.isExecutableFile(atPath: path))
        let sources = LauncherLocator.Sources(environment: [LauncherLocator.environmentKey: path])
        #expect(try LauncherLocator.locate(sources).path == path)
    }
}
