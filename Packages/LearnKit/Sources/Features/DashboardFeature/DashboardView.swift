public import LearnCore
public import SwiftUI
internal import DesignSystem

/// 대시보드("오늘") 화면 — `design/Main.dc.html` 의 본문 영역.
///
/// 위에서부터 2단 카드(이어서 · 오늘의 복습)와 10행 트랙 표다. 세 가지 심리 설계가
/// 레이아웃 자체에 들어 있다.
///
/// - **자이가르닉** — 멈춘 레슨이 화면의 첫 블록이다(`OpenLessonCard`). 진행 중 블록은
///   채우지 않고 빈 윤곽 칸으로 남는다.
/// - **부여된 진도** — 트랙을 연 순간 오리엔테이션 한 칸이 채워진다. 표는 그 사실을
///   숨기지 않고 "01 오리엔테이션은 완료로 기록됨" 이라고 적는다.
/// - **축적 프레이밍** — 스트릭은 "14일째" 하나뿐이다. 만료·경고 문구가 없다.
///
/// 헤더("오늘" + 날짜)는 **셸이 그린다**(`ShellHeader`). 화면이 다시 그리면 `ShellContent`
/// 안에서 제목이 두 번 나온다 — 디자인의 헤더는 7개 화면이 공유하는 셸 크롬이다.
public struct DashboardView: View {
    @State private var model: DashboardModel
    private let onResume: (ResumePoint) -> Void
    private let onStartReview: () -> Void
    private let onOpenTrack: (LanguageID) -> Void

    public init(
        model: DashboardModel = DashboardModel(),
        onResume: @escaping (ResumePoint) -> Void = { _ in },
        onStartReview: @escaping () -> Void = {},
        onOpenTrack: @escaping (LanguageID) -> Void = { _ in }
    ) {
        _model = State(wrappedValue: model)
        self.onResume = onResume
        self.onStartReview = onStartReview
        self.onOpenTrack = onOpenTrack
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            cards
            TrackTable(rows: model.rows) { onOpenTrack($0.languageID) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper)
        .task { await model.load() }
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            OpenLessonCard(resume: model.openLesson, onResume: onResume)
            TodayReviewCard(summary: model.review, onStart: onStartReview)
        }
    }
}
