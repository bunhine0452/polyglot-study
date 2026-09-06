public import LearnCore
public import Observation

/// 대시보드("오늘") 화면의 상태 모델.
///
/// 목 데이터가 없다. 값은 전부 주입된 스토어 3종에서 온다 — 진도는 `LessonProgressStore`,
/// 오늘의 복습은 `CardStateStore.queue(...)`, 연속일수는 `ReviewLogStore` 다. 기본값은
/// `LearnCore` 의 인메모리 페이크(`InMemoryStores`)이고, 앱은 `LearnPersistence` 의 GRDB
/// 구현을 같은 프로토콜로 꽂는다. 페이크가 비어 있으면 화면에는 "아직 시작 안 함" 이
/// 정직하게 나온다 — 채워진 척하지 않는다.
///
/// 모듈 기본 격리가 `MainActor` 다(`Package.swift` 의 `uiSettings`) — 클래스에 `@MainActor`
/// 를 다시 적지 않는다.
@Observable
public final class DashboardModel {
    /// 팩이 알려 주는 레슨 메타. 순번과 제목은 팩 매니페스트(`ContentKit.PackManifest` 의
    /// `order`·`title`)에만 있는 정보라 밖에서 넣는다.
    ///
    /// `nonisolated` 인 이유: 이 값은 `@Sendable` 공급자 클로저가 **MainActor 밖에서**
    /// 만들 수 있어야 한다. 모듈 기본 격리가 MainActor 라(`uiSettings`) 표시하지 않으면
    /// 클로저 안에서 생성자조차 부를 수 없다.
    nonisolated public struct LessonMetadata: Hashable, Sendable {
        /// 1-기반 순번.
        public let ordinal: Int
        public let title: String

        public init(ordinal: Int, title: String) {
            self.ordinal = ordinal
            self.title = title
        }
    }

    // MARK: - 관측 상태

    /// 표에 그릴 10행. 순서는 **활성 트랙이 최근 활동 순으로 먼저, 준비 중 트랙이 카탈로그
    /// 순으로 뒤**다.
    public private(set) var rows: [TrackRow] = []
    public private(set) var review = ReviewSummary(perTrack: [], total: 0, streakDays: 0)
    public private(set) var isLoading = false
    public private(set) var lastLoadedAt: EpochMillis?
    /// 진도 읽기가 실패했다. 실패를 "아직 시작 안 함" 으로 그리지 않기 위한 플래그다 —
    /// 읽지 못한 것과 아무것도 안 한 것은 화면에서 같아 보이면 안 된다.
    public private(set) var lastLoadFailed = false

    /// **자이가르닉** — 화면 최상단 "이어서 · 열린 레슨" 카드. 멈춘 레슨 중 가장 최근
    /// 것 하나다. 열린 레슨이 없으면 `nil` 이고, 카드는 빈 상태를 정직하게 말한다.
    public var openLesson: ResumePoint? {
        rows.compactMap(\.resume)
            .filter(\.isOpen)
            .max { lhs, rhs in
                (lhs.lastActivityAt?.value ?? .min) < (rhs.lastActivityAt?.value ?? .min)
            }
    }

    // MARK: - 주입

    private let packID: PackID
    private let catalog: [TrackDescriptor]
    private let progressStore: any LessonProgressStore
    private let cardStateStore: any CardStateStore
    private let reviewLogStore: any ReviewLogStore
    private let clock: any SchedulerClock
    private let dayBoundary: DayBoundary
    private let queuePolicy: DueQueuePolicy

    /// `nil` 이면 레슨 순번·제목을 모르는 상태로 그린다(제목 자리에 레슨 id).
    ///
    /// 클로저에 기본 인자 값을 주지 않는 이유는 **실측으로 밟은 함정** 때문이다 —
    /// `@Sendable` 클로저를 `@MainActor` 격리 `public init` 의 기본 인자로 두고 다른
    /// 모듈에서 그 파라미터를 생략해 호출하면 `freed pointer was not the last allocation`
    /// 으로 프로세스가 죽는다(온보딩 세션이 100% 재현). `nil` 기본값 + 내부 폴백으로 피한다.
    private let lessonMetadata: (@Sendable (PackID, LessonID) -> LessonMetadata?)?
    /// 트랙 순서대로의 레슨 목록. `nil` 이면 진도가 있는 레슨만 아는 상태다.
    private let lessonDirectory: (@Sendable (LanguageID) -> [LessonID])?
    /// `nil` 이면 모든 트랙이 `.unknown` — 감지 결과를 지어내지 않는다.
    private let toolchainStatus: (@Sendable (LanguageID) -> TrackToolchainStatus)?

