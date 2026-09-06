import Foundation
internal import LearnCore

// 벤더 FSRS ↔ LearnCore 값 타입 변환. **이 파일이 유일한 통로다.**
//
// 여기 밖에서는 `Card`, `Rating`, `CardState`, `FSRS*` 어떤 것도 등장하지 않는다.
// 컨버전이 흩어지면 반올림 규칙이 흩어지고, 반올림 규칙이 흩어지면 리플레이가 깨진다.

extension EpochMillis {
    /// 벤더 호출 직전에만 쓰는 변환.
    var vendorDate: Date { Date(timeIntervalSince1970: Double(value) / 1_000) }

    /// 벤더가 돌려준 `Date` 를 다시 밀리초로. 반올림은 여기 한 곳에만 있다.
    init(vendor date: Date) {
        self.init(Int64((date.timeIntervalSince1970 * 1_000).rounded()))
    }
}

extension ReviewRating {
    var vendor: Rating {
        switch self {
        case .again: return .again
        case .hard: return .hard
        case .good: return .good
        case .easy: return .easy
        }
    }
}

extension CardPhase {
    var vendor: CardState {
        switch self {
        case .new: return .new
        case .learning: return .learning
        case .review: return .review
        case .relearning: return .relearning
        }
    }

    init(vendor state: CardState) {
        switch state {
        case .new: self = .new
        case .learning: self = .learning
        case .review: self = .review
        case .relearning: self = .relearning
        }
    }
}

extension CardSchedulingState {
    /// 벤더 카드로. `elapsedDays`/`scheduledDays` 는 벤더에서 `Double` 이지만 항상 정수값이다.
    var vendorCard: Card {
        Card(
            due: dueAt.vendorDate,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: Double(elapsedDays),
            scheduledDays: Double(scheduledDays),
            learningSteps: learningStepIndex,
            reps: reps,
            lapses: lapses,
            state: phase.vendor,
            lastReview: lastReviewedAt?.vendorDate
        )
    }

    init(vendor card: Card, cardID: CardID, parameterSetID: ParameterSetID, derivedFromLogID: ReviewLogID?) {
        self.init(
            cardID: cardID,
            phase: CardPhase(vendor: card.state),
            stability: card.stability,
            difficulty: card.difficulty,
            dueAt: EpochMillis(vendor: card.due),
            lastReviewedAt: card.lastReview.map(EpochMillis.init(vendor:)),
            elapsedDays: Int(card.elapsedDays.rounded()),
            scheduledDays: Int(card.scheduledDays.rounded()),
            learningStepIndex: card.learningSteps,
            reps: card.reps,
            lapses: card.lapses,
            derivedFromLogID: derivedFromLogID,
            parameterSetID: parameterSetID
        )
    }
}

/// 벤더 오류를 경계에서 감싼다. `FSRSError` 는 절대 `LearnCore` 로 새 나가지 않는다.
func wrapEngineError(_ error: any Error, cardID: CardID?) -> ReviewSchedulingError {
    if let scheduling = error as? ReviewSchedulingError { return scheduling }
    return .engineFailure(cardID: cardID, reason: String(describing: error))
}
