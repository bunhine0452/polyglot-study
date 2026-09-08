import DesignSystem
import LanguageKit
import LearnCore
import Testing

@testable import DashboardFeature

@Suite("대시보드 · 트랙 표")
struct DashboardTrackTableTests {
    @Test("10트랙이고 진도 칸 수가 레슨 총수와 정확히 일치한다 `{#screen-dashboard}`")
    func cellCountMatchesLessonTotal() async throws {
        let fixture = DashboardFixture()
        let model = fixture.model()
        await model.load()

        #expect(model.rows.count == 10)
        let totals = Dictionary(
            uniqueKeysWithValues: model.rows.map { ($0.name, $0.cells.count) }
        )
        #expect(
            totals == [
                "Python": 24, "SQL": 22, "Swift": 24, "Rust": 26, "C++": 26,
                "Go": 20, "Java": 24, "Next.js": 18, "TypeScript": 24, "Assembly": 20,
            ]
        )
        // 총수와 칸 수가 따로 놀지 않는다 — 한쪽만 고쳐도 여기서 깨진다.
        #expect(model.rows.allSatisfy { $0.cells.count == $0.lessonTotal })
    }

    @Test("활성 5트랙은 잉크, 준비 중 5트랙은 흐림")
    func activeTracksAreInkComingSoonAreDimmed() async throws {
        let fixture = DashboardFixture()
        let model = fixture.model()
        await model.load()

        let dimmed = model.rows.filter(\.stage.isDimmed)
        #expect(dimmed.count == 5)
        #expect(Set(dimmed.map(\.name)) == ["Go", "Java", "Next.js", "TypeScript", "Assembly"])
        #expect(Set(model.rows.filter { !$0.stage.isDimmed }.map(\.name))
            == ["Python", "SQL", "Swift", "Rust", "C++"])
        #expect(dimmed.allSatisfy { $0.stage == .comingSoon })
    }

    @Test("준비 중 트랙은 진도도 오늘 복습도 없다 — 0 이 아니라 없음이다")
    func comingSoonHasNoNumbers() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedDueCards(LanguageID("go"), count: 5)
        let model = fixture.model()
        await model.load()

        let go = try #require(model.rows.first { $0.name == "Go" })
        // 콘텐츠가 없는 트랙에 카드가 들어 있어도 표에 세지 않는다. `nil` 은 "—" 로 그려지고
        // `0` 은 "0 장 도착" 이라는 다른 말이다.
        #expect(go.dueToday == nil)
        #expect(go.resume == nil)
        #expect(go.completedLessons == 0)
        #expect(go.pendingContentLabel == "20 레슨 · 콘텐츠 준비 중")
    }

    @Test("활성 트랙이 최근 활동 순으로 먼저, 준비 중 트랙이 카탈로그 순으로 뒤")
    func activeTracksComeFirstByRecency() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedOpenLesson(.swift, ordinal: 7, completedBlocks: 3, at: fixture.studyDay(daysAgo: 0))
        try await fixture.seedOpenLesson(.sql, ordinal: 12, completedBlocks: 0, at: fixture.studyDay(daysAgo: 1))
        try await fixture.seedOpenLesson(.python, ordinal: 2, completedBlocks: 0, at: fixture.studyDay(daysAgo: 3))
        let model = fixture.model()
        await model.load()

        #expect(model.rows.map(\.name) == [
            "Swift", "SQL", "Python",
            "Rust", "C++", "Go", "Java", "Next.js", "TypeScript", "Assembly",
        ])
    }

    @Test("활동 시각이 같으면 카탈로그 순서가 마지막 키다 — 정렬이 흔들리지 않는다")
    func orderingIsTotal() {
        let rows = TrackCatalog.all.map { descriptor in
            TrackRow(
                descriptor: descriptor,
                stage: descriptor.hasContent ? .notStarted : .comingSoon,
                completedLessons: 0,
                recordedLessons: 0,
                cells: [],
                resume: nil,
                dueToday: nil,
                toolchain: .unknown
            )
        }
        // `Swift.sort` 는 안정 정렬이 아니다. 같은 키가 10개여도 결과는 매번 같아야 한다.
        let once = DashboardModel.ordered(rows).map(\.name)
        for _ in 0..<20 {
            #expect(DashboardModel.ordered(rows).map(\.name) == once)
        }
        #expect(once == TrackCatalog.all.map(\.name))
    }

    @Test("툴체인 열은 감지 결과를 받아 그리고, 없으면 확인 중이라고 말한다")
    func toolchainColumnComesFromInjectedProbe() async throws {
        let fixture = DashboardFixture()
        let injected = fixture.model(toolchainStatus: { language in
            // 포트가 `LanguageKit.ModuleAvailability` 를 그대로 실어 나른다 — 앱에서는
            // `RunnerKit.ToolchainProbe` 가 낸 값이 여기 그대로 들어온다.
            switch language.rawValue {
            case "swift":
                .probed(tool: "swiftc", .ready(version: "6.3.3", executablePath: "/usr/bin/swiftc"))
            case "go": .probed(tool: "go", .missing(installHint: "brew install go"))
            case "java": .probed(tool: "java", .stub(path: "/usr/bin/java", reason: "런타임 없음"))
            default: .unknown
            }
        })
        await injected.load()

        func status(_ name: String) throws -> TrackToolchainStatus {
            try #require(injected.rows.first { $0.name == name }).toolchain
        }
        #expect(try status("Swift").label == "swiftc 6.3.3")
        #expect(try status("Swift").dot == .pass)
        #expect(try status("Go").label == "go · 미설치")
        #expect(try status("Go").dot == .empty)
        #expect(try status("Java").label == "java · 스텁 감지")
        #expect(try status("Java").dot == .fail)

        // 공급자가 없으면 설치됐다고 지어내지 않는다.
        let bare = DashboardFixture().model()
        await bare.load()
        #expect(bare.rows.allSatisfy { $0.toolchain == .unknown })
        #expect(bare.rows.allSatisfy { $0.toolchain.label == "확인 중…" })
    }

    /// 디자인에 없는 4번째 판정. 온보딩과 같은 자리로 접는다 (`{#availability-mapping}`).
    @Test("최소 버전 미달은 미설치와 같은 표현으로 접힌다")
    func unsupportedFoldsIntoMissing() {
        let unsupported = TrackToolchainStatus.probed(
            tool: "go", .unsupported(path: "/usr/bin/go", version: "1.16", minimum: "1.22"))
        #expect(unsupported.label == "go · 미설치")
        #expect(unsupported.dot == .empty)
    }
}

