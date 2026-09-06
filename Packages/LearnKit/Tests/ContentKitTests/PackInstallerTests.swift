import Foundation
import LearnCore
import Testing

@testable import ContentKit

/// 디스크에 최소 팩 하나를 만든다. 매니페스트의 해시는 실제 파일에서 계산한다.
@discardableResult
private func makePack(
    at directory: URL,
    packID: String = "sample-pack",
    version: String = "1.0.0",
    minAppVersion: String = "0.1.0"
) throws -> PackManifest {
    let manager = FileManager.default
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)

    let files: [(String, String)] = [
        ("lessons/py-0001-a.md", ReferenceLesson.full),
        ("expected/run-it.txt", "hello\n"),
        ("starters/a.swift", "// starter\n"),
        ("tests/a.swift", "// tests\n"),
        ("solutions/a.swift", "// solution\n"),
        ("assets/note.txt", "asset\n"),
    ]
    for (path, contents) in files {
        let url = directory.appendingPathComponent(path)
        try manager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    var manifest = PackManifest(
        packID: PackID(packID),
        displayName: "샘플 팩",
        version: version,
        minAppVersion: minAppVersion,
        generatedAt: "2026-09-06T00:00:00Z",
        languages: [.swift],
        lessons: [
            PackManifest.LessonEntry(
                stableID: LessonID("py-0001-a"), language: .swift, title: "레슨", order: 1,
                path: "lessons/py-0001-a.md")
        ],
        files: [])
    try PackManifestBuilder.writeLock(StableIDLock.from(manifest: manifest), to: directory)
    manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: directory)
    try PackManifestBuilder.write(manifest, to: directory)
    return manifest
}

private func installError(
    _ installer: PackInstaller, _ source: URL, appVersion: SemanticVersion? = nil
) -> PackInstallError? {
    do {
        _ = try installer.install(from: source, appVersion: appVersion)
        return nil
    } catch {
        return error
    }
}

private func stagingCount(_ store: PackStore, _ packID: PackID) -> Int {
    let contents =
        (try? FileManager.default.contentsOfDirectory(atPath: store.packDirectory(packID).path))
        ?? []
    return contents.filter { $0.hasPrefix(".staging-") }.count
}

private let samplePackID = PackID("sample-pack")

@Suite("팩 설치 — 원자성과 롤백")
struct PackInstallerTests {
    @Test("설치하면 버전 디렉터리와 current 포인터가 생긴다")
    func installCreatesVersionAndPointer() throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            try makePack(at: source)
            let store = PackStore(root: temp.child("ContentPacks"))

