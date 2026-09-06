import Foundation
import Testing
import LanguageKit
@testable import RunnerKit

@Suite("워크스페이스 — 경로 판정과 정리")
struct WorkspaceTests {

    // MARK: - 스폰 전 경로 판정

    @Test("절대경로·상위참조·홈참조는 전부 거부", arguments: [
        ("/etc/passwd", WorkspaceError.Reason.absolutePath),
        ("/tmp/x.sql", .absolutePath),
        ("file:///etc/passwd", .absolutePath),
        ("~/.ssh/id_rsa", .homeReference),
        ("../outside.sql", .parentReference),
        ("a/../../outside.sql", .parentReference),
        ("nested/../../../etc/passwd", .parentReference),
        ("", .emptyPath),
        ("a//b.sql", .invalidComponent),
        ("dir/", .invalidComponent),
        ("./a.sql", .invalidComponent),
        ("a/./b.sql", .invalidComponent),
    ])
    func rejectsDangerousPaths(path: String, reason: WorkspaceError.Reason) {
        #expect(throws: WorkspaceError(path: path, reason: reason)) {
            try WorkspacePathPolicy.normalize(path)
        }
    }

    @Test("평범한 상대 경로는 통과")
    func acceptsRelativePaths() throws {
        #expect(try WorkspacePathPolicy.normalize("answer.sql") == "answer.sql")
        #expect(try WorkspacePathPolicy.normalize("src/main/answer.sql") == "src/main/answer.sql")
        #expect(try WorkspacePathPolicy.normalize("..hidden/a.sql") == "..hidden/a.sql")
    }

    @Test("APFS 는 대소문자를 안 가리므로 중복 경로도 거부")
    func rejectsDuplicatePaths() {
        let files = [
            SourceFile(path: "Main.sql", contents: "SELECT 1;"),
            SourceFile(path: "main.sql", contents: "SELECT 2;"),
        ]
        #expect(throws: WorkspaceError(path: "main.sql", reason: .duplicatePath)) {
            try WorkspacePathPolicy.validate(files)
        }
    }

    @Test("거부는 디렉터리를 만들기 전에 일어난다")
    func rejectsBeforeCreatingAnything() throws {
        let container = try makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }

        #expect(throws: (any Error).self) {
            try RunWorkspace(
                files: [SourceFile(path: "../escape.sql", contents: "SELECT 1;")],
                container: container
            )
        }
        #expect(RunWorkspace.residentWorkspaceCount(in: container) == 0)
    }

    // MARK: - 생성

    @Test("파일이 워크스페이스 안에 정확히 놓인다")
    func writesFilesInsideRoot() throws {
        let container = try makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }

        let workspace = try RunWorkspace(
            files: [
                SourceFile(path: "answer.sql", contents: "SELECT 1;"),
                SourceFile(path: "nested/deep/helper.sql", contents: "SELECT 2;"),
            ],
            container: container
        )
        defer { workspace.remove() }

        let answer = try workspace.url(for: "answer.sql")
        let helper = try workspace.url(for: "nested/deep/helper.sql")
        #expect(try String(contentsOf: answer, encoding: .utf8) == "SELECT 1;")
        #expect(try String(contentsOf: helper, encoding: .utf8) == "SELECT 2;")
        #expect(answer.path.hasPrefix(workspace.root.path + "/"))
    }

    @Test("워크스페이스마다 루트가 다르다")
    func rootsAreUnique() throws {
        let container = try makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }

        let first = try RunWorkspace(container: container)
        let second = try RunWorkspace(container: container)
        defer { first.remove(); second.remove() }
        #expect(first.root != second.root)
        #expect(RunWorkspace.residentWorkspaceCount(in: container) == 2)
    }

    @Test("remove() 는 여러 번 불러도 안전")
    func removeIsIdempotent() throws {
        let container = try makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }
        let workspace = try RunWorkspace(container: container)
        workspace.remove()
        workspace.remove()
        #expect(RunWorkspace.residentWorkspaceCount(in: container) == 0)
    }

    // MARK: - 네 종료 경로 × 100회

    @Test("성공·실패·타임아웃·취소 100회 반복 후 잔여 디렉터리 0")
    func cleansUpOnAllFourExitPaths() async throws {
        let container = try makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }

        let files = [SourceFile(path: "answer.sql", contents: "SELECT 1;")]

        for _ in 0..<25 {
            // ① 성공
            let value = try await RunWorkspace.withWorkspace(files: files, container: container) { workspace in
                FileManager.default.fileExists(atPath: workspace.root.path)
            }
            #expect(value)

            // ② 실패
            await #expect(throws: SampleFailure.self) {
                try await RunWorkspace.withWorkspace(files: files, container: container) { _ in
                    throw SampleFailure.boom
                }
            }

            // ③ 타임아웃 (러너가 던지는 것과 같은 오류)
            await #expect(throws: RunFailure.self) {
                try await RunWorkspace.withWorkspace(files: files, container: container) { _ in
                    throw RunFailure.wallClockExceeded(seconds: 1)
                }
            }

            // ④ 취소 — 진짜로 Task 를 취소한다
            let task = Task {
                try await RunWorkspace.withWorkspace(files: files, container: container) { _ in
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
            try await Task.sleep(nanoseconds: 1_000_000)
            task.cancel()
            _ = await task.result
        }

        #expect(RunWorkspace.residentWorkspaceCount(in: container) == 0)
    }

    // MARK: -

    private func makeContainer() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-wstest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    enum SampleFailure: Error { case boom }
}
