import DesignSystem
import LearnCore
import SwiftUI
import Testing

@testable import DashboardFeature

/// 12편짜리 트랙 셋. 앱의 실제 팩 구성과 같은 모양이다.
private func mvpCatalog() -> [TrackDescriptor] {
    [
        track(.python, name: "Python", lessonTotal: 12, hasPack: true),
        track(.sql, name: "SQL", lessonTotal: 12, hasPack: true),
        track(.swift, name: "Swift", lessonTotal: 12, hasPack: true),
        track(LanguageID("rust"), name: "Rust", lessonTotal: 26, hasPack: false),
    ]
}

/// 언어와 1:1 인 트랙 하나. 팩 id 는 픽스처의 규칙(`polyglot-<lang>`)을 따른다.
private func track(
    _ languageID: LanguageID, name: String, lessonTotal: Int, hasPack: Bool
) -> TrackDescriptor {
    TrackDescriptor(
        trackID: TrackID(languageID.rawValue),
        languageID: languageID,
        packID: hasPack ? DashboardFixture.packID(for: languageID) : nil,
        name: name,
        lessonTotal: lessonTotal
    )
}

/// `nonisolated` — 모델이 이 클로저를 `@Sendable` 로 받는다. 모듈 기본 격리가 MainActor 라
/// (uiSettings) 표시하지 않으면 클로저 안에서 값 하나 읽는 것조차 경계를 넘지 못한다.
@Sendable private nonisolated func mvpDirectory(_ language: LanguageID) -> [LessonID] {
    switch language {
    case .python, .sql, .swift: (1...12).map { DashboardFixture.lessonID(language, $0) }
    default: []
    }
}

/// 픽스처는 팩 id 의 `polyglot-` 를 떼어 넘긴다 — `polyglot-rust` 는 "rust",
/// `polyglot-algorithms` 는 "algorithms" 로 도착한다.
@Sendable private nonisolated func twoTrackDirectory(_ key: LanguageID) -> [LessonID] {
    (1...12).map { DashboardFixture.lessonID(key, $0) }
}

@Sendable private nonisolated func mvpMetadata(
    _ packID: PackID, _ lessonID: LessonID
) -> DashboardModel.LessonMetadata? {
    // `<lang>-0007` 의 뒤 네 자리가 순번이다.
    guard let ordinal = Int(lessonID.rawValue.suffix(4)) else { return nil }
    return DashboardModel.LessonMetadata(ordinal: ordinal, title: "레슨 \(ordinal)")
}

@Suite("트랙 화면 · 레슨 목록")
struct TracksModelTests {

    @Test("트랙마다 레슨 12행이 순번 순으로 서고 제목은 팩에서 온다")
    func lessonsListedInOrder() async throws {
        let fixture = DashboardFixture()
        let model = fixture.tracksModel(
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        let python = try #require(model.tracks.first { $0.name == "Python" })
        #expect(python.lessons.count == 12)
        #expect(python.lessons.map(\.ordinal) == Array(1...12))
        #expect(python.lessons.first?.title == "레슨 1")
        #expect(python.lessons.first?.ordinalLabel == "01")
        #expect(python.lessons.last?.ordinalLabel == "12")
        // 레슨을 열려면 팩까지 알아야 한다.
        #expect(python.lessons.allSatisfy { $0.ref.packID == DashboardFixture.packID(for: .python) })
    }

    @Test("진도가 상태 열과 블록 칸에 그대로 나타난다")
    func progressShowsPerLesson() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 3, finishedBy: fixture.studyDay(daysAgo: 1))
        try await fixture.seedOpenLesson(.swift, ordinal: 4, completedBlocks: 2, at: fixture.studyDay(daysAgo: 0))
        let model = fixture.tracksModel(
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        let swift = try #require(model.tracks.first { $0.name == "Swift" })
        #expect(swift.completedLessons == 3)
        #expect(swift.progressLabel == "3 / 12")
        #expect(swift.lessons[0].statusLabel == "완료")
        #expect(swift.lessons[3].status == .inProgress)
        #expect(swift.lessons[3].statusLabel == "블록 3 / 6")
        #expect(swift.lessons[4].statusLabel == "아직 안 함")

        // **자이가르닉** — 진행 중 블록은 채우지 않고 빈 윤곽 칸으로 남는다.
        let cells = swift.lessons[3].blockCells
        #expect(cells.count == 6)
        #expect(cells.prefix(2).allSatisfy { $0 == .done })
        #expect(cells[2] == .current)
        #expect(cells.suffix(3).allSatisfy { $0 == .future })
    }

