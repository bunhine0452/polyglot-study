import ContentKit
import Foundation
import LearnCore
import LessonGenKit
import Testing

@Suite("팩 쓰기 — 구조·문법 단계를 첫 시도에")
struct PackWriterTests {
    private func lesson(slug: String, ordinal: Int = 1) throws -> GeneratedLesson {
        try LessonAssembler.assemble(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(slug: slug, ordinal: ordinal),
            language: .python,
            generatorModel: "z-ai/glm-5.3-flash",
            upstreamProvider: "TestUpstream")
    }

    private func header(_ id: String = "polyglot-test") -> PackWriter.Header {
        PackWriter.Header(
            packID: PackID(id), displayName: "테스트 팩", generatedAt: "2026-09-06T00:00:00Z")
    }

    @Test("쓴 팩이 매니페스트 디코딩·sha256·참조·디렉티브 파싱을 전부 통과한다")
    func writtenPackVerifies() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = PackWriter(directory: directory)
        let manifest = try writer.write(lessons: [try lesson(slug: "fstring")], header: header()).manifest
        #expect(manifest.lessons.count == 1)
        #expect(manifest.lessons[0].stableID == LessonID("python-fstring"))

        // packtool 의 구조·문법 단계와 같은 코드.
        let documents = try writer.verify()
        #expect(documents.count == 1)
        #expect(documents[0].blocks.count == 6)
    }

    @Test("사이드카 넷이 함께 놓이고 전부 매니페스트에 등록된다")
    func sidecarsRegistered() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = PackWriter(directory: directory)
        let manifest = try writer.write(lessons: [try lesson(slug: "fstring")], header: header()).manifest
        let registered = Set(manifest.files.map(\.path))
        for path in [
            "lessons/python-fstring.md", "expected/python-fstring.txt",
            "starters/python-fstring.py", "tests/python-fstring.py",
            "solutions/python-fstring.py", "stableids.lock",
        ] {
            #expect(registered.contains(path), "등록되지 않은 파일: \(path)")
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent(path).path))
        }
    }

    @Test("같은 레슨을 다시 쓰면 덮어쓰고 중복 항목이 생기지 않는다")
    func rewriteIsIdempotent() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = PackWriter(directory: directory)
        _ = try writer.write(lessons: [try lesson(slug: "fstring")], header: header())
        let manifest = try writer.write(lessons: [try lesson(slug: "fstring")], header: header()).manifest
        #expect(manifest.lessons.count == 1)
        try writer.verify()
    }

    @Test("격리는 레슨과 사이드카를 흔적 없이 지운다 — 등록되지 않은 파일이 남으면 설치가 거부한다")
    func quarantineRemovesEverything() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = PackWriter(directory: directory)
        _ = try writer.write(
            lessons: [try lesson(slug: "keep", ordinal: 1), try lesson(slug: "drop", ordinal: 2)],
            header: header())

        let manifest = try writer.write(
            lessons: [], removing: [LessonID("python-drop")], header: header()).manifest
        #expect(manifest.lessons.map(\.stableID.rawValue) == ["python-keep"])
        for path in [
            "lessons/python-drop.md", "expected/python-drop.txt", "starters/python-drop.py",
            "tests/python-drop.py", "solutions/python-drop.py",
        ] {
            #expect(
                !FileManager.default.fileExists(atPath: directory.appendingPathComponent(path).path),
                "격리 잔여물: \(path)")
        }
        // 잔여물이 있으면 여기서 터진다 (매니페스트와 디스크 양방향 대조).
        try writer.verify()
    }

    @Test("기존 매니페스트의 신원은 도구가 바꾸지 않는다")
    func keepsExistingIdentity() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = PackWriter(directory: directory)
        _ = try writer.write(lessons: [try lesson(slug: "fstring")], header: header("first-id"))
        let existing = try writer.existingManifest()
        #expect(existing?.packID == PackID("first-id"))
        #expect(existing?.generatedAt == "2026-09-06T00:00:00Z")
    }

    @Test("두 번 구운 매니페스트는 바이트가 같다")
    func deterministicBytes() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = PackWriter(directory: directory)
        _ = try writer.write(lessons: [try lesson(slug: "fstring")], header: header())
        let first = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        _ = try writer.write(lessons: [try lesson(slug: "fstring")], header: header())
        let second = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        #expect(first == second)
    }

    @Test("기대 stdout 사이드카는 개행 하나로 끝난다 — 바이트 대조의 전제")
    func expectedStdoutEndsWithNewline() throws {
        let generated = try lesson(slug: "fstring")
        #expect(generated.expectedStdout.hasSuffix("\n"))
        #expect(!generated.expectedStdout.hasSuffix("\n\n"))
    }
}
