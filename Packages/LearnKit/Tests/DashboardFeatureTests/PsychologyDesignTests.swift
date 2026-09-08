import DesignSystem
import Foundation
import LearnCore
import Testing

@testable import DashboardFeature

/// 이 앱의 차별점 세 가지. 디자인에 이미 들어 있고, 여기서 코드로 못 박는다.

@Suite("심리 설계 · 부여된 진도 효과")
struct EndowedProgressTests {
    @Test("트랙을 열면 0% 가 아니라 첫 칸이 이미 채워진 상태로 보인다")
    func openingATrackCreditsOrientation() async throws {
        let fixture = DashboardFixture()
        // 사용자는 아직 어떤 레슨도 끝내지 않았다 — 02 를 열어 두 블록만 했다.
        try await fixture.seedOpenLesson(.python, ordinal: 2, completedBlocks: 2, at: fixture.studyDay(daysAgo: 0))
        let model = fixture.model()
        await model.load()

        let python = try #require(model.rows.first { $0.name == "Python" })
        #expect(python.recordedLessons == 0)
        #expect(python.completedLessons == 1)
        #expect(python.isEndowed)
        #expect(python.progressLabel == "1 / 24")
        #expect(python.cells[0] == .done)
        #expect(python.cells[1] == .current)
        #expect(python.cells.dropFirst(2).allSatisfy { $0 == .future })
        #expect(python.stage == .justStarted)
        #expect(python.stage.label == "방금 시작")
    }

    @Test("열지 않은 트랙에는 부여하지 않는다 — 부여는 거짓말이 아니어야 한다")
    func unopenedTrackGetsNothing() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedOpenLesson(.python, ordinal: 2, completedBlocks: 2, at: fixture.studyDay(daysAgo: 0))
        let model = fixture.model()
        await model.load()

        let swift = try #require(model.rows.first { $0.name == "Swift" })
        #expect(swift.completedLessons == 0)
        #expect(!swift.isEndowed)
        #expect(swift.stage == .notStarted)
        #expect(swift.cells.allSatisfy { $0 == .future })
    }

    @Test("이미 완료한 레슨이 있으면 부여분이 이중 계산되지 않는다")
    func endowmentIsNotAddedTwice() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.sql, count: 12, finishedBy: fixture.studyDay(daysAgo: 2))
        let model = fixture.model()
        await model.load()

        let sql = try #require(model.rows.first { $0.name == "SQL" })
        #expect(sql.recordedLessons == 12)
        #expect(sql.completedLessons == 12)
        #expect(!sql.isEndowed)
        #expect(sql.progressLabel == "12 / 22")
        #expect(sql.stage == .active)
    }

    @Test("부여된 진도는 그 사실을 화면에 적는다 — 조용히 채우지 않는다")
    func endowmentIsStatedOnScreen() async throws {
        // 디자인의 Python 행 그대로: 1 / 24, 이어서는 "02 변수와 타입",
        // 그 아래 "01 오리엔테이션은 완료로 기록됨".
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.python, count: 1, finishedBy: fixture.studyDay(daysAgo: 0))
        let model = fixture.model(
            lessonMetadata: { _, lessonID in
                lessonID == DashboardFixture.lessonID(.python, 2)
                    ? DashboardModel.LessonMetadata(ordinal: 2, title: "변수와 타입")
                    : nil
            },
            lessonDirectory: { language in
                language == .python ? (1...24).map { DashboardFixture.lessonID(.python, $0) } : []
            }
        )
        await model.load()

        let python = try #require(model.rows.first { $0.name == "Python" })
        #expect(python.progressLabel == "1 / 24")
        #expect(python.orientationCredit)
        #expect(python.resume?.headline == "02 변수와 타입")
        #expect(python.resumeCaption == "01 오리엔테이션은 완료로 기록됨")
    }

    @Test("화면이 부여한 칸도 같은 문구를 낸다 — 기록된 것과 구분되게 숨기지 않는다")
    func creditedWithoutARecordSaysTheSameThing() async throws {
        let fixture = DashboardFixture()
        // 저장소에 완료 기록이 하나도 없다. 트랙을 열기만 한 상태.
        try await fixture.stores.lessonProgress.upsert(
            LessonProgress(
                packID: DashboardFixture.packID(for: .python),
                lessonID: DashboardFixture.lessonID(.python, 1),
                languageID: .python,
                status: .skipped,
                lastActivityAt: fixture.studyDay(daysAgo: 0)
            )
        )
        let model = fixture.model()
        await model.load()

        let python = try #require(model.rows.first { $0.name == "Python" })
        #expect(python.recordedLessons == 0)
        #expect(python.isEndowed)
        #expect(python.orientationCredit)
        #expect(python.resumeCaption == "01 오리엔테이션은 완료로 기록됨")
    }

    @Test("멈춘 레슨이 있으면 그 자리를 말한다 — 오리엔테이션 문구가 덮지 않는다")
    func openLessonCaptionWins() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedOpenLesson(.python, ordinal: 2, completedBlocks: 2, at: fixture.studyDay(daysAgo: 0))
        let model = fixture.model()
        await model.load()

        let python = try #require(model.rows.first { $0.name == "Python" })
        #expect(python.isEndowed)
        #expect(!python.orientationCredit)
        #expect(python.resumeCaption == "블록 3 / 6 · 빈칸")
    }
}