    @Test("선택은 콘텐츠가 있는 첫 트랙에서 시작하고 준비 중 트랙으로는 옮겨가지 않는다")
    func selectionSkipsPendingTracks() async throws {
        let fixture = DashboardFixture()
        let model = fixture.tracksModel(
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        #expect(model.selectedTrack?.name == "Python")
        model.select(TrackID("swift"))
        #expect(model.selectedTrack?.name == "Swift")
        // 준비 중 트랙은 고를 수 없다 — 빈 목록을 보여줄 이유가 없다.
        model.select(TrackID("rust"))
        #expect(model.selectedTrack?.name == "Swift")
    }

    /// {#track-descriptor-pack-id} 의 완료 기준. 알고리즘 트랙이 성립하려면 이것이 참이어야
    /// 한다 — 같은 `rustc` 를 쓰는 두 트랙이 목록에 따로 서고 진도를 따로 센다.
    @Test("한 언어에 트랙이 둘이면 따로 서고 진도가 섞이지 않는다")
    func twoTracksShareALanguageWithoutSharingProgress() async throws {
        let intro = PackID("polyglot-rust")
        let algorithms = PackID("polyglot-algorithms")
        let catalog = [
            TrackDescriptor(
                trackID: TrackID("rust"), languageID: .rust, packID: intro,
                name: "Rust 입문", lessonTotal: 12),
            TrackDescriptor(
                trackID: TrackID("algorithms"), languageID: .rust, packID: algorithms,
                name: "알고리즘", lessonTotal: 12),
        ]

        let fixture = DashboardFixture()
        // 입문만 3편 끝냈다. 알고리즘은 아직 0편이다.
        try await fixture.seedCompletedLessons(
            .rust, count: 3, finishedBy: fixture.studyDay(daysAgo: 1), pack: intro)

        let model = fixture.tracksModel(
            catalog: catalog, lessonMetadata: mvpMetadata, lessonDirectory: twoTrackDirectory)
        await model.load()

        // 목록에 두 줄이 선다 — 언어가 같아도 트랙은 다르다.
        #expect(model.tracks.map(\.name) == ["Rust 입문", "알고리즘"])
        #expect(model.tracks.map(\.id) == ["rust", "algorithms"])
        #expect(model.tracks.allSatisfy { $0.languageID == .rust })

        let introTrack = try #require(model.tracks.first { $0.id == "rust" })
        let algoTrack = try #require(model.tracks.first { $0.id == "algorithms" })
        #expect(introTrack.completedLessons == 3)
        // 여기가 핵심이다. 언어로 진도를 묶으면 이 값이 3 이 된다.
        #expect(algoTrack.completedLessons == 0)
        #expect(introTrack.lessons.allSatisfy { $0.ref.packID == intro })
        #expect(algoTrack.lessons.allSatisfy { $0.ref.packID == algorithms })

        // 선택도 트랙 단위다 — 언어가 같아도 서로를 덮지 않는다.
        model.select(TrackID("algorithms"))
        #expect(model.selectedTrack?.name == "알고리즘")
    }

    @Test("준비 중 트랙은 레슨이 0행이고 총수는 계획값으로 말한다")
    func pendingTrackStatesItsPlan() async throws {
        let fixture = DashboardFixture()
        let model = fixture.tracksModel(
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        let rust = try #require(model.tracks.first { $0.name == "Rust" })
        #expect(rust.lessons.isEmpty)
        #expect(rust.progressLabel == "26 레슨")
        #expect(rust.caption == "준비 중")
    }

    @Test("진도 읽기 실패를 '아직 안 함' 으로 그리지 않는다")
    func readFailureIsNotEmptiness() async throws {
        let fixture = DashboardFixture()
        let model = fixture.tracksModel(
            progressStore: FailingLessonProgressStore(),
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        #expect(model.lastLoadFailed)
        // 실패 전 상태(빈 목록)를 그대로 둔다 — 12행을 "아직 안 함" 으로 그리면 거짓말이다.
        #expect(model.tracks.allSatisfy { $0.lessons.isEmpty })
    }

    @Test("두 단 화면이 실제로 비트맵까지 간다")
    @MainActor
    func screenRendersToBitmap() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.python, count: 5, finishedBy: fixture.studyDay(daysAgo: 1))
        let model = fixture.tracksModel(
            catalog: mvpCatalog(), lessonMetadata: mvpMetadata, lessonDirectory: mvpDirectory)
        await model.load()

        let renderer = ImageRenderer(content: TracksView(model: model).frame(width: 1128, height: 720))
        #expect(renderer.nsImage != nil)
        // 비트맵만 보면 빈 화면이 그려져도 통과한다 — 렌더 직전 상태를 함께 못 박는다.
        #expect(model.selectedTrack?.lessons.count == 12)
        #expect(model.selectedTrack?.progressLabel == "5 / 12")
    }
}
