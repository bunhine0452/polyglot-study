import Foundation
import LearnCore
import Testing

@testable import ContentKit

/// 리포에 커밋된 `Content/fixtures/polyglot-mvp` 가 스펙대로인지 본다.
///
/// 스펙 문서와 샘플 팩과 파서가 셋 다 같은 것을 말해야 의미가 있다. 문서만 고치고
/// 팩을 안 고치거나, 팩만 고치고 해시를 안 갱신하는 실수가 여기서 잡힌다.
@Suite("샘플 팩 — Content/fixtures/polyglot-mvp")
struct SamplePackTests {
    @Test("팩 디렉터리가 리포에 있다")
    func packExists() {
        #expect(FileManager.default.exists(RepoPaths.samplePack))
        #expect(FileManager.default.exists(RepoPaths.packFormatSpec))
    }

    @Test("매니페스트가 검증을 통과한다")
    func manifestValidates() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        #expect(pack.manifest.packID == PackID("polyglot-mvp"))
        #expect(pack.manifest.schemaVersion == PackManifest.currentSchemaVersion)
        #expect(pack.manifest.languages == [.python, .sql, .swift])
        #expect(pack.manifest.lessons.count == 3)
    }

    @Test("레이아웃 6종 디렉터리가 모두 쓰인다")
    func layoutIsExercised() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        let used = Set(pack.manifest.files.compactMap {
            try? PackRelativePath(validating: $0.path).topLevelDirectory
        })
        for directory in PackLayout.contentDirectories {
            #expect(used.contains(directory), "\(directory)/ 를 쓰는 파일이 없다")
        }
    }

    @Test("모든 파일의 sha256 과 크기가 최신이다")
    func checksumsAreCurrent() throws {
        try ContentPack(directory: RepoPaths.samplePack).verifyChecksums()
    }

    @Test("매니페스트를 다시 구우면 바이트가 같다")
    func manifestIsCanonical() throws {
        let url = RepoPaths.samplePack.appendingPathComponent(PackLayout.manifestFileName)
        let onDisk = try #require(FileManager.default.contents(atPath: url.path))
        let manifest = try CanonicalJSON.decode(PackManifest.self, from: onDisk)

        // ① 디코딩한 것을 그대로 다시 구우면 파일과 같아야 한다 (정규 바이트 규칙).
        #expect(try CanonicalJSON.encode(manifest) == onDisk)
        // ② 디스크에서 files 를 재계산해도 같아야 한다 (해시가 최신).
        let rebuilt = try PackManifestBuilder.rebuildingFiles(of: manifest, in: RepoPaths.samplePack)
        #expect(try CanonicalJSON.encode(rebuilt) == onDisk)
        // ③ 두 번 구운 결과가 같아야 한다.
        #expect(try CanonicalJSON.encode(rebuilt) == CanonicalJSON.encode(rebuilt))
    }

    @Test("잠금 파일이 매니페스트를 허락하고 정규 텍스트다")
    func lockIsCurrent() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        try pack.checkStableIDLock()

        let url = RepoPaths.samplePack.appendingPathComponent(PackLayout.lockFileName)
        let onDisk = try #require(FileManager.default.contents(atPath: url.path))
        let expected = StableIDLock.from(manifest: pack.manifest).canonicalText()
        #expect(String(decoding: onDisk, as: UTF8.self) == expected)
    }

    @Test("세 레슨이 모두 6블록으로 파싱된다")
    func lessonsParse() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        let documents = try pack.validateReferences()
        #expect(documents.count == 3)
        for document in documents {
            #expect(
                document.blocks.map(\.kind) == LessonBlockKind.requiredSequence,
                "\(document.stableID.rawValue) 의 블록 구성이 다르다")
            #expect(document.example?.language == document.language)
            #expect(document.task?.language == document.language)
        }
    }

    @Test("빈칸의 정답이 표식을 빠짐없이 덮는다")
    func blanksAreComplete() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        for document in try pack.allLessons() {
            let blank = try #require(document.blank)
            let markers = Set(BlankSlotMarker.indices(in: blank.template))
            #expect(markers == Set(blank.slots.map(\.index)))
            #expect(!blank.filledTemplate().contains("___"))
        }
    }

    @Test("퀴즈 정답 키가 실제 선택지를 가리킨다")
    func quizAnswersResolve() throws {
        let pack = try ContentPack(directory: RepoPaths.samplePack)
        for document in try pack.allLessons() {
            let quiz = try #require(document.quiz)
            #expect(quiz.choices.count >= 2)
            #expect(quiz.answer != nil, "\(document.stableID.rawValue) 의 정답 키가 선택지에 없다")
        }
    }

    @Test("샘플 팩은 그대로 설치된다")
    func samplePackInstalls() throws {
        try withTemporaryDirectory { temp in
            let store = PackStore(root: temp.child("ContentPacks"))
            let installed = try PackInstaller(store: store).install(
                from: RepoPaths.samplePack,
                appVersion: SemanticVersion(major: 0, minor: 1, patch: 0))

            #expect(installed.packID == PackID("polyglot-mvp"))
            #expect(store.currentVersion(PackID("polyglot-mvp")) == "1.0.0")
            let current = try #require(store.currentDirectory(installed.packID))
            #expect(try ContentPack(directory: current).allLessons().count == 3)
        }
    }
}