@Suite("심리 설계 · 자이가르닉 효과")
struct ZeigarnikTests {
    @Test("멈춘 레슨이 화면 최상단 카드가 된다")
    func openLessonRisesToTheTop() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 6, finishedBy: fixture.studyDay(daysAgo: 2))
        try await fixture.seedOpenLesson(.swift, ordinal: 7, completedBlocks: 3, at: fixture.studyDay(daysAgo: 0))
        try await fixture.seedOpenLesson(.sql, ordinal: 12, completedBlocks: 0, at: fixture.studyDay(daysAgo: 4))

        let model = fixture.model(lessonMetadata: { _, lessonID in
            lessonID == DashboardFixture.lessonID(.swift, 7)
                ? DashboardModel.LessonMetadata(ordinal: 7, title: "값 타입과 참조 타입")
                : nil
        })
        await model.load()

        let open = try #require(model.openLesson)
        #expect(open.trackName == "Swift")
        #expect(open.lessonTitle == "값 타입과 참조 타입")
        #expect(open.lessonOrdinal == 7)
        #expect(open.lessonTotal == 24)
        #expect(open.headline == "07 값 타입과 참조 타입")
        #expect(open.blockIndex == 3)
        #expect(open.blockName == "테스트 과제")
        #expect(open.blockLine == "블록 4 / 6 · 테스트 과제")
        #expect(open.remainingBlocks == 3)
        #expect(open.remainingMinutes == 15)
    }

    @Test("진행 중 블록은 채우지 않고 빈 윤곽 칸으로 남는다 — 그 칸이 긴장이다")
    func inProgressBlockStaysAnOutline() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedOpenLesson(.swift, ordinal: 7, completedBlocks: 3, at: fixture.studyDay(daysAgo: 0))
        let model = fixture.model()
        await model.load()

        let open = try #require(model.openLesson)
        #expect(open.blockCells == [.done, .done, .done, .current, .future, .future])
        #expect(open.blockCells[open.blockIndex] == .current)
        #expect(open.completedBlocks == 3)
    }

    @Test("열린 레슨이 없으면 없다고 한다 — 없는 긴장을 지어내지 않는다")
    func noOpenLessonMeansNil() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 4, finishedBy: fixture.studyDay(daysAgo: 1))
        let model = fixture.model()
        await model.load()

        #expect(model.openLesson == nil)
    }

    @Test("아직 열지 않은 '다음 레슨' 은 최상단 카드가 되지 않는다")
    func nextLessonIsNotAnOpenLesson() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.python, count: 1, finishedBy: fixture.studyDay(daysAgo: 1))
        let model = fixture.model(
            lessonMetadata: { _, lessonID in
                lessonID == DashboardFixture.lessonID(.python, 2)
                    ? DashboardModel.LessonMetadata(ordinal: 2, title: "변수와 타입")
                    : nil
            },
            lessonDirectory: { language in
                language == .python ? (1...24).map { DashboardFixture.lessonID(.python, $0) } : []
            }
        )
        await model.load()

        let python = try #require(model.rows.first { $0.name == "Python" })
        let resume = try #require(python.resume)
        #expect(resume.kind == .next)
        #expect(resume.headline == "02 변수와 타입")
        #expect(resume.blockLine == nil)
        // 다음 레슨은 미완성 긴장이 아니다 — 카드는 비어 있어야 한다.
        #expect(model.openLesson == nil)
    }

    @Test("멈춘 레슨이 여럿이면 가장 최근에 멈춘 것 하나만 올라온다")
    func mostRecentOpenLessonWins() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedOpenLesson(.python, ordinal: 3, completedBlocks: 1, at: fixture.studyDay(daysAgo: 5))
        try await fixture.seedOpenLesson(.sql, ordinal: 9, completedBlocks: 2, at: fixture.studyDay(daysAgo: 0))
        try await fixture.seedOpenLesson(.swift, ordinal: 4, completedBlocks: 5, at: fixture.studyDay(daysAgo: 2))
        let model = fixture.model()
        await model.load()

        #expect(model.openLesson?.trackName == "SQL")
        #expect(model.rows.compactMap(\.resume).count(where: { $0.isOpen }) == 3)
    }
}

