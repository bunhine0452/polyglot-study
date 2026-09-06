internal import DesignSystem
internal import SwiftUI

/// 이 화면의 치수. 디자인 실측이지만 **폭은 최대값으로만 쓴다** — 아트보드 폭을 고정
/// 폭으로 박으면 사이드바 232 를 더했을 때 창을 넘긴다(온보딩 표에서 실제로 잘렸다).
/// 결과 패널만 예외다 — `Spacing.resultPanelWidth` 가 이미 그 예약을 토큰화하고 있다.
enum EditorLayout {
    /// 상단 바. 디자인 실측 48px.
    static let topBarHeight: CGFloat = Spacing.xxl
    /// 과제 바. 디자인 실측 56px — 8px 그리드에 없어 `xxl + s` 로 유도한다.
    static let taskBarHeight: CGFloat = Spacing.xxl + Spacing.s
    /// 코드 패널의 파일명 머리줄. 디자인 실측 32px, 정확히 `Spacing.xl`.
    static let codeHeaderHeight: CGFloat = Spacing.xl
    /// 코드 거터 폭. 디자인 실측 56px.
    static let gutterWidth: CGFloat = 56
    /// 결과 패널의 탭 바·상태 행 높이. 디자인 실측 40px.
    static let panelRowHeight: CGFloat = Spacing.xl + Spacing.s
    /// 테스트 목록 한 행. 디자인 실측 32px, 정확히 `Spacing.xl`.
    static let testRowHeight: CGFloat = Spacing.xl
    /// SQL 결과 표 한 행. `{#sql-row-padding}` — 디자인 실측 28px, `l + xs` 로 유도한다.
    static let sqlRowHeight: CGFloat = Spacing.l + Spacing.xs
    /// 상단 바·과제 바 안쪽 여백.
    static let barPadding: CGFloat = Spacing.l
    /// 결과 패널 안쪽 좌우 여백.
    static let panelPadding: CGFloat = Spacing.l
}
