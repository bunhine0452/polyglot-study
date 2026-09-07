import DesignSystem
import LearnCore
import SwiftUI
import Testing

@testable import DashboardFeature

/// 12편짜리 트랙 셋. 앱의 실제 팩 구성과 같은 모양이다.
private func mvpCatalog() -> [TrackDescriptor] {
    [
        TrackDescriptor(languageID: .python, name: "Python", lessonTotal: 12, hasContent: true),
        TrackDescriptor(languageID: .sql, name: "SQL", lessonTotal: 12, hasContent: true),
        TrackDescriptor(languageID: .swift, name: "Swift", lessonTotal: 12, hasContent: true),
        TrackDescriptor(languageID: LanguageID("rust"), name: "Rust", lessonTotal: 26, hasContent: false),
    ]
}

/// `nonisolated` — 모델이 이 클로저를 `@Sendable` 로 받는다. 모듈 기본 격리가 MainActor 라
/// (uiSettings) 표시하지 않으면 클로저 안에서 값 하나 읽는 것조차 경계를 넘지 못한다.
@Sendable private nonisolated func mvpDirectory(_ language: LanguageID) -> [LessonID] {
    switch language {
    case .python, .sql, .swift: (1...12).map { DashboardFixture.lessonID(language, $0) }
    default: []
    }
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
        #expect(python.lessons.allSatisfy { $0.ref.packID == DashboardFixture.packID })
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
        model.select(.swift)
        #expect(model.selectedTrack?.name == "Swift")
        // 준비 중 트랙은 고를 수 없다 — 빈 목록을 보여줄 이유가 없다.
        model.select(LanguageID("rust"))
        #expect(model.selectedTrack?.name == "Swift")
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