@Suite("심리 설계 · 축적 프레이밍")
struct AccumulationFramingTests {
    @Test("스트릭은 '14일째' 로만 쓴다")
    func streakReadsAsAccumulation() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedReviewStreak(days: Array(0..<14))
        let model = fixture.model()
        await model.load()

        #expect(model.review.streakDays == 14)
        #expect(model.review.streakLabel == "14일째")
    }

    @Test("오늘 아직 복습을 안 했어도 쌓인 날수는 그대로 서 있는다")
    func todaysGapDoesNotResetTheCount() {
        // 어제까지 14일 연속. 오늘은 아직 안 했다.
        let days = Set((1...14).map { -$0 })
        #expect(DashboardModel.streak(days: days, today: 0) == 14)

        // 오늘 하면 15일째가 된다.
        #expect(DashboardModel.streak(days: days.union([0]), today: 0) == 15)

        // 이틀을 건너뛰면 그때 비로소 0 이다. 경고가 아니라 사실이다.
        #expect(DashboardModel.streak(days: days, today: 1) == 0)
    }

    @Test("연속일수가 0 이면 라벨을 내지 않는다 — '0일째' 는 질책이다")
    func zeroStreakShowsNothing() async throws {
        let fixture = DashboardFixture()
        let model = fixture.model()
        await model.load()

        #expect(model.review.streakDays == 0)
        #expect(model.review.streakLabel == nil)
    }

    @Test("중간에 끊긴 이력은 최근 구간만 센다")
    func brokenStreakCountsOnlyTheRecentRun() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedReviewStreak(days: [0, 1, 2, 5, 6, 7, 8])
        let model = fixture.model()
        await model.load()

        #expect(model.review.streakDays == 3)
    }

    @Test("같은 날 여러 번 복습해도 하루다")
    func sameDayCountsOnce() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedReviewStreak(days: [0, 0, 0, 1, 1])
        let model = fixture.model()
        await model.load()

        #expect(model.review.streakDays == 2)
    }

    @Test("화면 문구에 위협·만료 표현이 0건이다")
    func noThreatWordingInSource() throws {
        // 스트릭을 압박 장치로 되돌리는 가장 쉬운 길은 문구 한 줄이다. 타입으로는 막을 수
        // 없으니 소스를 직접 읽는다 — `DesignSystemTests.PrimitivesSealingTests` 와 같은 방식.
        let banned = [
            "끊깁니다", "끊어집니다", "끊긴", "사라집니다", "잃게", "놓치면",
            "마감", "만료", "남은 시간", "지금 안 하면", "내일까지",
        ]
        var hits: [String] = []
        for file in try DashboardSources.swiftFiles {
            for (line, text) in try DashboardSources.codeLines(of: file) {
                for needle in banned where text.contains(needle) {
                    hits.append("\(file.lastPathComponent):\(line) — \(needle)")
                }
            }
        }
        #expect(hits.isEmpty, "위협 문구 발견:\n\(hits.joined(separator: "\n"))")
    }

    @Test("스트릭 표현은 '일째' 하나뿐이다 — 다른 세는 말이 끼어들지 않았다")
    func onlyOneStreakPhrasing() {
        for days in 1...400 {
            let summary = ReviewSummary(perTrack: [], total: 0, streakDays: days)
            #expect(summary.streakLabel == "\(days)일째")
        }
    }
}

