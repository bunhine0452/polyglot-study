public import Observation
public import LearnCore
internal import LearnScheduling

/// 복습 화면의 상태 모델. `{#screen-review}`
///
/// 목 데이터가 없다 — 스케줄러와 두 스토어를 **프로토콜로** 받는다. 오늘의 큐는
/// `CardStateStore.queue(languageID:using:policy:)` 가 실제로 계산하고, 버튼 아래 표시할
/// 4개 간격은 `ReviewScheduler.preview(_:at:)` 가 실제로 계산한다 — 이 타입은 그 값을
/// 옮겨 담을 뿐 스스로 간격을 만들지 않는다.
///
/// 카드 앞/뒤 텍스트만 `ReviewCardContentProvider` 뒤에 따로 있다 — `ReviewCardContent.swift`
/// 의 주석 참고. FSRS 계산과는 별개의 관심사다.
///
/// 이 모듈의 기본 격리가 `MainActor` 다(`Package.swift` 의 `uiSettings`) — 그래서 이 클래스
/// 자체에 `@MainActor` 를 다시 적지 않는다. `OnboardingModel` 과 같은 관용구다.
@Observable
public final class ReviewModel {
    /// 큐 한 자리 — 알고리즘 상태(캐시)와 표시용 콘텐츠를 함께 든다.
    public struct QueueCard: Identifiable, Sendable, Equatable {
        public var snapshot: CardStateSnapshot
        public var content: ReviewCardContent

        public init(snapshot: CardStateSnapshot, content: ReviewCardContent) {
            self.snapshot = snapshot
            self.content = content
        }

        public var id: CardID { snapshot.cardID }
    }

    public private(set) var queue: [QueueCard] = []
    public private(set) var currentIndex = 0
    /// 지금 카드의 4-rating 미리보기. `{#scheduler-preview}` — 한 시각, 한 호출로 넷을 낸다.
    public private(set) var preview: ReviewPreview?
    /// 연속 복습 일수. `review_log` 에서 실제로 세어 계산한다 — 하드코딩 없음.
    public private(set) var streakDays = 0
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let languageIDs: [LanguageID]
    private let policy: DueQueuePolicy
    private let scheduler: any ReviewScheduler
    private let cardStateStore: any CardStateStore
    private let reviewLogStore: any ReviewLogStore
    private let contentProvider: any ReviewCardContentProvider

    /// 연속일수 계산이 훑는 최대 과거 일수. 로그가 하나도 없는 새 설치에서 무한히
    /// 거슬러 올라가지 않도록 하는 상한이다 — 이 정도 지나면 "연속 복습 0일" 이 맞는 답이다.
    private static let maxStreakLookbackDays = 400

    public init(
        languageIDs: [LanguageID],
        policy: DueQueuePolicy = .default,
        scheduler: any ReviewScheduler,
        cardStateStore: any CardStateStore,
        reviewLogStore: any ReviewLogStore,
        contentProvider: any ReviewCardContentProvider = StaticReviewCardContentProvider()
    ) {
        self.languageIDs = languageIDs
        self.policy = policy
        self.scheduler = scheduler
        self.cardStateStore = cardStateStore
        self.reviewLogStore = reviewLogStore
        self.contentProvider = contentProvider
    }

    // MARK: - 파생 상태

    public var currentCard: QueueCard? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    public var totalCount: Int { queue.count }
    /// 진행 헤더의 "완료" 칸 수. 아직 채점하지 않은 지금 카드는 포함하지 않는다.
    public var completedCount: Int { min(currentIndex, queue.count) }
    public var isFinished: Bool { !queue.isEmpty && currentIndex >= queue.count }

    /// 지금 카드의 채점 버튼 4개 스펙. 순서는 again → hard → good → easy.
    ///
    /// `internal` 이다 — `RatingButtonSpec` 자체가 이 모듈 밖에 나가지 않는 타입이라
    /// (뷰 전용 스타일 계약), 이 화면의 뷰와 `@testable import` 로 여는 테스트만 본다.
    var ratingSpecs: [RatingButtonSpec] {
        guard let preview else { return [] }
        return RatingButtonRow.specs(from: preview)
    }

    /// 주입된 클록의 "지금". 화면이 "마지막 복습 N일 전" 같은 문구를 계산할 때 쓴다 —
    /// `Date()` 를 직접 부르면 고정 클록을 주입한 테스트와 어긋난다.
    public var now: EpochMillis { scheduler.clock.now() }

    // MARK: - 로드

    /// 오늘의 복습 큐를 불러오고 첫 카드의 미리보기·연속일수를 계산한다.
    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ensureSchedulerParameterSetIsActive()

