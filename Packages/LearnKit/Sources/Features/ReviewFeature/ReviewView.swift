public import SwiftUI
internal import DesignSystem
internal import LearnCore

/// 복습 화면 — `design/Review.dc.html` 을 그대로 따른다: 12칸 진행 헤더, 질문/답 카드,
/// 동일 크기 4버튼.
///
/// 목 데이터가 아니라 `ReviewModel` 이 부르는 실제 `ReviewScheduler`·`CardStateStore`·
/// `ReviewLogStore` 결과를 그린다. 이 뷰 자체는 테스트하지 않는다 — `OnboardingFeature`
/// 와 같은 관용구로, 렌더 없이 확인 가능한 값(스타일 상수·스펙 계산)은
/// `RatingButtonMetrics`/`RatingButtonRow` 로 떼어내 모델과 함께 테스트한다.
public struct ReviewView: View {
    @State private var model: ReviewModel

    public init(model: ReviewModel) {
        _model = State(wrappedValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content(for: model.currentCard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper)
        .task { await model.load() }
    }

    @ViewBuilder
    private func content(for card: ReviewModel.QueueCard?) -> some View {
        if let card {
            ScrollView {
                cardColumn(card)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xxl + Spacing.unit)
                    .padding(.horizontal, Spacing.xl + Spacing.unit)
                    .padding(.bottom, Spacing.l)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Header

    /// 48px 커스텀 헤더. 표준 `ShellHeader` 를 쓰지 않는 이유는 이 화면의 헤더가
    /// (뒤로가기 + 압축 제목) · (12칸 진행) · (연속일수) 3분할 구조라 다른 화면들의
    /// "큰 제목 + 우측 라벨" 형태와 근본적으로 다르기 때문이다 — `OnboardingView` 도 같은
    /// 이유로 자체 헤더를 그린다.
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Palette.ink)
                    Text("복습")
                        .font(AppFont.sans(.label, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    LabelText("오늘")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.m) {
                    SegmentedProgress(
                        completed: model.completedCount,
                        total: max(model.totalCount, 1),
                        height: .slim
                    )
                    .frame(width: 240)
                    HStack(spacing: 0) {
                        MonoText("\(model.completedCount)", size: .label, weight: .semibold)
                        MonoText(" / \(model.totalCount)", size: .label)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: Spacing.s) {
                    LabelText("연속 복습")
                    Text("\(model.streakDays)일째")
                        .font(AppFont.sans(.label, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.l)
            .frame(height: 48)
            Rule(.hard)
        }
    }

    // MARK: - Card column

    private func cardColumn(_ card: ReviewModel.QueueCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                LabelText(card.content.contextLabel)
                Spacer(minLength: Spacing.l)
                LabelText(reviewHistoryCaption(for: card))
            }

            questionCard(card.content)
            answerCard(card.content)

            Spacer(minLength: Spacing.unit)

            ratingRow

            HStack(alignment: .top) {
                Text(ReviewCopy.intervalExplanation)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(Palette.faint)
                Spacer(minLength: Spacing.l)
                Text(ReviewCopy.noCardRemovalNotice)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(Palette.faint)
            }
        }
    }

    private func questionCard(_ content: ReviewCardContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LabelText("질문", color: Palette.ink)
            Text(content.question)
                .font(AppFont.sans(.subtitle, weight: .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(alignment: .top) { Rule(.emphasis) }
    }

    private func answerCard(_ content: ReviewCardContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LabelText("답")
            Text(content.answer)
                .font(AppFont.sans(.body))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let codeExample = content.codeExample {
                MonoText(codeExample, size: .label)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.paper)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(alignment: .top) { Rule(.soft) }
    }

    // MARK: - Rating row

    /// 4개 버튼 전부 `RatingButtonView` 하나로 찍어낸다 — rating 별로 다른 뷰 타입이나
    /// 다른 modifier 체인을 쓰지 않는다. `{#review-no-nudge}`
    private var ratingRow: some View {
        HStack(spacing: Spacing.s) {
            ForEach(model.ratingSpecs) { spec in
                RatingButtonView(spec: spec) {
                    Task { await model.choose(spec.rating) }
                }
            }
        }
    }

    // MARK: - Empty / finished

    private var emptyState: some View {
        VStack(spacing: Spacing.s) {
            Spacer(minLength: 0)
            if model.isLoading {
                LabelText("불러오는 중…")
            } else if let errorMessage = model.errorMessage {
                LabelText(errorMessage, color: Palette.fail)
            } else if model.isFinished {
                LabelText("오늘 복습을 모두 마쳤습니다.")
            } else {
                LabelText("오늘 복습할 카드가 없습니다.")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 문구 조립

    /// "마지막 복습 3일 전 · 4번째" / 첫 복습이면 "첫 복습".
    ///
    /// `model.now` 를 기준으로 계산한다(`Date()` 를 직접 부르지 않는다) — 고정 클록을
    /// 주입한 프리뷰·테스트에서도 값이 흔들리지 않는다.
    private func reviewHistoryCaption(for card: ReviewModel.QueueCard) -> String {
        let ordinal = card.snapshot.reps + 1
        guard let last = card.snapshot.lastReviewedAt else {
            return "첫 복습"
        }
        let daysAgo = max(0, model.now.minutes(since: last) / 1_440)
        return daysAgo == 0
            ? "오늘 복습 · \(ordinal)번째"
            : "마지막 복습 \(daysAgo)일 전 · \(ordinal)번째"
    }
}
