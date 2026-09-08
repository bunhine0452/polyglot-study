public import ContentKit
public import Foundation
public import LearnCore

/// 생성한 레슨을 팩 디렉터리에 놓고, 놓은 것이 실제로 팩인지 확인한다.
///
/// 마지막 단계가 요점이다. 파일을 쓰고 끝내면 "구조 단계를 통과할 것이다" 는 추측으로
/// 남는다. 여기서는 쓴 직후 ``ContentPack`` 을 열어 매니페스트 디코딩·sha256 대조·참조
/// 파일 존재·디렉티브 파싱을 전부 돌린다 — `packtool` 의 구조·문법 단계와 **같은 코드**다.
/// 그래서 `lessongen` 이 성공으로 끝났다는 것은 그 두 단계를 이미 지났다는 뜻이다.
/// `FileManager` 를 들고 있어 `Sendable` 이 아니다 — 의도다. 팩 디렉터리에 동시에 쓰는
/// 경로를 만들면 매니페스트 재계산이 서로를 덮어쓴다. 팬아웃은 **생성**까지이고, 쓰기는
/// 결과를 모은 뒤 한 번에 한다.
public struct PackWriter {
    /// 새 팩을 만들 때 쓰는 머리말. 기존 팩에 얹을 때는 디스크의 값이 이긴다.
    public struct Header: Sendable, Hashable {
        public var packID: PackID
        public var displayName: String
        public var version: String
        public var minAppVersion: String
        /// `YYYY-MM-DDTHH:MM:SSZ`. **입력이다** — 여기서 현재 시각을 읽으면 두 번 구운
        /// 팩의 바이트가 달라진다. 스펙상 출처는 git commit date 다.
        public var generatedAt: String

        public init(
            packID: PackID,
            displayName: String,
            version: String = "0.1.0",
            minAppVersion: String = "0.1.0",
            generatedAt: String
        ) {
            self.packID = packID
            self.displayName = displayName
            self.version = version
            self.minAppVersion = minAppVersion
            self.generatedAt = generatedAt
        }
    }

