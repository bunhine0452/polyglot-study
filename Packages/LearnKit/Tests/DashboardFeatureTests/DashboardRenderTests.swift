import LanguageKit
import LearnCore
import SwiftUI
import Testing

@testable import DashboardFeature

/// 뷰 계층이 실제로 조립되는지만 본다. 픽셀을 단언하지 않는다 — 색·간격은
/// `DesignSystemTests` 가 토큰 차원에서 이미 고정했고, 여기서 다시 재면 폰트 폴백 때문에
/// 기계마다 다른 결과가 나온다. 잡으려는 것은 "모델은 맞는데 화면이 안 그려진다" 하나다.
@Suite("대시보드 · 렌더 조립")
struct DashboardRenderTests {
    @Test("10행 표와 2단 카드가 실제로 비트맵까지 간다")
    func screenRendersToBitmap() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 6, finishedBy: fixture.studyDay(daysAgo: 2))
        try await fixture.seedOpenLesson(.swift, ordinal: 7, completedBlocks: 3, at: fixture.studyDay(daysAgo: 0))
        try await fixture.seedCompletedLessons(.sql, count: 11, finishedBy: fixture.studyDay(daysAgo: 1))
        try await fixture.seedOpenLesson(.sql, ordinal: 12, completedBlocks: 0, at: fixture.studyDay(daysAgo: 1))
        try await fixture.seedCompletedLessons(.python, count: 1, finishedBy: fixture.studyDay(daysAgo: 3))
        try await fixture.seedDueCards(.swift, count: 7)
        try await fixture.seedDueCards(.sql, count: 4)
        try await fixture.seedDueCards(.python, count: 1)
        try await fixture.seedReviewStreak(days: Array(0..<14))

        let model = fixture.model(toolchainStatus: { language in
            func ready(_ tool: String, _ version: String) -> TrackToolchainStatus {
                .probed(tool: tool, .ready(version: version, executablePath: "/usr/bin/\(tool)"))
            }
            switch language.rawValue {
            case "swift": return ready("swiftc", "6.3.3")
            case "sql": return ready("sqlite3", "3.51.1")
            case "python": return ready("python3", "3.14.3")
            case "go", "typescript":
                return .probed(
                    tool: language.rawValue, .missing(installHint: "brew install \(language.rawValue)"))
            case "java":
                return .probed(tool: "java", .stub(path: "/usr/bin/java", reason: "런타임 없음"))
            default: return .unknown
            }
        })
        await model.load()

        // 아트보드 1440 에서 사이드바 232 와 좌우 여백 80 을 뺀 본문 폭.
        let renderer = ImageRenderer(content: DashboardView(model: model).frame(width: 1128, height: 720))
        let image = try #require(renderer.nsImage)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)

        // 렌더 직전 상태가 디자인의 그 화면인지 함께 못 박는다 — 비트맵만 보면
        // 빈 화면이 그려져도 통과한다.
        #expect(model.rows.map(\.name).prefix(3) == ["Swift", "SQL", "Python"])
        #expect(model.openLesson?.trackName == "Swift")
        #expect(model.review.breakdownLine == "Swift 7 · SQL 4 · Python 1 · 약 8분")
        #expect(model.review.streakLabel == "14일째")
    }

    @Test("빈 스토어에서도 화면이 조립된다 — 빈 상태가 크래시 경로가 아니다")
    func emptyScreenRenders() async throws {
        let model = DashboardFixture().model()
        await model.load()

        let renderer = ImageRenderer(content: DashboardView(model: model).frame(width: 1128, height: 720))
        #expect(renderer.nsImage != nil)
        #expect(model.openLesson == nil)
        #expect(model.review.total == 0)
    }
}