            let installed = try PackInstaller(store: store).install(from: source)
            #expect(installed.version == "1.0.0")
            #expect(FileManager.default.exists(installed.directory))
            #expect(store.currentVersion(samplePackID) == "1.0.0")
            #expect(store.currentDirectory(samplePackID)?.path == installed.directory.path)
            #expect(store.installedVersions(samplePackID) == ["1.0.0"])
            #expect(store.installedPackIDs() == [samplePackID])
        }
    }

    @Test("설치된 팩은 그대로 다시 읽힌다")
    func installedPackReadsBack() throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            try makePack(at: source)
            let store = PackStore(root: temp.child("ContentPacks"))
            let installed = try PackInstaller(store: store).install(from: source)

            let pack = try ContentPack(directory: installed.directory)
            try pack.verifyChecksums()
            try pack.checkStableIDLock()
            let lesson = try pack.lesson(LessonID("py-0001-a"))
            #expect(lesson.blocks.map(\.kind) == LessonBlockKind.requiredSequence)
        }
    }

    @Test("두 번째 버전을 설치하면 current 가 옮겨간다")
    func secondVersionMovesPointer() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let installer = PackInstaller(store: store)
            try makePack(at: temp.child("v1"), version: "1.0.0")
            try installer.install(from: temp.child("v1"))
            try makePack(at: temp.child("v2"), version: "1.1.0")
            try installer.install(from: temp.child("v2"))

            #expect(store.currentVersion(samplePackID) == "1.1.0")
            #expect(store.installedVersions(samplePackID) == ["1.0.0", "1.1.0"])
        }
    }

    @Test("롤백은 포인터만 되돌린다")
    func rollbackMovesPointerBack() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let installer = PackInstaller(store: store)
            try makePack(at: temp.child("v1"), version: "1.0.0")
            try installer.install(from: temp.child("v1"))
            try makePack(at: temp.child("v2"), version: "1.1.0")
            try installer.install(from: temp.child("v2"))

            try installer.activate(packID: samplePackID, version: "1.0.0")
            #expect(store.currentVersion(samplePackID) == "1.0.0")
            // 두 버전 다 남아 있다.
            #expect(store.installedVersions(samplePackID) == ["1.0.0", "1.1.0"])
        }
    }

    @Test("current 가 가리키는 버전은 지울 수 없다")
    func cannotUninstallCurrent() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let installer = PackInstaller(store: store)
            try makePack(at: temp.child("v1"))
            try installer.install(from: temp.child("v1"))

            #expect(
                throws: PackInstallError.versionInUse(packID: samplePackID, version: "1.0.0")
            ) {
                try installer.uninstall(packID: samplePackID, version: "1.0.0")
            }
        }
    }

    @Test(
        "설치 도중 강제 종료돼도 current 는 이전 버전을 가리킨다",
        arguments: [InstallPhase.validated, .staged, .verified])
    func crashKeepsPreviousCurrent(_ phase: InstallPhase) throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            try makePack(at: temp.child("v1"), version: "1.0.0")
            try PackInstaller(store: store).install(from: temp.child("v1"))
            try makePack(at: temp.child("v2"), version: "1.1.0")

            let crashing = PackInstaller(store: store, crashAfter: phase)
            #expect(throws: PackInstallError.interrupted(phase)) {
                try crashing.install(from: temp.child("v2"))
            }

            #expect(store.currentVersion(samplePackID) == "1.0.0")
            #expect(
                FileManager.default.exists(store.versionDirectory(samplePackID, version: "1.0.0")))
            #expect(
                !FileManager.default.exists(store.versionDirectory(samplePackID, version: "1.1.0")))
        }
    }

    @Test("버전 디렉터리를 놓은 뒤 죽어도 current 는 아직 이전 버전이다")
    func crashAfterVersionPlacedKeepsPointer() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            try makePack(at: temp.child("v1"), version: "1.0.0")
            try PackInstaller(store: store).install(from: temp.child("v1"))
            try makePack(at: temp.child("v2"), version: "1.1.0")

            let crashing = PackInstaller(store: store, crashAfter: .versionPlaced)
            #expect(throws: PackInstallError.interrupted(.versionPlaced)) {
                try crashing.install(from: temp.child("v2"))
            }
            #expect(store.currentVersion(samplePackID) == "1.0.0")
            // 새 버전의 파일은 다 있다 — 다음 실행이 포인터만 옮기면 된다.
            #expect(
                FileManager.default.exists(store.versionDirectory(samplePackID, version: "1.1.0")))
            try PackInstaller(store: store).activate(packID: samplePackID, version: "1.1.0")
            #expect(store.currentVersion(samplePackID) == "1.1.0")
        }
    }

    @Test("강제 종료가 남긴 스테이징은 다음 설치가 쓸어낸다")
    func stagingResidueIsSwept() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            try makePack(at: temp.child("v1"), version: "1.0.0")
            try PackInstaller(store: store).install(from: temp.child("v1"))
            try makePack(at: temp.child("v2"), version: "1.1.0")

            #expect(throws: PackInstallError.interrupted(.staged)) {
                try PackInstaller(store: store, crashAfter: .staged).install(from: temp.child("v2"))
            }
            #expect(stagingCount(store, samplePackID) == 1)

            try PackInstaller(store: store).install(from: temp.child("v2"))
            #expect(stagingCount(store, samplePackID) == 0)
            #expect(store.currentVersion(samplePackID) == "1.1.0")
        }
    }

    @Test("실패한 설치는 스테이징을 남기지 않는다")
    func failedInstallLeavesNoStaging() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let source = temp.child("src")
            try makePack(at: source)

            // 매니페스트를 구운 뒤 파일을 고쳐 해시를 어긋나게 한다.
            try Data("tampered\n".utf8).write(
                to: source.appendingPathComponent("expected/run-it.txt"))

            let error = installError(PackInstaller(store: store), source)
            switch error {
            case .checksumMismatch(let path, _, _): #expect(path == "expected/run-it.txt")
            case .sizeMismatch(let path, _, _): #expect(path == "expected/run-it.txt")
            default: Issue.record("해시 불일치가 잡히지 않았다: \(String(describing: error))")
            }
            #expect(stagingCount(store, samplePackID) == 0)
            #expect(store.currentVersion(samplePackID) == nil)
        }
    }

    @Test("같은 버전을 두 번 설치하면 거부된다")
    func duplicateVersionRejected() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let source = temp.child("src")
            try makePack(at: source)
            let installer = PackInstaller(store: store)
            try installer.install(from: source)

            #expect(
                throws: PackInstallError.versionAlreadyInstalled(
                    packID: samplePackID, version: "1.0.0")
            ) {
                try installer.install(from: source)
            }
        }
    }

    @Test("매니페스트에 없는 파일이 디스크에 있으면 거부된다")
    func unregisteredFileOnDiskRejected() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let source = temp.child("src")
            try makePack(at: source)
            try Data("stray\n".utf8).write(to: source.appendingPathComponent("assets/stray.txt"))

            #expect(
                installError(PackInstaller(store: store), source)
                    == .unregisteredFileOnDisk(path: "assets/stray.txt"))
        }
    }

    @Test("매니페스트에 있는데 디스크에 없으면 거부된다")
    func missingFileRejected() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let source = temp.child("src")
            try makePack(at: source)
            try FileManager.default.removeItem(at: source.appendingPathComponent("assets/note.txt"))

            #expect(
                installError(PackInstaller(store: store), source)
                    == .fileMissing(path: "assets/note.txt"))
        }
    }

    @Test("앱보다 새 팩은 설치되지 않고 사용자 문구가 남는다")
    func versionGateBlocksInstall() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let source = temp.child("src")
            try makePack(at: source, minAppVersion: "9.0.0")

            let error = installError(
                PackInstaller(store: store), source,
                appVersion: SemanticVersion(major: 1, minor: 0, patch: 0))
            guard case .incompatible(let reason) = error else {
                Issue.record("게이트가 열려 있다: \(String(describing: error))")
                return
            }
            #expect(reason.userMessage.contains("9.0.0"))
            #expect(!FileManager.default.exists(temp.child("ContentPacks")))
        }
    }
}