    /// - Parameters:
    ///   - stores: 비워 두면 `LearnCore` 의 인메모리 페이크가 들어간다. 앱은 GRDB 구현을 넣는다.
    ///   - catalog: 트랙 커리큘럼. 기본값은 10트랙 전부.
    public init(
        packID: PackID = DashboardModel.defaultPackID,
        catalog: [TrackDescriptor] = TrackCatalog.all,
        progressStore: (any LessonProgressStore)? = nil,
        cardStateStore: (any CardStateStore)? = nil,
        reviewLogStore: (any ReviewLogStore)? = nil,
        clock: (any SchedulerClock)? = nil,
        dayBoundary: DayBoundary = DayBoundary(),
        queuePolicy: DueQueuePolicy = .default,
        lessonMetadata: (@Sendable (PackID, LessonID) -> LessonMetadata?)? = nil,
        lessonDirectory: (@Sendable (LanguageID) -> [LessonID])? = nil,
        toolchainStatus: (@Sendable (LanguageID) -> TrackToolchainStatus)? = nil
    ) {
        // 셋 중 하나만 주어져도 나머지는 같은 컨테이너에서 나와야 한다 — 서로 다른 페이크를
        // 섞으면 큐 계산이 참조하는 로그가 달라진다.
        let fakes = InMemoryStores()
        self.packID = packID
        self.catalog = catalog
        self.progressStore = progressStore ?? fakes.lessonProgress
        self.cardStateStore = cardStateStore ?? fakes.cardState
        self.reviewLogStore = reviewLogStore ?? fakes.reviewLog
        self.clock = clock ?? SystemSchedulerClock()
        self.dayBoundary = dayBoundary
        self.queuePolicy = queuePolicy
        self.lessonMetadata = lessonMetadata
        self.lessonDirectory = lessonDirectory
        self.toolchainStatus = toolchainStatus
        self.rows = catalog.map { Self.emptyRow(for: $0) }
    }

    /// MVP 콘텐츠 팩. `Content/packs/polyglot-mvp/manifest.json` 의 `packID` 와 같다.
    public static let defaultPackID = PackID("polyglot-mvp")

    // MARK: - 적재

    /// 스토어를 읽어 10행과 복습 요약을 다시 만든다.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        let now = clock.now()
        let studyDayStart = dayBoundary.startOfStudyDay(containing: now)

        guard let progressByTrack = await progressByTrack() else {
            // 저장소를 못 읽었다. 직전 행을 그대로 둔다 — 빈 표를 그리면 "아직 시작 안 함"
            // 이라고 말하는 것이 되고, 그건 사실이 아니다.
            lastLoadFailed = true
            return
        }
        lastLoadFailed = false
        var built: [TrackRow] = []
        var counts: [ReviewSummary.TrackCount] = []

        for descriptor in catalog {
            let progress = progressByTrack[descriptor.languageID] ?? []
            let due = descriptor.hasContent
                ? await dueCount(descriptor.languageID, now: now, studyDayStart: studyDayStart)
                : nil
            built.append(row(for: descriptor, progress: progress, dueToday: due))
            if let due, due > 0 {
                counts.append(ReviewSummary.TrackCount(name: descriptor.name, count: due))
            }
        }

