import Foundation
import LearnCore
import Testing

@testable import ContentKit

/// 디스크에 팩 하나를 만든다. 해시는 실제 파일에서 계산한다.
@discardableResult
private func makeLibraryPack(
    at directory: URL,
    packID: String,
    language: LanguageID,
    lessonCount: Int,
    version: String = "1.0.0"
) throws -> PackManifest {
    let manager = FileManager.default
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)

    var entries: [PackManifest.LessonEntry] = []
    // 순번을 **역순으로** 적는다. `lessons(for:)` 가 order 로 정렬하는지 보려면
    // 매니페스트에 적힌 순서가 정답과 달라야 한다.
    for ordinal in stride(from: lessonCount, through: 1, by: -1) {
        let id = "\(packID)-\(ordinal)"
        let path = "lessons/\(id).md"
        let url = directory.appendingPathComponent(path)
        try manager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(ReferenceLesson.full.utf8).write(to: url)
        entries.append(
            PackManifest.LessonEntry(
                stableID: LessonID(id), language: language, title: "레슨 \(ordinal)",
                order: ordinal, path: path))
    }
    for extra in ["expected/run-it.txt", "starters/a.swift", "tests/a.swift", "solutions/a.swift"] {
        let url = directory.appendingPathComponent(extra)
        try manager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x\n".utf8).write(to: url)
    }

    var manifest = PackManifest(
        packID: PackID(packID),
        displayName: packID,
        version: version,
        minAppVersion: "0.1.0",
        generatedAt: "2026-09-07T00:00:00Z",
        languages: [language],
        lessons: entries,
        files: [])
    try PackManifestBuilder.writeLock(StableIDLock.from(manifest: manifest), to: directory)
    manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: directory)
    try PackManifestBuilder.write(manifest, to: directory)
    return manifest
}

@Suite("PackLibrary — 여러 팩을 하나의 커리큘럼으로")
struct PackLibraryTests {

    // MARK: - 탐색

