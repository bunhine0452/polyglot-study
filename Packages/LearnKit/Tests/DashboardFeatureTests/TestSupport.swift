import LearnCore

@testable import DashboardFeature

/// 대시보드 테스트의 조립 지점.
///
/// **목 데이터를 만들지 않는다.** `InMemoryStores` 는 GRDB 구현과 같은 프로토콜을 지키는
/// 진짜 페이크이고, 여기 들어가는 값은 전부 실제 도메인 타입(`LessonProgress`,
/// `CardStateSnapshot`, `ReviewLogEntry`)이다. 화면이 읽는 경로도 앱과 같다.
struct DashboardFixture {
    /// 서울 04:00 롤오버로 고정한다. 시스템 시간대에 기대면 연속일수 단언이 기계마다 달라진다.
    static let dayBoundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
    /// 2026-09-06 12:00 KST 근처의 고정 시각. 값 자체는 의미가 없고 **차이**만 쓴다.
    static let now = EpochMillis(1_757_127_600_000)
    static let packID = DashboardModel.defaultPackID

    let stores = InMemoryStores()

    /// 오늘 학습일의 시작.
    var studyDayStart: EpochMillis { Self.dayBoundary.startOfStudyDay(containing: Self.now) }

    /// `offset` 일 전 학습일 한가운데. 롤오버 경계에 걸치지 않도록 6시간을 더한다.
    func studyDay(daysAgo offset: Int) -> EpochMillis {
        studyDayStart.adding(days: -offset).adding(minutes: 6 * 60)
    }

    func model(
        progressStore: (any LessonProgressStore)? = nil,
        catalog: [TrackDescriptor] = TrackCatalog.all,
        lessonMetadata: (@Sendable (PackID, LessonID) -> DashboardModel.LessonMetadata?)? = nil,
        lessonDirectory: (@Sendable (LanguageID) -> [LessonID])? = nil,
        toolchainStatus: (@Sendable (LanguageID) -> TrackToolchainStatus)? = nil
    ) -> DashboardModel {
        DashboardModel(
            packID: Self.packID,
            catalog: catalog,
            progressStore: progressStore ?? stores.lessonProgress,
            cardStateStore: stores.cardState,
            reviewLogStore: stores.reviewLog,
            clock: FixedSchedulerClock(Self.now),
            dayBoundary: Self.dayBoundary,
            queuePolicy: .default,
            lessonMetadata: lessonMetadata,
            lessonDirectory: lessonDirectory,
            toolchainStatus: toolchainStatus
        )
    }

    // MARK: - 진도

    /// 완료된 레슨 `count` 개를 심는다. 레슨 id 는 `<lang>-0001` … 로 순번을 담는다.
    func seedCompletedLessons(
        _ languageID: LanguageID,
        count: Int,
        finishedBy timestamp: EpochMillis
    ) async throws {
        guard count > 0 else { return }
        for ordinal in 1...count {
            try await stores.lessonProgress.upsert(
                LessonProgress(
                    packID: Self.packID,
                    lessonID: Self.lessonID(languageID, ordinal),
                    languageID: languageID,
                    status: .completed,
                    completedBlocks: Array(LessonBlockSequence.indices),
                    currentBlockIndex: LessonBlockSequence.count - 1,
                    startedAt: timestamp,
                    lastActivityAt: timestamp,
                    completedAt: timestamp
                )
            )
        }
    }

    /// 블록 도중에 멈춘 레슨 하나.
    func seedOpenLesson(
        _ languageID: LanguageID,
        ordinal: Int,
        completedBlocks: Int,
        at timestamp: EpochMillis
    ) async throws {
        try await stores.lessonProgress.upsert(
            LessonProgress(
                packID: Self.packID,
                lessonID: Self.lessonID(languageID, ordinal),
                languageID: languageID,
                status: .inProgress,
                completedBlocks: Array(0..<completedBlocks),
                currentBlockIndex: completedBlocks,
                startedAt: timestamp,
                lastActivityAt: timestamp
            )
        )
    }

    /// 샘플 팩의 이름 규칙(`py-0001-fstring`)과 같은 4자리 순번을 쓴다.
    ///
    /// `nonisolated` — 레슨 메타 공급자(`@Sendable` 클로저) 안에서도 불러야 한다.
    nonisolated static func lessonID(_ languageID: LanguageID, _ ordinal: Int) -> LessonID {
        var digits = "\(ordinal)"
        while digits.count < 4 { digits = "0" + digits }
        return LessonID("\(languageID.rawValue)-\(digits)")
    }

    // MARK: - 복습

    /// 이미 due 인 복습 카드 `count` 장.
    func seedDueCards(_ languageID: LanguageID, count: Int) async throws {
        for index in 0..<count {
            try await stores.cardState.upsert(
                CardStateSnapshot(
                    cardID: CardID("\(languageID.rawValue)-card-\(index)"),
                    languageID: languageID,
                    stability: 4,
                    difficulty: 5,
                    dueAt: Self.now.adding(minutes: -60),
                    lastReviewedAt: Self.now.adding(days: -2),
                    phase: .review,
                    reps: 3,
                    elapsedDays: 2,
                    scheduledDays: 4,
                    learningStepIndex: 0,
                    rebuiltAt: Self.now
                )
            )
        }
    }

    /// `days` 일 연속으로 복습 로그를 남긴다(0 = 오늘). 카드 상태는 만들지 않는다 —
    /// 오늘의 큐 몫을 갉아먹지 않게 하기 위해서다(`InMemoryCardStateStore.queue` 는
    /// 스냅샷이 있는 카드의 로그만 오늘 쓴 몫으로 센다).
    func seedReviewStreak(days: [Int]) async throws {
        for offset in days {
            try await stores.reviewLog.append(
                ReviewLogEntry(
                    cardID: CardID("streak-\(offset)"),
                    reviewedAt: studyDay(daysAgo: offset),
                    rating: .good,
                    stateBefore: .review,
                    elapsedDays: 1,
                    scheduledDays: 3
                )
            )
        }
    }
}

/// 항상 실패하는 진도 스토어. GRDB 구현이 `StoreError` 를 올려보내는 경로를 흉내낸다.
///
/// `nonisolated` — 프로토콜 요구가 전부 코어(비격리) 쪽 선언이다.
nonisolated struct FailingLessonProgressStore: LessonProgressStore {
    static let failure = StoreError.storage(message: "disk I/O error")

    func progress(packID: PackID, lessonID: LessonID) async throws -> LessonProgress? {
        throw Self.failure
    }

    func upsert(_ progress: LessonProgress) async throws {
        throw Self.failure
    }

    func progressList(packID: PackID) async throws -> [LessonProgress] {
        throw Self.failure
    }

    @discardableResult
    func completeBlock(
        packID: PackID,
        lessonID: LessonID,
        languageID: LanguageID,
        blockIndex: Int,
        at timestamp: EpochMillis
    ) async throws -> LessonProgress {
        throw Self.failure
    }

    func observeProgress(
        packID: PackID,
        lessonID: LessonID
    ) -> AsyncThrowingStream<LessonProgress?, any Error> {
        AsyncThrowingStream { $0.finish(throwing: Self.failure) }
    }
}