        rows = Self.ordered(built)
        review = ReviewSummary(
            perTrack: counts.sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.name < rhs.name : lhs.count > rhs.count
            },
            total: counts.reduce(0) { $0 + $1.count },
            streakDays: await streakDays(now: now)
        )
        lastLoadedAt = now
    }

    // MARK: - 행 조립

    /// 활성 트랙이 **최근 활동 순**으로 먼저, 준비 중 트랙이 카탈로그 순으로 뒤.
    ///
    /// 활동 시각을 모르는 활성 트랙(아직 안 연 트랙)은 활성 구간의 끝으로 간다 — 순서가
    /// 흔들리지 않도록 카탈로그 순서를 마지막 키로 쓴다(`Swift.sort` 는 안정 정렬이 아니다).
    static func ordered(_ rows: [TrackRow]) -> [TrackRow] {
        rows.enumerated()
            .sorted { lhs, rhs in
                let left = (lhs.element.stage == .comingSoon ? 1 : 0)
                let right = (rhs.element.stage == .comingSoon ? 1 : 0)
                if left != right { return left < right }
                let leftActivity = lhs.element.resume?.lastActivityAt?.value ?? .min
                let rightActivity = rhs.element.resume?.lastActivityAt?.value ?? .min
                if leftActivity != rightActivity { return leftActivity > rightActivity }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func emptyRow(for descriptor: TrackDescriptor) -> TrackRow {
        TrackRow(
            descriptor: descriptor,
            stage: descriptor.hasContent ? .notStarted : .comingSoon,
            completedLessons: 0,
            recordedLessons: 0,
            cells: ProgressCells.build(completed: 0, total: descriptor.lessonTotal, showsCurrent: false),
            resume: nil,
            dueToday: nil,
            toolchain: .unknown
        )
    }

    private func row(
        for descriptor: TrackDescriptor,
        progress: [LessonProgress],
        dueToday: Int?
    ) -> TrackRow {
        let toolchain = toolchainStatus?(descriptor.languageID) ?? .unknown
        guard descriptor.hasContent else {
            // 준비 중 트랙은 진도를 읽지 않는다 — 콘텐츠가 없으니 진도도 있을 수 없다.
            // 칸 배열은 그래도 레슨 총수만큼 만든다. 표에는 안 그려지지만, "칸 수 = 레슨
            // 총수" 불변식이 10트랙 전부에서 성립해야 한다(`{#screen-dashboard}`).
            return TrackRow(
                descriptor: descriptor,
                stage: .comingSoon,
                completedLessons: 0,
                recordedLessons: 0,
                cells: ProgressCells.build(
                    completed: 0, total: descriptor.lessonTotal, showsCurrent: false
                ),
                resume: nil,
                dueToday: nil,
                toolchain: toolchain
            )
        }

        let recorded = progress.count { $0.status == .completed }
        // **부여된 진도 효과** — 트랙을 연 순간 오리엔테이션(01)이 완료로 기록된다.
        // 열지도 않은 트랙에는 주지 않는다. 그건 부여가 아니라 거짓말이다.
        let isOpened = !progress.isEmpty
        let completed = isOpened ? max(1, recorded) : 0
        let stage: TrackStage =
            if !isOpened { .notStarted } else if completed <= 1 { .justStarted } else { .active }

        return TrackRow(
            descriptor: descriptor,
            stage: stage,
            completedLessons: completed,
            recordedLessons: recorded,
            cells: ProgressCells.build(
                completed: completed,
                total: descriptor.lessonTotal,
                showsCurrent: isOpened && completed < descriptor.lessonTotal
            ),
            resume: resumePoint(for: descriptor, progress: progress),
            dueToday: dueToday,
            toolchain: toolchain
        )
    }

    /// 멈춘 레슨이 있으면 그것, 없으면 다음에 열 레슨.
    private func resumePoint(
        for descriptor: TrackDescriptor,
        progress: [LessonProgress]
    ) -> ResumePoint? {
        let open = progress
            .filter { $0.status == .inProgress }
            .max { ($0.lastActivityAt?.value ?? .min) < ($1.lastActivityAt?.value ?? .min) }

        if let open {
            return makeResume(
                descriptor: descriptor,
                lessonID: open.lessonID,
                kind: .open(
                    blockIndex: min(open.currentBlockIndex, LessonBlockSequence.count - 1),
                    completedBlocks: open.completedBlocks.count
                ),
                lastActivityAt: open.lastActivityAt
            )
        }

        // 열린 레슨이 없다 — 팩 목록을 알면 다음 레슨을 가리키고, 모르면 가리킬 곳이 없다.
        guard let directory = lessonDirectory?(descriptor.languageID) else { return nil }
        let settled = Set(
            progress.filter { $0.status == .completed || $0.status == .skipped }.map(\.lessonID)
        )
        guard let next = directory.first(where: { !settled.contains($0) }) else { return nil }
        return makeResume(
            descriptor: descriptor,
            lessonID: next,
            kind: .next,
            lastActivityAt: progress.compactMap(\.lastActivityAt).max()
        )
    }

    private func makeResume(
        descriptor: TrackDescriptor,
        lessonID: LessonID,
        kind: ResumeKind,
        lastActivityAt: EpochMillis?
    ) -> ResumePoint {
        let metadata = lessonMetadata?(packID, lessonID)
        return ResumePoint(
            languageID: descriptor.languageID,
            trackName: descriptor.name,
            lessonID: lessonID,
            lessonOrdinal: metadata?.ordinal,
            lessonTitle: metadata?.title ?? lessonID.rawValue,
            lessonTotal: descriptor.lessonTotal,
            kind: kind,
            lastActivityAt: lastActivityAt
        )
    }

    // MARK: - 스토어 조회

    /// `nil` 이면 읽기 자체가 실패한 것이다. 빈 사전과 구분된다.
    private func progressByTrack() async -> [LanguageID: [LessonProgress]]? {
        guard let list = try? await progressStore.progressList(packID: packID) else { return nil }
        return Dictionary(grouping: list, by: \.languageID)
    }

    private func dueCount(
        _ languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis
    ) async -> Int {
        let queue = try? await cardStateStore.queue(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: queuePolicy
        )
        return queue?.count ?? 0
    }

    /// **축적 프레이밍** — 오늘(또는 아직 오늘 복습을 안 했으면 어제)에서 뒤로 이어지는
    /// 학습일 수. 만료도, 경고도, 남은 시간도 없다.
    ///
    /// 어제부터 세는 것이 핵심이다. 오늘 아직 복습을 안 했다고 연속일수가 0 으로 떨어지면
    /// 그 숫자 자체가 위협이 된다 — 쌓인 것은 오늘 하루로 사라지지 않는다.
    private func streakDays(now: EpochMillis) async -> Int {
        guard let entries = try? await reviewLogStore.entries(after: nil, limit: .max) else { return 0 }
        let days = Set(entries.map { dayBoundary.studyDay(containing: $0.reviewedAt) })
        return Self.streak(days: days, today: dayBoundary.studyDay(containing: now))
    }

    /// 연속일수 계산. 스토어 없이 단언할 수 있도록 순수 함수로 떼어 놓았다.
    static func streak(days: Set<Int>, today: Int) -> Int {
        var cursor = days.contains(today) ? today : today - 1
        guard days.contains(cursor) else { return 0 }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }
}