            var entries: [DueQueueEntry] = []
            for languageID in languageIDs {
                entries += try await cardStateStore.queue(
                    languageID: languageID,
                    using: scheduler,
                    policy: policy
                )
            }
            // 여러 트랙을 합친 큐라 due 시각 순으로 다시 정렬한다 — 언어별 결과는 이미
            // due 순이지만 합친 뒤에는 그 보장이 깨진다.
            entries.sort { $0.snapshot.dueAt < $1.snapshot.dueAt }

            var cards: [QueueCard] = []
            cards.reserveCapacity(entries.count)
            for entry in entries {
                let content = try await contentProvider.content(for: entry.cardID)
                cards.append(QueueCard(snapshot: entry.snapshot, content: content))
            }

            queue = cards
            currentIndex = 0
            errorMessage = nil
            refreshPreview()
            streakDays = try await computeStreak()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - 채점

    /// rating 을 적용하고 다음 카드로 넘어간다.
    ///
    /// **뷰가 카드를 지우지 않는다** — 다음 카드로 넘어갈 뿐, 채점 이전의 카드도 `queue` 배열
    /// 안에 그대로 남는다(`ReviewCopy.noCardRemovalNotice` 가 이 사실을 그대로 옮긴 문구다).
    @discardableResult
    public func choose(_ rating: ReviewRating) async -> Bool {
        guard let card = currentCard else { return false }
        let now = scheduler.clock.now()
        do {
            let outcome = try scheduler.apply(
                rating,
                to: card.snapshot.scheduling,
                at: now,
                reviewDurationMS: nil,
                source: .review
            )
            let snapshot = CardStateSnapshot(
                scheduling: outcome.state,
                languageID: card.snapshot.languageID,
                rebuiltAt: now
            )
            try await cardStateStore.upsert(snapshot)
            try await reviewLogStore.append(outcome.logEntry)

            queue[currentIndex].snapshot = snapshot
            currentIndex += 1
            errorMessage = nil
            refreshPreview()
            streakDays = try await computeStreak()
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    // MARK: - 내부

    /// `review_log.parameter_set_id` 는 `scheduler_parameters` 를 참조하는 외래키다.
    ///
    /// 새로 연 `LearnDatabase` 는 마이그레이션 001 이 심은 자리표시 세트(`fsrs6-default` 라는
    /// **문자열 그대로**)를 활성으로 갖고 시작한다. 반면 실제 `FSRSReviewScheduler` 의
    /// `parameterSetID` 는 파라미터 내용에서 유도한 해시(`fsrs6-<hex>`)라 그 문자열과
    /// 다르다 — 활성 세트를 갈아 끼우지 않고 그대로 리뷰를 기록하면 외래키 위반으로
    /// `reviewLogStore.append` 가 던진다. 그래서 세션을 불러올 때 한 번, 스케줄러가 실제로
    /// 쓰는 세트를 등록·활성화해 둔다. 이미 일치하면 아무것도 쓰지 않는다.
    private func ensureSchedulerParameterSetIsActive() async throws {
        let active = try await reviewLogStore.activeParameterSet()
        guard active.id != scheduler.parameterSetID else { return }
        try await reviewLogStore.save(
            parameterSet: SchedulerParameterSet(
                id: scheduler.parameterSetID,
                schedulerID: scheduler.schedulerID,
                weights: nil,
                createdAt: scheduler.clock.now(),
                isActive: true
            ),
            activate: true
        )
    }

    private func refreshPreview() {
        guard let card = currentCard else {
            preview = nil
            return
        }
        preview = try? scheduler.preview(card.snapshot.scheduling, at: scheduler.clock.now())
    }

    /// 오늘부터 거슬러 올라가며 리뷰가 있었던 연속 학습일 수.
    ///
    /// 오늘 몫을 아직 하지 않았어도(지금 이 화면을 여는 이유가 그것이다) 어제까지의
    /// 연속기록은 깨지지 않는다 — 그래서 "오늘" 하루만은 카운트가 0이어도 계속 거슬러
    /// 올라가고, 그 이후 처음 만나는 빈 날에서 멈춘다.
    private func computeStreak() async throws -> Int {
        let dayBoundary = scheduler.dayBoundary
        var streak = 0
        var probe = scheduler.clock.now()
        var isToday = true
        for _ in 0..<Self.maxStreakLookbackDays {
            let dayStart = dayBoundary.startOfStudyDay(containing: probe)
            let dayEnd = dayStart.adding(days: 1)
            let count = try await reviewLogStore.count(from: dayStart, to: dayEnd)
            if count > 0 {
                streak += 1
            } else if !isToday {
                break
            }
            isToday = false
            probe = dayStart.adding(days: -1)
        }
        return streak
    }
}
