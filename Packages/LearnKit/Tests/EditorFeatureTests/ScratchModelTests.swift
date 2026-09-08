import DesignSystem
import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import EditorFeature

/// 연습장은 **진짜 실행기를 태운다.** 목 러너로만 검증하면 "화면은 도는데 코드가 안
/// 돈다" 를 놓친다 — 이 화면의 존재 이유가 코드를 돌리는 것이다.
@Suite("연습장", .serialized)
struct ScratchModelTests {

    private func temporaryStore() throws -> (ScratchStore, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("scratch-test-\(UUID().uuidString)", isDirectory: true)
        return (ScratchStore(root: root), root)
    }

    // MARK: - 파일

    @Test("처음 열면 진입점 하나가 시작 코드와 함께 생긴다")
    @MainActor
    func createsEntryFileOnFirstOpen() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .python, store: store)

        #expect(model.files.count == 1)
        #expect(model.selectedFileName == "main.py")
        #expect(model.code == ScratchLanguage.python.starterContents)
        // 화면에만 있는 것이 아니라 디스크에 있어야 한다 — 앱을 껐다 켜도 남는다.
        let onDisk = root.appendingPathComponent("python/main.py")
        #expect(FileManager.default.fileExists(atPath: onDisk.path))
    }

    @Test("편집하면 곧바로 디스크에 남는다")
    @MainActor
    func editingPersists() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .python, store: store)
        model.code = "print('바뀐 코드')\n"

        let reopened = ScratchModel(language: .python, store: store)
        #expect(reopened.code == "print('바뀐 코드')\n")
        #expect(model.saveFailure == nil)
    }

    @Test("언어를 바꾸면 그 언어의 파일과 시작 코드로 갈린다")
    @MainActor
    func switchingLanguageSwapsFiles() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .python, store: store)
        model.code = "print('파이썬 쪽')\n"
        model.switchLanguage(to: .rust)

        #expect(model.selectedFileName == "main.rs")
        #expect(model.code == ScratchLanguage.rust.starterContents)

        model.switchLanguage(to: .python)
        #expect(model.code == "print('파이썬 쪽')\n")
    }

    @Test("진입점은 지울 수 없다 — 지우면 실행할 것이 없어진다")
    @MainActor
    func entryFileCannotBeDeleted() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .python, store: store)
        let reason = model.deleteFile(named: "main.py")

        #expect(reason != nil)
        #expect(model.files.contains { $0.name == "main.py" })
    }

    @Test("파일 이름은 그 언어의 확장자여야 하고 경로를 벗어날 수 없다")
    @MainActor
    func fileNamesAreValidated() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .python, store: store)

        #expect(model.addFile(named: "helper.rs") != nil, "다른 언어 확장자가 통과했다")
        #expect(model.addFile(named: "../탈출.py") != nil, "경로 탈출이 통과했다")
        #expect(model.addFile(named: "") != nil, "빈 이름이 통과했다")
        #expect(model.addFile(named: "helper.py") == nil, "정상 이름이 거부됐다")
        #expect(model.addFile(named: "helper.py") != nil, "중복 이름이 통과했다")
        #expect(model.files.map(\.name) == ["main.py", "helper.py"], "진입점이 맨 앞이 아니다")
    }

    @Test("SQL 은 파일 하나만 쓴다")
    @MainActor
    func sqlIsSingleFile() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .sql, store: store)
        #expect(model.addFile(named: "other.sql") != nil)
        #expect(model.files.count == 1)
    }

    // MARK: - 실행 (진짜 러너)

    @Test("파이썬 코드가 실제로 돌고 stdout 이 콘솔에 온다")
    @MainActor
    func runsPythonForReal() async throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        // 기본 배선(`EditorModel.defaultRunner`)이 실제 launcher 를 찾게 한다 —
        // 팩토리를 주입해 우회하면 "화면은 도는데 코드가 안 돈다" 를 못 잡는다.
        RealToolchainEnvironment.install()

        let model = ScratchModel(language: .python, store: store)
        model.code = "print(21 * 2)\n"
        await model.run()

        #expect(model.transcript.lines.contains { $0.text.contains("42") },
                "받은 줄: \(model.transcript.lines.map(\.text))")
        guard case .finished(let succeeded, _, _) = model.runState else {
            Issue.record("종료하지 않았다: \(model.runState)")
            return
        }
        #expect(succeeded)
    }

    @Test("여러 파일이 함께 실행기에 간다 — 진입점만 못박는다")
    @MainActor
    func multipleFilesReachTheRunner() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .cpp, store: store)
        #expect(model.addFile(named: "helper.h") == nil)

        let files = model.runnableFiles()
        #expect(files.map(\.path).sorted() == ["helper.h", "main.cpp"])
    }

    @Test("SQL 은 질의 하나만 간다 — 나머지가 조용히 무시되지 않게")
    @MainActor
    func sqlSendsOnlyTheQuery() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = ScratchModel(language: .sql, store: store)
        let files = model.runnableFiles()
        #expect(files.count == 1)
        #expect(files.first?.path == "query.sql")
    }

    @Test("실행이 실패해도 상태가 running 에 갇히지 않는다")
    @MainActor
    func failedRunDoesNotStickBusy() async throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }

        // 종료 이벤트 없이 닫히는 스트림. 이걸 안 다루면 실행 버튼이 영영 잠긴다.
        let model = ScratchModel(
            language: .python, store: store,
            runFactory: { _, _ in AsyncThrowingStream { $0.finish() } })
        await model.run()

        #expect(model.canRun, "실행 버튼이 잠긴 채로 남았다")
        #expect(model.transcript.isRunning == false)
    }
}
