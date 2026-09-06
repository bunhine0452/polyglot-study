public import LearnCore

// `DayBoundary` 배선. `{#queue-mixing}`
//
// `CardStateStore.queue(languageID:now:studyDayStart:policy:)` 가 학습일 시작을 **인자로**
// 받는 것은 저장 계층에 `Calendar` 의존을 들이지 않으려는 의도다 — 롤오버는 시간대와
// 그레고리력을 아는 정책이고, SQL 은 정수 비교만 하면 된다 (`EpochMillis` 주석 참고).
//
// 그 대가로 호출부마다 `dayBoundary.startOfStudyDay(containing: now)` 를 손으로 넣어야 하고,
// 한 군데라도 빼먹으면 상한이 세션 단위로 되돌아간다 — 앱을 다시 열 때마다 오늘 몫이
// 새로 생기는, 조용하고 알아채기 어려운 종류의 오작동이다. 그래서 그 한 줄을 여기서 한 번만
// 쓴다. 롤오버 정책을 아는 계층이 `LearnScheduling` 이므로 배선도 여기 있는 게 맞다.

extension CardStateStore {
    /// 오늘의 복습 큐. 학습일 시작을 `DayBoundary` 가 계산해 넣는다.
    ///
    /// - Parameters:
    ///   - now: due 판정 기준 시각.
    ///   - dayBoundary: 롤오버 정책. 기본 04:00 이다.
    public func queue(
        languageID: LanguageID,
        now: EpochMillis,
        dayBoundary: DayBoundary,
        policy: DueQueuePolicy = .default
    ) async throws -> [DueQueueEntry] {
        try await queue(
            languageID: languageID,
            now: now,
            studyDayStart: dayBoundary.startOfStudyDay(containing: now),
            policy: policy
        )
    }

    /// 스케줄러가 들고 있는 롤오버 정책과 클록을 그대로 쓰는 큐.
    ///
    /// 실제 복습 화면이 부르는 형태다. 시각과 하루 경계가 스케줄링과 큐에서 **같은 출처**를
    /// 쓰게 되므로, "버튼 라벨은 10분인데 큐는 내일로 넘겼다" 류의 어긋남이 생기지 않는다.
    public func queue(
        languageID: LanguageID,
        using scheduler: some ReviewScheduler,
        at now: EpochMillis? = nil,
        policy: DueQueuePolicy = .default
    ) async throws -> [DueQueueEntry] {
        let instant = now ?? scheduler.clock.now()
        return try await queue(
            languageID: languageID,
            now: instant,
            dayBoundary: scheduler.dayBoundary,
            policy: policy
        )
    }
}

extension ReviewScheduler {
    /// 이 스케줄러의 롤오버 정책이 보는 "오늘의 시작".
    ///
    /// 큐 밖에서도 같은 경계가 필요하다 — 오늘 푼 개수, 연속일수, 통계 전부 이 값을 기준으로
    /// 센다. 각자 `Calendar` 를 만들면 화면마다 하루가 달라진다.
    public func startOfStudyDay(containing instant: EpochMillis? = nil) -> EpochMillis {
        dayBoundary.startOfStudyDay(containing: instant ?? clock.now())
    }
}
