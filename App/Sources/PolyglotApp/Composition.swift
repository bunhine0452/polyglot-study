internal import ContentKit
internal import DashboardFeature
internal import EditorFeature
internal import Foundation
internal import LearnCore
internal import LearnPersistence
internal import LessonFeature
internal import OnboardingFeature
internal import ReviewFeature

/// 앱의 **유일한** 조립 지점. 구체 타입을 아는 곳이 여기 하나뿐이라야
/// 화면들이 서로를 모른 채로 남는다.
///
/// 실패를 삼키지 않는다 — DB 를 못 열거나 팩을 못 읽으면 그 사실이 화면에 남아야 한다.
/// 조용히 빈 화면을 보여주면 "아직 아무것도 안 함" 과 구별되지 않는다.
@MainActor
final class Composition {
    let database: Result<LearnDatabase, any Error>
    /// 설치된 팩 전부. 비어 있을 수 있고, 그 사실은 `packFailureNotice` 가 말한다.
    let library: PackLibrary
    /// 팩을 어디서 읽었는지 한 줄. 개발 중 "왜 옛 레슨이 뜨지" 를 30초 안에 끝내려는 것이다.
    let packOrigin: String

    let onboarding = OnboardingModel()
    private(set) lazy var dashboard: DashboardModel = makeDashboard()

    init() {
        database = Result { try LearnDatabase.open() }
        (library, packOrigin) = Self.loadLibrary()
    }

    // MARK: - 콘텐츠 팩

    /// 팩을 찾는 곳은 셋이고, **순서가 계약이다.**
    ///
    /// 1. `POLYGLOT_PACK_PATH` — 팩 하나든 팩들이 담긴 디렉터리든 받는다. 콘텐츠를
    ///    고치면서 앱을 띄우는 경로다(설치를 거치지 않으므로 매니페스트 해시를 다시
    ///    굽지 않아도 된다).
    /// 2. 앱 번들 `Resources/Content/packs` — **배포 경로**. 여기 있는 것은 읽기 전용
    ///    씨앗이라 `PackStore` 에 설치하고 `current` 를 읽는다(`{#wire-pack-installer}`).
    ///    팩은 앱과 따로 갱신되므로 읽는 곳이 스토어 하나여야 그 경로가 성립한다.
    /// 3. 저장소의 `Content/packs` — 번들에 콘텐츠가 없을 때의 개발 폴백.
    private static func loadLibrary() -> (PackLibrary, String) {
        if let override = ProcessInfo.processInfo.environment["POLYGLOT_PACK_PATH"],
            !override.isEmpty
        {
            let url = URL(fileURLWithPath: override)
            return (PackLibrary.open(directories: packDirectories(at: url)), "POLYGLOT_PACK_PATH=\(override)")
        }

        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent(bundledPacksSubpath, isDirectory: true),
            case let seeds = PackLibrary.packDirectories(in: bundled), !seeds.isEmpty
        {
            let store = PackStore(root: packStoreRoot())
            let library = PackLibrary.provision(
                seeds: seeds, into: store, appVersion: appVersion())
            return (library, "설치된 팩 · \(store.root.path)")
        }

        for candidate in repositoryPackRoots() {
            let directories = PackLibrary.packDirectories(in: candidate)
            guard !directories.isEmpty else { continue }
            return (PackLibrary.open(directories: directories), "저장소 소스 · \(candidate.path)")
        }

        return (PackLibrary(packs: []), "찾지 못함")
    }

    /// 번들 안에서 팩들이 사는 자리. `App/Scripts/build-app.sh` 가 여기에 복사한다.
    static let bundledPacksSubpath = "Content/packs"