@Suite("팩 경로 하드닝 — 설치 전에 거부하고 잔여물 0")
struct PackPathHardeningTests {
    @Test("악성 경로 1 — 상위 탈출")
    func rejectsParentEscape() throws {
        try expectRejection(mutate: { $0.files[0].path = "../escape.md" }) { error in
            error == .unsafeEntry(path: "../escape.md", reason: .parentEscape("../escape.md"))
        }
    }

    @Test("악성 경로 2 — 절대경로")
    func rejectsAbsolutePath() throws {
        try expectRejection(mutate: { $0.files[0].path = "/etc/passwd" }) { error in
            error == .unsafeEntry(path: "/etc/passwd", reason: .absolute("/etc/passwd"))
        }
    }

    @Test("악성 경로 3 — 정규화로 빠져나가는 경로")
    func rejectsNormalizedEscape() throws {
        try expectRejection(mutate: { $0.files[0].path = "lessons/../../escape.md" }) { error in
            error
                == .unsafeEntry(
                    path: "lessons/../../escape.md",
                    reason: .parentEscape("lessons/../../escape.md"))
        }
    }

    @Test("악성 경로 4 — 디스크의 심볼릭 링크")
    func rejectsSymbolicLink() throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            try makePack(at: source)
            // 매니페스트에 등록된 파일을 링크로 바꿔치기한다.
            let target = source.appendingPathComponent("expected/run-it.txt")
            try FileManager.default.removeItem(at: target)
            try FileManager.default.createSymbolicLink(
                atPath: target.path, withDestinationPath: "/etc/passwd")

            let store = PackStore(root: temp.child("ContentPacks"))
            #expect(
                installError(PackInstaller(store: store), source)
                    == .symbolicLink(path: "expected/run-it.txt"))
            #expect(!FileManager.default.exists(temp.child("ContentPacks")))
        }
    }

    @Test("거부된 팩은 스토어 루트조차 만들지 않는다")
    func rejectionLeavesNoResidue() throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            var manifest = try makePack(at: source)
            manifest.files[0].path = "../escape.md"
            try PackManifestBuilder.write(manifest, to: source)

            let store = PackStore(root: temp.child("ContentPacks"))
            _ = installError(PackInstaller(store: store), source)
            #expect(!FileManager.default.exists(temp.child("ContentPacks")))
            #expect(temp.entryCount() == 1)  // src 만 남는다
        }
    }

    @Test("레이아웃 밖의 파일은 설치 전에 거부된다")
    func rejectsFileOutsideLayout() throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            try makePack(at: source)
            let stray = source.appendingPathComponent("scripts/build.sh")
            try FileManager.default.createDirectory(
                at: stray.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/sh\n".utf8).write(to: stray)

            let store = PackStore(root: temp.child("ContentPacks"))
            #expect(
                installError(PackInstaller(store: store), source)
                    == .fileOutsideLayout(path: "scripts/build.sh"))
            #expect(!FileManager.default.exists(temp.child("ContentPacks")))
        }
    }

    private func expectRejection(
        mutate: (inout PackManifest) -> Void,
        check: (PackInstallError?) -> Bool
    ) throws {
        try withTemporaryDirectory { temp in
            let source = temp.child("src")
            var manifest = try makePack(at: source)
            mutate(&manifest)
            try PackManifestBuilder.write(manifest, to: source)

            let store = PackStore(root: temp.child("ContentPacks"))
            let error = installError(PackInstaller(store: store), source)
            #expect(check(error), "기대와 다른 에러: \(String(describing: error))")
            #expect(!FileManager.default.exists(temp.child("ContentPacks")))
        }
    }
}
