public import LearnCore
internal import LearnScheduling
public import LearnPersistence

/// 실물 조립 — 앱이 이 화면을 붙일 때 쓰는 진입점.
///
/// `ReviewModel.init` 은 스케줄러·스토어를 프로토콜로만 받는다(테스트가 인메모리
/// `LearnDatabase` 를 꽂기 위해서다). 앱 쪽에서는 보통 "FSRS-6 기본 파라미터 + 이미 열어
/// 둔 `LearnDatabase`" 조합을 그대로 쓰므로, 그 조합을 한 줄로 묶어 둔다.
extension ReviewModel {
    /// - Parameter database: 앱이 연 `LearnDatabase`(파일이든 `inMemory()`든 상관없다).
    /// - Throws: `FSRSReviewScheduler.init` 이 던지는 에러 — 기본 파라미터
    ///   (`FSRSParameterSet.fsrs6Default`)는 이미 검증돼 있어 사실상 던지지 않지만,
    ///   실패 가능성을 숨기지 않기 위해 그대로 전파한다.
    public static func live(
        database: LearnDatabase,
        languageIDs: [LanguageID] = [.python, .sql, .swift],
        policy: DueQueuePolicy = .default,
        contentProvider: any ReviewCardContentProvider = StaticReviewCardContentProvider()
    ) throws -> ReviewModel {
        let scheduler = try FSRSReviewScheduler()
        return ReviewModel(
            languageIDs: languageIDs,
            policy: policy,
            scheduler: scheduler,
            cardStateStore: database.cardStateStore,
            reviewLogStore: database.reviewLogStore,
            contentProvider: contentProvider
        )
    }
}
