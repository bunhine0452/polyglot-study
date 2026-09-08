public import LearnCore

public import Foundation

/// 앱이 **동시에 들고 있는 팩 전부**.
///
/// 팩 하나를 읽는 창구가 ``ContentPack`` 이라면, 이것은 여러 팩을 하나의 커리큘럼으로
/// 보는 창구다. MVP 는 트랙마다 팩이 하나씩이라(`polyglot-python`·`polyglot-sql`·
/// `polyglot-swift`) 어떤 질문이든 "어느 팩이냐" 를 먼저 풀어야 답이 나온다 — 그
/// 해석을 화면마다 따로 하면 대시보드가 가리킨 레슨과 조립 루트가 여는 레슨이 어긋난다.
///
/// **실패를 삼키지 않는다.** 팩 하나가 깨져도 나머지는 열되, 깨진 사실은 ``problems``
/// 에 남아 화면까지 올라간다. 조용히 빠진 트랙은 "아직 안 만든 트랙" 과 구별되지 않는다.
public struct PackLibrary: Sendable {
    /// 팩 하나를 열지 못한 사연. 사용자에게 그대로 보여줄 수 있는 한 줄이다.
    public struct Problem: Hashable, Sendable, CustomStringConvertible {
        /// 팩 id 를 알아냈으면 그것, 아니면 디렉터리 이름.
        public let source: String
        public let reason: String

        public init(source: String, reason: String) {
            self.source = source
            self.reason = reason
        }

        public var description: String { "\(source): \(reason)" }
    }

    /// packID 사전순. 화면 순서는 트랙 카탈로그가 정하므로 여기서는 안정성만 지킨다.
    public let packs: [ContentPack]
    public let problems: [Problem]

    public init(packs: [ContentPack], problems: [Problem] = []) {
        self.packs = packs.sorted { $0.manifest.packID.rawValue < $1.manifest.packID.rawValue }
        self.problems = problems
    }

    public var isEmpty: Bool { packs.isEmpty }

    public var packIDs: [PackID] { packs.map(\.manifest.packID) }

    public func pack(_ id: PackID) -> ContentPack? {
        packs.first { $0.manifest.packID == id }
    }

    /// 콘텐츠가 실제로 있는 언어들. 매니페스트의 `languages` 가 아니라 **레슨이 있는**
    /// 언어를 센다 — 선언은 계획이고 레슨은 사실이다.
    public var languages: [LanguageID] {
        var seen: Set<LanguageID> = []
        var ordered: [LanguageID] = []
        for pack in packs {
            for lesson in pack.manifest.lessons {
                for language in lesson.languages where seen.insert(language).inserted {
                    ordered.append(language)
                }
            }
        }
        return ordered
    }

    /// 이 언어의 레슨을 `order` 오름차순으로. 팩이 여럿이면 팩 순서 뒤에 order 순이다.
    ///
    /// 같은 언어를 두 팩이 담는 경우는 MVP 에 없지만 포맷이 금지하지 않는다. 그때
    /// 순번이 겹치므로 팩 경계를 먼저 지키는 편이 덜 놀랍다.
    public func lessons(for language: LanguageID) -> [LessonRef] {
        packs.flatMap { pack in
            pack.manifest.lessons(for: language)
                .sorted { $0.order < $1.order }
                .map { LessonRef(packID: pack.manifest.packID, lessonID: $0.stableID) }
        }
    }

    public func lessonCount(for language: LanguageID) -> Int {
        packs.reduce(0) { $0 + $1.manifest.lessons(for: language).count }
    }

    /// 이 팩의 레슨을 `order` 오름차순으로.
    ///
    /// 트랙이 팩 단위이므로({#track-descriptor-pack-id}) 트랙 목록의 정본은 이쪽이다.
    /// 언어로 모으면 같은 언어를 담은 두 팩(Rust 입문·알고리즘)의 레슨이 한 줄로 섞인다.
    public func lessons(inPack packID: PackID) -> [LessonRef] {
        guard let pack = pack(packID) else { return [] }
        return pack.manifest.lessons
            .sorted { $0.order < $1.order }
            .map { LessonRef(packID: packID, lessonID: $0.stableID) }
    }