@Suite("대시보드 · 진도 셀 3상태")
struct ProgressCellStateTests {
    @Test("완료·현재·미래 세 상태로만 그려진다 `{#progress-cell-states}`")
    func threeStates() {
        let cells = ProgressCells.build(completed: 3, total: 6, showsCurrent: true)
        #expect(cells == [.done, .done, .done, .current, .future, .future])
    }

    @Test("현재 칸은 정확히 하나이거나 없다")
    func atMostOneCurrent() {
        for completed in 0...6 {
            let cells = ProgressCells.build(completed: completed, total: 6, showsCurrent: true)
            #expect(cells.count(where: { $0 == .current }) <= 1)
            #expect(cells.count(where: { $0 == .done }) == completed)
        }
    }

    @Test("다 끝낸 트랙과 아직 안 연 트랙에는 현재 칸이 없다")
    func noCurrentWhenFinishedOrUnopened() {
        let finished = ProgressCells.build(completed: 6, total: 6, showsCurrent: true)
        #expect(finished == Array(repeating: .done, count: 6))

        let unopened = ProgressCells.build(completed: 0, total: 6, showsCurrent: false)
        #expect(unopened == Array(repeating: .future, count: 6))
    }

    @Test("완료 수가 총수를 넘어도 칸 수는 총수 그대로다")
    func clampsToTotal() {
        let cells = ProgressCells.build(completed: 99, total: 4, showsCurrent: true)
        #expect(cells.count == 4)
        #expect(cells.allSatisfy { $0 == .done })
    }

    @Test("모델이 만든 칸이 실제 진도와 일치한다 — 잉크 7칸, 현재 1칸, 나머지 흐림")
    func modelCellsMatchProgress() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 7, finishedBy: fixture.studyDay(daysAgo: 1))
        let model = fixture.model()
        await model.load()

        let swift = try #require(model.rows.first { $0.name == "Swift" })
        #expect(swift.completedLessons == 7)
        #expect(swift.progressLabel == "7 / 24")
        #expect(swift.cells.count == 24)
        #expect(swift.cells.prefix(7).allSatisfy { $0 == .done })
        #expect(swift.cells[7] == .current)
        #expect(swift.cells.dropFirst(8).allSatisfy { $0 == .future })
    }
}

@Suite("대시보드 · 오늘의 복습")
struct TodayReviewTests {
    @Test("트랙별 도착 수를 합치고 큰 것부터 나열한다")
    func perTrackBreakdown() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedDueCards(.swift, count: 7)
        try await fixture.seedDueCards(.sql, count: 4)
        try await fixture.seedDueCards(.python, count: 1)
        let model = fixture.model()
        await model.load()