/// 대시보드 소스 트리를 읽는 헬퍼. 주석은 제외한다 — 규칙을 설명하려면 금지어를
/// 적을 수밖에 없기 때문이다.
enum DashboardSources {
    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)  // .../Tests/DashboardFeatureTests/PsychologyDesignTests.swift
            .deletingLastPathComponent() // .../Tests/DashboardFeatureTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // .../LearnKit
            .appendingPathComponent("Sources/Features/DashboardFeature")
    }

    static var swiftFiles: [URL] {
        get throws {
            var found: [URL] = []
            var stack = [sourceRoot]
            while let directory = stack.popLast() {
                for entry in try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: [.isDirectoryKey]
                ) {
                    if (try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        stack.append(entry)
                    } else if entry.pathExtension == "swift" {
                        found.append(entry)
                    }
                }
            }
            return found.sorted { $0.path < $1.path }
        }
    }

    static func codeLines(of file: URL) throws -> [(line: Int, text: String)] {
        let source = try String(contentsOf: file, encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: String($0.element)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }
}

@Suite("대시보드 · 소스 트리")
struct DashboardSourceTreeTests {
    @Test("소스 경로 계산이 맞다 — grep 테스트가 빈 디렉터리를 훑고 통과하지 않게")
    func sourceRootIsWhereWeThink() throws {
        let names = Set(try DashboardSources.swiftFiles.map(\.lastPathComponent))
        for required in [
            "DashboardModel.swift", "DashboardView.swift", "DashboardPresentation.swift",
            "TrackCatalog.swift", "TrackTable.swift", "OpenLessonCard.swift", "TodayReviewCard.swift",
        ] {
            #expect(names.contains(required), "\(required) 를 못 찾았다")
        }
        #expect(!names.contains("Placeholder.swift"))
    }

    @Test("화면 코드에 색 리터럴도 LazyHGrid 도 없다")
    func noColorLiteralsNoLazyGrid() throws {
        // 색은 전부 `Palette` 를 거쳐야 하고, 진도 칸은 지연 레이아웃이면 안 된다
        // (`{#progress-cell-states}` — 스크롤 밖 칸의 2px 간격이 보장되지 않는다).
        let banned = ["Color(hex:", "Color(red:", "Color(.sRGB", "LazyHGrid", "LazyVGrid", "cornerRadius"]
        var hits: [String] = []
        for file in try DashboardSources.swiftFiles {
            for (line, text) in try DashboardSources.codeLines(of: file) {
                for needle in banned where text.contains(needle) {
                    hits.append("\(file.lastPathComponent):\(line) — \(needle)")
                }
            }
        }
        #expect(hits.isEmpty, "금지 표현 발견:\n\(hits.joined(separator: "\n"))")
    }
}