    public let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    /// 디스크에 이미 매니페스트가 있으면 읽는다.
    public func existingManifest() throws -> PackManifest? {
        let url = directory.appendingPathComponent(PackLayout.manifestFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try CanonicalJSON.decode(PackManifest.self, from: try Data(contentsOf: url))
    }

    /// 쓰기 결과.
    public struct WriteResult: Sendable {
        public var manifest: PackManifest
        /// 팩에 없는 레슨을 가리켜 떨어져 나간 선수 관계.
        ///
        /// 비어 있지 않다는 것은 **팩이 아직 완성이 아니라는 신호**다. 호출자가 반드시
        /// 사람에게 보여야 한다.
        public var droppedPrerequisites: [DroppedPrerequisite]
    }

    public struct DroppedPrerequisite: Hashable, Sendable {
        public var lesson: LessonID
        public var prerequisite: LessonID
    }

    /// 레슨들을 쓰고 매니페스트·잠금을 다시 굽는다. 같은 stableID 는 덮어쓴다.
    ///
    /// - Parameter removing: 팩에서 빼야 할 레슨. 격리(`{#lessongen-quarantine}`)가 쓴다.
    @discardableResult
    public func write(
        lessons: [GeneratedLesson],
        removing removed: Set<LessonID> = [],
        header: Header
    ) throws -> WriteResult {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var entries: [LessonID: PackManifest.LessonEntry] = [:]
        if let existing = try existingManifest() {
            for entry in existing.lessons { entries[entry.stableID] = entry }
        }

        for id in removed {
            guard let entry = entries.removeValue(forKey: id) else { continue }
            try removeFiles(ofLessonAt: entry)
        }

        for lesson in lessons {
            for file in lesson.files {
                try writeFile(at: file.path, contents: file.contents)
            }
            entries[lesson.stableID] = lesson.manifestEntry
        }

        // 팩에 없는 레슨을 가리키는 선수 관계는 매니페스트를 통째로 무효로 만든다
        // (`.unknownPrerequisite`). 실패한 레슨 한 편 때문에 성공한 나머지를 못 쓰게
        // 두는 대신, 매달린 참조를 떼고 **무엇을 뗐는지 호출자에게 돌려준다.**
        // 관계의 원본은 개요 파일이라 그 레슨을 다시 만들면 복원된다.
        var dropped: [DroppedPrerequisite] = []
        let present = Set(entries.keys)
        for (id, entry) in entries {
            let kept = entry.prerequisites.filter { present.contains($0) }
            guard kept.count != entry.prerequisites.count else { continue }
            for missing in entry.prerequisites where !present.contains(missing) {
                dropped.append(DroppedPrerequisite(lesson: id, prerequisite: missing))
            }
            entries[id]?.prerequisites = kept
        }

        let ordered = entries.values.sorted {
            // 정렬 키의 언어는 대표 언어다 — 목록의 자리를 정하는 것뿐이라 하나면 된다.
            ($0.primaryLanguage.rawValue, $0.order, $0.stableID.rawValue)
                < ($1.primaryLanguage.rawValue, $1.order, $1.stableID.rawValue)
        }
        var manifest = PackManifest(
            packID: header.packID,
            displayName: header.displayName,
            version: header.version,
            minAppVersion: header.minAppVersion,
            generatedAt: header.generatedAt,
            languages: orderedLanguages(of: ordered),
            lessons: ordered,
            files: [])

        // 잠금은 매니페스트에서 파생된다. 먼저 써야 `files` 스캔이 그것까지 센다.
        try PackManifestBuilder.writeLock(StableIDLock.from(manifest: manifest), to: directory)
        manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: directory)
        try manifest.validate()
        try PackManifestBuilder.write(manifest, to: directory)
        return WriteResult(
            manifest: manifest,
            droppedPrerequisites: dropped.sorted {
                ($0.lesson.rawValue, $0.prerequisite.rawValue)
                    < ($1.lesson.rawValue, $1.prerequisite.rawValue)
            })
    }

    /// 쓴 것이 실제로 팩인가. `packtool` 의 구조·문법 단계와 같은 검사다.
    ///
    /// - Returns: 파싱된 레슨 전량. 호출자가 블록 수를 세어 볼 수 있다.
    @discardableResult
    public func verify() throws -> [LessonDocument] {
        let pack = try ContentPack(directory: directory)
        try pack.verifyChecksums()
        try pack.checkStableIDLock()
        return try pack.validateReferences()
    }

    // MARK: - 파일

    private func writeFile(at path: PackRelativePath, contents: String) throws {
        let url = directory.appendingPathComponent(path.rawValue)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url, options: .atomic)
    }

    /// 레슨과 그 사이드카를 지운다. **격리는 흔적을 남기지 않아야 한다** — 등록되지 않은
    /// 파일이 디스크에 남으면 설치가 양방향 대조에서 거부한다.
    private func removeFiles(ofLessonAt entry: PackManifest.LessonEntry) throws {
        // 생성기가 만든 레슨은 언어 하나짜리다 — 파일 경로도 그 언어로 정해진다.
        guard let language = LessonLanguage(entry.primaryLanguage) else { return }
        let paths = try LessonPaths(stableID: entry.stableID, language: language)
        for path in paths.all {
            let url = directory.appendingPathComponent(path.rawValue)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    /// 매니페스트의 `languages`. 등장 순서가 아니라 사전순 — 두 번 구운 결과가 같아야 한다.
    private func orderedLanguages(of lessons: [PackManifest.LessonEntry]) -> [LanguageID] {
        var seen: Set<String> = []
        for lesson in lessons {
            for language in lesson.languages { seen.insert(language.rawValue) }
        }
        return seen.sorted().map { LanguageID($0) }
    }
}