    @Test("manifest.json 을 가진 디렉터리만, 이름 사전순으로 찾는다")
    func discoversOnlyPackDirectories() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let root = temporary.url
            try makeLibraryPack(
                at: root.appendingPathComponent("zeta"), packID: "zeta", language: .swift,
                lessonCount: 1)
            try makeLibraryPack(
                at: root.appendingPathComponent("alpha"), packID: "alpha", language: .python,
                lessonCount: 1)
            // 매니페스트가 없는 이웃 — 팩이 아니다.
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent("notes"), withIntermediateDirectories: true)

            let found = PackLibrary.packDirectories(in: root).map(\.lastPathComponent)
            #expect(found == ["alpha", "zeta"])
        }
    }

    @Test("팩 안의 하위 디렉터리로 재귀하지 않는다")
    func doesNotRecurseIntoPacks() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let root = temporary.url
            let pack = root.appendingPathComponent("alpha")
            try makeLibraryPack(at: pack, packID: "alpha", language: .python, lessonCount: 2)
            // 팩 안에 매니페스트를 하나 더 심어도 그건 팩이 아니다.
            try Data("{}".utf8).write(
                to: pack.appendingPathComponent("lessons/\(PackLayout.manifestFileName)"))

            #expect(PackLibrary.packDirectories(in: root).count == 1)
        }
    }

    // MARK: - 직접 열기

    @Test("깨진 팩 하나가 나머지를 막지 않고, 깨진 사실은 problems 에 남는다")
    func brokenPackDoesNotHideTheRest() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let root = temporary.url
            try makeLibraryPack(
                at: root.appendingPathComponent("good"), packID: "good", language: .python,
                lessonCount: 3)
            let broken = root.appendingPathComponent("broken")
            try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
            try Data("not json".utf8).write(
                to: broken.appendingPathComponent(PackLayout.manifestFileName))

            let library = PackLibrary.open(directories: PackLibrary.packDirectories(in: root))
            #expect(library.packIDs.map(\.rawValue) == ["good"])
            #expect(library.problems.count == 1)
            #expect(library.problems[0].source == "broken")
        }
    }

    @Test("레슨은 order 순으로 나오고 팩 id 를 달고 나온다")
    func lessonsCarryTheirPack() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let root = temporary.url
            try makeLibraryPack(
                at: root.appendingPathComponent("py"), packID: "py", language: .python,
                lessonCount: 3)
            try makeLibraryPack(
                at: root.appendingPathComponent("sq"), packID: "sq", language: .sql,
                lessonCount: 2)

            let library = PackLibrary.open(directories: PackLibrary.packDirectories(in: root))
            let python = library.lessons(for: .python)
            #expect(python.map(\.lessonID.rawValue) == ["py-1", "py-2", "py-3"])
            #expect(python.allSatisfy { $0.packID == PackID("py") })
            #expect(library.lessonCount(for: .sql) == 2)
            #expect(library.lessonCount(for: .swift) == 0)
            #expect(Set(library.languages) == [.python, .sql])
        }
    }

    // MARK: - 설치 경로 ({#wire-pack-installer})

    @Test("씨앗 팩들이 스토어에 설치되고 current 를 통해 열린다")
    func provisionInstallsSeeds() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let seedRoot = temporary.child("seeds")
            try makeLibraryPack(
                at: seedRoot.appendingPathComponent("py"), packID: "py", language: .python,
                lessonCount: 2)
            try makeLibraryPack(
                at: seedRoot.appendingPathComponent("sw"), packID: "sw", language: .swift,
                lessonCount: 4)
            let store = PackStore(root: temporary.child("ContentPacks"))

            let library = PackLibrary.provision(
                seeds: PackLibrary.packDirectories(in: seedRoot), into: store)

            #expect(library.problems.isEmpty)
            #expect(library.packIDs.map(\.rawValue) == ["py", "sw"])
            #expect(store.currentVersion(PackID("py")) == "1.0.0")
            // 팩은 씨앗이 아니라 **스토어**에서 열려야 한다 — 업데이트가 오는 곳이 거기다.
            let opened = try #require(library.pack(PackID("sw")))
            #expect(opened.directory.path.hasPrefix(store.root.path))
            #expect(library.lessonCount(for: .swift) == 4)
        }
    }

    @Test("같은 버전은 다시 설치하지 않는다")
    func provisionIsIdempotent() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let seedRoot = temporary.child("seeds")
            try makeLibraryPack(
                at: seedRoot.appendingPathComponent("py"), packID: "py", language: .python,
                lessonCount: 2)
            let store = PackStore(root: temporary.child("ContentPacks"))
            let seeds = PackLibrary.packDirectories(in: seedRoot)

            _ = PackLibrary.provision(seeds: seeds, into: store)
            // 설치된 버전 디렉터리에 표식을 남긴다. 다시 설치하면 사라진다.
            let marker = store.versionDirectory(PackID("py"), version: "1.0.0")
                .appendingPathComponent("touched")
            try Data("1".utf8).write(to: marker)

            let second = PackLibrary.provision(seeds: seeds, into: store)

            #expect(second.problems.isEmpty)
            #expect(second.packIDs.map(\.rawValue) == ["py"])
            #expect(store.installedVersions(PackID("py")) == ["1.0.0"])
            #expect(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    @Test("current 포인터만 없으면 다시 세운다")
    func provisionRestoresMissingPointer() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let seedRoot = temporary.child("seeds")
            try makeLibraryPack(
                at: seedRoot.appendingPathComponent("py"), packID: "py", language: .python,
                lessonCount: 1)
            let store = PackStore(root: temporary.child("ContentPacks"))
            let seeds = PackLibrary.packDirectories(in: seedRoot)
            _ = PackLibrary.provision(seeds: seeds, into: store)

            // 포인터를 옮기다 죽은 상태를 흉내낸다 — 버전은 있고 current 는 없다.
            try FileManager.default.removeItem(at: store.currentPointer(PackID("py")))
            #expect(store.currentVersion(PackID("py")) == nil)

            let restored = PackLibrary.provision(seeds: seeds, into: store)
            #expect(restored.problems.isEmpty)
            #expect(store.currentVersion(PackID("py")) == "1.0.0")
        }
    }

    @Test("중단된 설치의 .staging 잔여물은 설치 전에 쓸어낸다")
    func provisionSweepsStagingResidue() throws {
        try withTemporaryDirectory("pack-library") { temporary in
            let seedRoot = temporary.child("seeds")
            try makeLibraryPack(
                at: seedRoot.appendingPathComponent("py"), packID: "py", language: .python,
                lessonCount: 1)
            let store = PackStore(root: temporary.child("ContentPacks"))
            let residue = store.packDirectory(PackID("py"))
                .appendingPathComponent(".staging-leftover", isDirectory: true)
            try FileManager.default.createDirectory(at: residue, withIntermediateDirectories: true)

            _ = PackLibrary.provision(
                seeds: PackLibrary.packDirectories(in: seedRoot), into: store)

            #expect(!FileManager.default.fileExists(atPath: residue.path))
        }
    }

    // MARK: - 리포의 실제 팩

    @Test("리포의 MVP 세 트랙이 한 라이브러리로 열린다 — 언어 3종 · 레슨 36편")
    func repositoryMVPTracksOpen() throws {
        // `Content/packs` 는 **앱이 번들하는 것만** 담는다. 포맷 스펙 픽스처
        // (`polyglot-mvp`)는 `Content/fixtures` 에 따로 산다 — 그래서 여기에 예외가 없다.
        let root = RepoPaths.root.appendingPathComponent("Content/packs", isDirectory: true)
        let library = PackLibrary.open(directories: PackLibrary.packDirectories(in: root))

        #expect(library.problems.isEmpty)
        #expect(library.packIDs.map(\.rawValue) == ["polyglot-python", "polyglot-sql", "polyglot-swift"])
        #expect(library.lessonCount(for: .python) == 12)
        #expect(library.lessonCount(for: .sql) == 12)
        #expect(library.lessonCount(for: .swift) == 12)

        // 대시보드가 "다음 레슨" 으로 가리킬 첫 레슨이 실제로 열려야 한다.
        let first = try #require(library.lessons(for: .python).first)
        let pack = try #require(library.pack(first.packID))
        #expect(try pack.lesson(first.lessonID).blocks.count == 6)
    }
}
