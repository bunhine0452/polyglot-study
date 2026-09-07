import ContentKit
import Foundation
import LearnCore
import SwiftUI
import Testing

@testable import EditorFeature

/// 리포에 커밋된 **진짜 팩**으로 검증한다. 픽스처를 새로 만들지 않는 이유는 이 변환이
/// 지켜야 하는 것이 팩 포맷 그 자체이기 때문이다 — 손으로 만든 팩은 규약이 어긋나도
/// 통과한다.
private enum PackFixture {
    static var packsRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("Content/packs", isDirectory: true)
    }

    static func pack(_ id: String) throws -> ContentPack {
        try ContentPack(directory: packsRoot.appendingPathComponent(id, isDirectory: true))
    }

    /// 그 팩의 첫 레슨에서 `@Task` 블록과 그 위치를 꺼낸다.
    static func firstTask(in pack: ContentPack) throws -> (TaskBlock, index: Int, count: Int, id: LessonID) {
        let entry = try #require(pack.manifest.lessons.sorted { $0.order < $1.order }.first)
        let document = try pack.lesson(entry.stableID)
        let index = try #require(document.blocks.firstIndex { $0.kind == .task })
        guard case .task(let block) = document.blocks[index] else {
            throw PackFixtureError.notATask
        }
        return (block, index, document.blocks.count, entry.stableID)
    }

    enum PackFixtureError: Error { case notATask }
}

@Suite("팩의 @Task 를 에디터 과제로 — packtool 게이트와 같은 규칙")
struct PackTaskLoadingTests {

    @Test("Python 진입점은 solution.py 여야 한다 — 숨은 테스트가 from solution import 로 부른다")
    func pythonEntryFileMatchesHiddenTests() throws {
        let pack = try PackFixture.pack("polyglot-python")
        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let loaded = try EditorTask.load(
            pack: pack, task: task, trackCaption: "Python · 레슨 01 / 12",
            lessonTitle: "제목", blockIndex: index, blockCount: count)

        #expect(loaded.entryFileName == "solution.py")
        #expect(loaded.language == .python)
        #expect(loaded.starterSource == (try pack.text(at: task.starterPath)))
        #expect(loaded.testSource == (try pack.text(at: task.testsPath)))
        // 다른 언어의 재료를 실어 보내지 않는다.
        #expect(loaded.solutionSource == nil)
        #expect(loaded.database == nil)
        #expect(loaded.testCount > 0)
        // 팩의 숨은 테스트가 실제로 그 모듈 이름을 부른다.
        #expect(try pack.text(at: task.testsPath).contains("from solution import"))
    }

    @Test("Swift 는 main.swift 로 열리고 @Test 개수가 라벨에 실린다")
    func swiftTaskCarriesTestCount() throws {
        let pack = try PackFixture.pack("polyglot-swift")
        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let loaded = try EditorTask.load(
            pack: pack, task: task, trackCaption: "Swift · 레슨 01 / 12",
            lessonTitle: "제목", blockIndex: index, blockCount: count)

        #expect(loaded.entryFileName == "main.swift")
        #expect(loaded.testSource != nil)
        #expect(loaded.solutionSource == nil)
        #expect(loaded.testCount >= 2)
    }

    @Test("SQL 의 참조 질의는 solutions/ 가 아니라 tests/ 에서 온다 — 배포 팩은 solutions 를 벗긴다")
    func sqlReferenceComesFromTests() throws {
        let pack = try PackFixture.pack("polyglot-sql")
        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let database = URL(fileURLWithPath: "/tmp/seed.db")
        let loaded = try EditorTask.load(
            pack: pack, task: task, trackCaption: "SQL · 레슨 01 / 12",
            lessonTitle: "제목", blockIndex: index, blockCount: count, database: database)

        #expect(loaded.entryFileName == "query.sql")
        #expect(loaded.solutionSource == (try pack.text(at: task.testsPath)))
        #expect(loaded.solutionSource != (try pack.text(at: task.solutionPath)))
        #expect(loaded.testSource == nil)
        #expect(loaded.database == database)
        #expect(loaded.testCount == 0)
    }