        #expect(model.review.total == 12)
        #expect(model.review.perTrack.map(\.name) == ["Swift", "SQL", "Python"])
        #expect(model.review.perTrack.map(\.count) == [7, 4, 1])
        #expect(model.review.estimatedMinutes == 8)
        #expect(model.review.breakdownLine == "Swift 7 · SQL 4 · Python 1 · 약 8분")
    }

    @Test("표의 오늘 복습 열과 카드의 합계가 같은 값에서 나온다")
    func columnAndCardAgree() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedDueCards(.swift, count: 3)
        try await fixture.seedDueCards(.python, count: 2)
        let model = fixture.model()
        await model.load()

        let columnSum = model.rows.compactMap(\.dueToday).reduce(0, +)
        #expect(columnSum == model.review.total)
        #expect(columnSum == 5)
    }

    @Test("도착한 복습이 없으면 분해 줄이 없다 — 0 을 문장으로 꾸미지 않는다")
    func emptyReviewIsHonest() async throws {
        let fixture = DashboardFixture()
        let model = fixture.model()
        await model.load()

        #expect(model.review.total == 0)
        #expect(model.review.breakdownLine == nil)
        #expect(model.review.estimatedMinutes == 0)
    }
}

@Suite("대시보드 · 빈 상태")
struct EmptyStateTests {
    @Test("스토어가 비어 있으면 활성 트랙 전부 '아직 시작 안 함' 이다")
    func emptyStoresYieldNotStarted() async throws {
        let fixture = DashboardFixture()
        let model = fixture.model()
        await model.load()

        let active = model.rows.filter { !$0.stage.isDimmed }
        #expect(active.count == 5)
        #expect(active.allSatisfy { $0.stage == .notStarted })
        #expect(active.allSatisfy { $0.stage.label == "아직 시작 안 함" })
        #expect(active.allSatisfy { $0.completedLessons == 0 })
        #expect(active.allSatisfy { $0.resume == nil })
        // 부여된 진도는 **연 사람에게만** 준다. 아무것도 안 한 화면이 채워져 보이면 거짓말이다.
        #expect(active.allSatisfy { row in row.cells.allSatisfy { $0 == .future } })
        #expect(model.openLesson == nil)
    }

    @Test("load 전에도 10행이 자리를 잡고 있다 — 결과가 채워질 때 표가 튀지 않게")
    func rowsExistBeforeLoad() {
        let model = DashboardFixture().model()
        #expect(model.rows.count == 10)
        #expect(model.rows.allSatisfy { $0.cells.count == $0.lessonTotal })
        #expect(!model.isLoading)
        #expect(model.lastLoadedAt == nil)
    }

    @Test("읽기 실패를 '아직 시작 안 함' 으로 그리지 않는다")
    func readFailureIsNotMistakenForNoProgress() async throws {
        let fixture = DashboardFixture()
        try await fixture.seedCompletedLessons(.swift, count: 9, finishedBy: fixture.studyDay(daysAgo: 1))
        let model = fixture.model()
        await model.load()
        #expect(model.rows.first { $0.name == "Swift" }?.completedLessons == 9)

        // 같은 모델이 다음 적재에서 저장소를 못 읽는다.
        let broken = fixture.model(progressStore: FailingLessonProgressStore())
        await broken.load()
        #expect(broken.lastLoadFailed)
        // 실패한 적재는 표를 갈아엎지 않는다 — 직전 상태가 그대로 남는다.
        #expect(broken.lastLoadedAt == nil)
        #expect(broken.rows.count == 10)
        #expect(!broken.isLoading)
    }

    @Test("load 가 끝나면 시각이 기록된다")
    func loadStampsTime() async {
        let model = DashboardFixture().model()
        await model.load()
        #expect(model.lastLoadedAt == DashboardFixture.now)
        #expect(!model.isLoading)
        #expect(!model.lastLoadFailed)
    }
}

@Suite("대시보드 · 6블록 이름")
struct LessonBlockNameTests {
    @Test("블록 이름은 6개이고 LessonBlockSequence 와 개수가 묶여 있다")
    func sixNames() {
        #expect(LessonBlockNames.all.count == LessonBlockSequence.count)
        #expect(LessonBlockNames.all == ["개념", "실행 예제", "빈칸", "테스트 과제", "퀴즈", "회고"])
        #expect(LessonBlockNames.name(at: 3) == "테스트 과제")
        #expect(LessonBlockNames.name(at: LessonBlockSequence.count) == nil)
        #expect(LessonBlockNames.name(at: -1) == nil)
    }
}