    public func lessonCount(inPack packID: PackID) -> Int {
        pack(packID)?.manifest.lessons.count ?? 0
    }

    /// 매니페스트가 아는 레슨의 순번·제목. 모르는 조합이면 nil.
    public func entry(_ ref: LessonRef) -> PackManifest.LessonEntry? {
        pack(ref.packID)?.manifest.lesson(ref.lessonID)
    }
}

// MARK: - 디스크에서 열기

extension PackLibrary {
    /// `root` 바로 아래에서 `manifest.json` 을 가진 디렉터리를 찾는다. 이름 사전순.
    ///
    /// 재귀하지 않는다 — 팩 안에도 디렉터리가 있고, 깊이 들어가면 팩의 하위 디렉터리를
    /// 팩으로 착각할 길이 생긴다.
    public static func packDirectories(in root: URL) -> [URL] {
        let manager = FileManager.default
        let contents =
            (try? manager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])) ?? []
        return
            contents
            .filter { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { return false }
                let manifest = url.appendingPathComponent(PackLayout.manifestFileName)
                return manager.fileExists(atPath: manifest.path)
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 디렉터리 목록을 그대로 연다. 설치를 거치지 않는 **개발 경로**다.
    public static func open(directories: [URL]) -> PackLibrary {
        var packs: [ContentPack] = []
        var problems: [Problem] = []
        for directory in directories {
            do {
                packs.append(try ContentPack(directory: directory))
            } catch {
                problems.append(
                    Problem(source: directory.lastPathComponent, reason: "\(error)"))
            }
        }
        return PackLibrary(packs: packs, problems: problems)
    }

    /// 씨앗 팩들을 스토어에 설치하고 `current` 가 가리키는 것을 연다. **배포 경로**다.
    ///
    /// 같은 버전이 이미 설치돼 있으면 다시 설치하지 않는다 — 버전 디렉터리는 불변이라
    /// 재설치할 이유가 없고, 앱을 열 때마다 수십 MB 를 다시 쓰는 것은 그 자체로 결함이다.
    /// `current` 만 없으면(설치는 끝났는데 포인터를 옮기다 죽은 경우) 포인터를 세운다.
    ///
    /// 씨앗은 앱 번들의 읽기 전용 사본이고, 스토어는 쓰기 가능한 사용자 디렉터리다.
    /// 번들에서 **직접 읽지 않는** 이유는 업데이트 때문이다 — 팩은 앱과 따로 갱신되고,
    /// 갱신된 팩은 번들이 아니라 스토어에 온다. 읽는 곳이 하나여야 그 경로가 성립한다.
    public static func provision(
        seeds: [URL],
        into store: PackStore,
        appVersion: SemanticVersion? = nil
    ) -> PackLibrary {
        var packs: [ContentPack] = []
        var problems: [Problem] = []
        let installer = PackInstaller(store: store)

        for seed in seeds {
            let name = seed.lastPathComponent
            let manifest: PackManifest
            do {
                manifest = try ContentPack(directory: seed).manifest
            } catch {
                problems.append(Problem(source: name, reason: "\(error)"))
                continue
            }
            let packID = manifest.packID
            store.sweepStagingResidue(packID)

            do {
                if store.installedVersions(packID).contains(manifest.version) {
                    if store.currentVersion(packID) != manifest.version {
                        try installer.activate(packID: packID, version: manifest.version)
                    }
                } else {
                    try installer.install(from: seed, appVersion: appVersion, activate: true)
                }
            } catch {
                problems.append(Problem(source: packID.rawValue, reason: "설치 실패 — \(error)"))
                // 설치에 실패해도 이전 버전이 남아 있을 수 있다. 아래에서 열어 본다.
            }

            guard let directory = store.currentDirectory(packID) else {
                problems.append(
                    Problem(source: packID.rawValue, reason: "설치된 버전이 없습니다"))
                continue
            }
            do {
                packs.append(try ContentPack(directory: directory))
            } catch {
                problems.append(Problem(source: packID.rawValue, reason: "\(error)"))
            }
        }
        return PackLibrary(packs: packs, problems: problems)
    }
}