    @Test("과제 바 번호와 헤더 캡션은 블록 위치에서 나온다")
    func captionsComeFromBlockPosition() throws {
        let pack = try PackFixture.pack("polyglot-sql")
        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let loaded = try EditorTask.load(
            pack: pack, task: task, trackCaption: "SQL · 레슨 01 / 12",
            lessonTitle: "테이블에서 원하는 데이터 꺼내기", blockIndex: index, blockCount: count)

        #expect(index == 3)  // 6블록 시퀀스에서 과제는 넷째다.
        #expect(loaded.taskOrdinalLabel == "04 테스트 과제")
        #expect(loaded.blockCaption == "블록 4 / 6 · 테스트 과제")
        #expect(loaded.trackCaption == "SQL · 레슨 01 / 12")
    }

    // MARK: - 종단

    @Test("팩에서 조립한 SQL 과제가 실제 시드 DB 위에서 채점된다 — solution 통과, starter 실패")
    func sqlTaskGradesOnRealSeedDatabase() async throws {
        let pack = try PackFixture.pack("polyglot-sql")
        let workspace = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("editor-seed-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let seed = try #require(try PackSQLSeed.materialize(pack: pack, into: workspace))

        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let editorTask = try EditorTask.load(
            pack: pack, task: task, trackCaption: "SQL · 레슨 01 / 12",
            lessonTitle: "제목", blockIndex: index, blockCount: count, database: seed)

        // 팩의 정답이 통과해야 한다. 팩토리를 주입하지 않는다 — `EditorModel` 의 기본
        // 배선(`InProcessRunner`·`SQLResultSetGrader`)이 곧 검증 대상이다.
        let passing = EditorModel(task: editorTask)
        passing.code = try pack.text(at: task.solutionPath)
        await passing.submit()
        #expect(passing.gradeState.result?.passed == true)

        // starter 는 실패해야 한다. 통과하면 그 과제는 아무것도 요구하지 않는 것이다.
        let failing = EditorModel(task: editorTask)
        failing.code = editorTask.starterSource
        await failing.submit()
        #expect(failing.gradeState.result?.passed == false)
    }

    // MARK: - 렌더

    @Test("팩에서 조립한 과제가 에디터 화면으로 실제 비트맵까지 간다", arguments: [
        "polyglot-python", "polyglot-swift", "polyglot-sql",
    ])
    @MainActor
    func editorScreenRendersFromPack(packID: String) throws {
        let pack = try PackFixture.pack(packID)
        let (task, index, count, _) = try PackFixture.firstTask(in: pack)
        let editorTask = try EditorTask.load(
            pack: pack, task: task, trackCaption: "트랙 · 레슨 01 / 12",
            lessonTitle: "제목", blockIndex: index, blockCount: count,
            database: URL(fileURLWithPath: "/tmp/does-not-need-to-exist.db"))
        let model = EditorModel(task: editorTask)

        let renderer = ImageRenderer(
            content: EditorView(model: model).frame(width: 1128, height: 720))
        #expect(renderer.nsImage != nil)
        // 비트맵만 보면 빈 화면이 그려져도 통과한다 — 화면이 그릴 값도 함께 못 박는다.
        #expect(!model.code.isEmpty)
        #expect(model.task.taskOrdinalLabel == "04 테스트 과제")
    }

    // MARK: - 개수 세기

    @Test("숨은 테스트 개수 — 언어별 규칙과 못 세는 경우")
    func hiddenTestCounting() {
        let swiftSource = """
            import Testing
            @testable import Solution

            @Test func a() {}
            @Test("이름이 붙은 것") func b() {}
              @Test
              func c() {}
            // @Test 주석은 세지 않아야 하지만 줄 시작이 아니므로 그냥 지나간다
            let notATestcase = 1
            """
        #expect(EditorTask.hiddenTestCount(in: swiftSource, language: .swift) == 3)

        let pythonSource = """
            import unittest

            class T(unittest.TestCase):
                def test_one(self): pass
                def test_two(self): pass
                def helper(self): pass
            """
        #expect(EditorTask.hiddenTestCount(in: pythonSource, language: .python) == 2)
        // 셀 규칙이 없는 언어는 0 — 화면은 0 이면 라벨을 아예 그리지 않는다.
        #expect(EditorTask.hiddenTestCount(in: pythonSource, language: .sql) == 0)
    }
}