    /// 설치된 팩이 사는 곳. DB 와 같은 `Application Support/LearnKit` 아래에 둔다 —
    /// 앱이 소유한 상태가 두 군데로 갈리지 않게 한다.
    private static func packStoreRoot() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent(DatabaseLocation.directoryName, isDirectory: true)
            .appendingPathComponent("ContentPacks", isDirectory: true)
    }

    /// 경로가 팩 하나면 그것만, 아니면 그 아래의 팩들을.
    private static func packDirectories(at url: URL) -> [URL] {
        let manifest = url.appendingPathComponent(PackLayout.manifestFileName)
        if FileManager.default.fileExists(atPath: manifest.path) { return [url] }
        return PackLibrary.packDirectories(in: url)
    }

    /// 개발 실행 — 번들이 `App/.build/...` 안에 있으므로 저장소 루트로 거슬러 올라간다.
    private static func repositoryPackRoots() -> [URL] {
        var probe = Bundle.main.bundleURL
        var roots: [URL] = []
        for _ in 0..<8 {
            probe.deleteLastPathComponent()
            roots.append(probe.appendingPathComponent(bundledPacksSubpath, isDirectory: true))
        }
        return roots
    }

    /// `minAppVersion` 게이트에 넘길 이 앱의 버전. 못 읽으면 게이트를 걸지 않는다 —
    /// 버전을 지어내면 멀쩡한 팩이 거부된다.
    private static func appVersion() -> SemanticVersion? {
        guard let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return nil }
        return try? SemanticVersion(parsing: raw)
    }

    // MARK: - 화면 조립

    private func makeDashboard() -> DashboardModel {
        // DB 를 못 열었으면 인메모리 페이크로 떨어진다. 화면이 죽는 것보다 낫고,
        // 실패 사실은 `databaseFailureNotice` 가 따로 알린다.
        guard case .success(let db) = database else { return DashboardModel(catalog: catalog) }
        return DashboardModel(
            packIDs: library.packIDs,
            catalog: catalog,
            progressStore: db.lessonProgressStore,
            cardStateStore: db.cardStateStore,
            reviewLogStore: db.reviewLogStore,
            lessonMetadata: packLessonMetadata(),
            lessonDirectory: packLessonDirectory()
        )
    }

    /// 트랙 화면. 대시보드와 같은 팩·스토어·카탈로그를 본다 — 두 화면이 같은 트랙을
    /// 다르게 세면 안 된다.
    private(set) lazy var tracks: TracksModel = makeTracks()

    /// 연습장. 채점이 없으므로 DB 도 진도도 필요 없다 — 파일은 디스크에 직접 산다.
    ///
    /// SQL 연습장에는 **SQL 트랙의 시드를 그대로 물린다.** 학습자가 레슨에서 익힌
    /// 쇼핑몰 스키마를 연습장에서 다시 배우게 하지 않는다. 시드를 굽지 못하면 nil 이고,
    /// 그러면 `WITH` 절로 데이터를 직접 만드는 질의만 돈다(연습장 시작 코드가 그 사실을
    /// 주석으로 말한다).
    /// 시드는 **모델을 만들 때 한 번 굽고 값으로 잡는다.** 클로저가 `Composition` 을
    /// 붙들면 `@MainActor` 격리를 넘어야 하는데 공급자는 `@Sendable` 이라 넘지 못한다.
    /// `URL?` 하나만 캡처하면 그 문제가 사라진다.
    private(set) lazy var scratch: ScratchModel = {
        let seed = scratchSQLSeed()
        return ScratchModel(seedDatabaseProvider: { seed })
    }()

    /// SQL 연습장의 시드. 실패는 삼킨다 — 여기서는 시드가 없어도 화면이 성립한다
    /// (레슨의 과제와 다른 점이다. 저쪽은 참조 질의가 시드를 요구하므로 던진다).
    private func scratchSQLSeed() -> URL? {
        guard let pack = library.pack(PackID("polyglot-sql")) else { return nil }
        return try? seedDatabase(for: pack)
    }

    private func makeTracks() -> TracksModel {
        guard case .success(let db) = database else {
            return TracksModel(
                packIDs: library.packIDs,
                catalog: catalog,
                lessonMetadata: packLessonMetadata(),
                lessonDirectory: packLessonDirectory()
            )
        }
        return TracksModel(
            packIDs: library.packIDs,
            catalog: catalog,
            progressStore: db.lessonProgressStore,
            lessonMetadata: packLessonMetadata(),
            lessonDirectory: packLessonDirectory()
        )
    }

    func makeReview() throws -> ReviewModel {
        guard case .success(let db) = database else {
            throw CompositionError.databaseUnavailable
        }
        return try ReviewModel.live(database: db)
    }

    /// - Parameter onOpenEditor: 과제 블록의 "에디터에서 열기". 셸이 화면을 갈아 끼운다.
    func makeLesson(
        _ ref: LessonRef, onOpenEditor: @escaping (TaskBlock) -> Void
    ) throws -> LessonModel {
        guard let pack = library.pack(ref.packID) else {
            throw CompositionError.packUnavailable(ref.packID)
        }
        return try LessonModel(pack: pack, lessonID: ref.lessonID, onOpenEditor: onOpenEditor)
    }

    /// 레슨의 `@Task` 블록 하나를 에디터 화면으로. 헤더 문구는 이미 열려 있는 레슨에서
    /// 그대로 물려받는다 — 같은 레슨을 두 화면이 다르게 부르면 안 된다.
    func makeEditor(_ ref: LessonRef, lesson: LessonModel, task: TaskBlock) throws -> EditorModel {
        guard let pack = library.pack(ref.packID) else {
            throw CompositionError.packUnavailable(ref.packID)
        }
        let index = lesson.blocks.firstIndex { $0.kind == .task } ?? 0
        let database = task.language == .sql ? try seedDatabase(for: pack) : nil
        return EditorModel(
            task: try EditorTask.load(
                pack: pack,
                task: task,
                trackCaption: lesson.trackCaption,
                lessonTitle: lesson.content.title,
                blockIndex: index,
                blockCount: lesson.blocks.count,
                database: database
            )
        )
    }

    // MARK: - SQL 시드 데이터베이스

    /// 팩당 한 번만 굽고 실행 동안 재사용한다. 실행기가 매 실행마다 **복제본**을 쓰므로
    /// (`SQLDatabaseClone`) 여러 과제가 같은 파일을 봐도 서로를 오염시키지 않는다.
    ///
    /// 실패를 nil 로 삼키지 않는다 — 시드가 없으면 참조 질의가 `no such table` 로 죽고,
    /// 학습자에게는 자기 코드가 틀린 것처럼 보인다.
    private func seedDatabase(for pack: ContentPack) throws -> URL {
        let packID = pack.manifest.packID
        if let cached = seedDatabases[packID] { return cached }
        let directory = seedRoot.appendingPathComponent(packID.rawValue, isDirectory: true)
        guard let url = try PackSQLSeed.materialize(pack: pack, into: directory) else {
            throw CompositionError.sqlSeedMissing(packID)
        }
        seedDatabases[packID] = url
        return url
    }

    private var seedDatabases: [PackID: URL] = [:]

    /// 실행 하나짜리 임시 디렉터리. 앱이 죽으면 OS 가 치운다.
    private let seedRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("polyglot-seed-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)

    var databaseFailureNotice: String? {
        guard case .failure(let error) = database else { return nil }
        return "저장소를 열지 못했습니다 — 진도가 기록되지 않습니다: \(error)"
    }

    /// 팩을 하나도 못 읽었거나, 읽다 실패한 팩이 있으면 그 사실을 한 줄로.
    var packFailureNotice: String? {
        var lines = library.problems.map(\.description)
        if library.isEmpty {
            lines.insert(
                "콘텐츠 팩을 찾지 못했습니다 (\(packOrigin)). POLYGLOT_PACK_PATH 로 경로를 지정하십시오.",
                at: 0)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: - 팩에서 나오는 메타데이터

    /// 트랙 커리큘럼. 콘텐츠가 **실제로 있는** 트랙은 레슨 총수를 팩에서 읽고, 없는
    /// 트랙은 카탈로그의 계획값을 그대로 둔다.
    ///
    /// 총수를 팩에서 읽는 이유는 진도 칸이 거짓말을 하지 않게 하려는 것이다 — 팩에
    /// 12편이 들어 있는데 24칸을 그리면 다 끝낸 학습자가 반만 한 것으로 보인다.
    private lazy var catalog: [TrackDescriptor] = {
        let available = Set(library.languages)
        return TrackCatalog.all.map { descriptor in
            guard available.contains(descriptor.languageID) else {
                return TrackDescriptor(
                    languageID: descriptor.languageID,
                    name: descriptor.name,
                    lessonTotal: descriptor.lessonTotal,
                    hasContent: false
                )
            }
            return TrackDescriptor(
                languageID: descriptor.languageID,
                name: descriptor.name,
                lessonTotal: library.lessonCount(for: descriptor.languageID),
                hasContent: true
            )
        }
    }()

    /// 대시보드가 레슨 번호·제목을 팩에서 읽게 한다. 팩이 없으면 `nil` 을 돌려주고,
    /// 대시보드는 "제목 모름" 으로 정직하게 그린다.
    private func packLessonMetadata() -> (@Sendable (PackID, LessonID) -> DashboardModel.LessonMetadata?)? {
        guard !library.isEmpty else { return nil }
        // 사전으로 굳혀 넘긴다 — 클로저가 매 호출마다 배열을 훑으면 표 10행에서 반복된다.
        var byRef: [LessonRef: DashboardModel.LessonMetadata] = [:]
        for pack in library.packs {
            for entry in pack.manifest.lessons {
                let ref = LessonRef(packID: pack.manifest.packID, lessonID: entry.stableID)
                byRef[ref] = DashboardModel.LessonMetadata(ordinal: entry.order, title: entry.title)
            }
        }
        let frozen = byRef
        return { packID, lessonID in frozen[LessonRef(packID: packID, lessonID: lessonID)] }
    }

    private func packLessonDirectory() -> (@Sendable (LanguageID) -> [LessonRef])? {
        guard !library.isEmpty else { return nil }
        let byLanguage = Dictionary(
            uniqueKeysWithValues: library.languages.map { ($0, library.lessons(for: $0)) })
        return { byLanguage[$0] ?? [] }
    }
}

enum CompositionError: Error, CustomStringConvertible {
    case databaseUnavailable
    case packUnavailable(PackID)
    case sqlSeedMissing(PackID)

    var description: String {
        switch self {
        case .databaseUnavailable: "저장소를 열지 못해 이 화면을 열 수 없습니다."
        case .packUnavailable(let id): "콘텐츠 팩 \(id.rawValue) 이 없어 이 화면을 열 수 없습니다."
        case .sqlSeedMissing(let id):
            "\(id.rawValue) 에 SQL 시드 스크립트(assets/*.sql)가 없어 과제를 채점할 수 없습니다."
        }
    }
}
