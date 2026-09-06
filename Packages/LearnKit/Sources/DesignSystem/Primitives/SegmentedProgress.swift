public import SwiftUI

/// 진도 칸 하나의 상태. 세 가지가 전부다.
public enum ProgressCellState: Sendable, CaseIterable {
    /// 완료 — 잉크 채움.
    case done
    /// 현재 — 종이 바탕에 잉크 1px.
    case current
    /// 미도래 — 종이 바탕에 흐린 1px.
    case future

    var fill: Color {
        switch self {
        case .done: Palette.ink
        case .current, .future: Palette.paper
        }
    }

    var stroke: Color {
        switch self {
        case .done, .current: Palette.ink
        case .future: Palette.cellEmpty
        }
    }
}

/// 칸 단위 진도 막대. 퍼센트 게이지가 아니라 **레슨·블록 개수를 그대로 센다** —
/// 24레슨 트랙이면 칸이 정확히 24개다.
///
/// `LazyHGrid` 를 쓰지 않는 이유: 지연 레이아웃이 스크롤 밖 칸의 2px 간격을 보장하지
/// 않는다. 칸 수가 최대 수십 개라 전부 그려도 비용이 없다.
public struct SegmentedProgress: View {
    /// 칸 높이. 폭은 컨테이너를 균등 분할한다(디자인의 `repeat(N, 1fr)`).
    public enum Height: Sendable, CaseIterable {
        /// 6px — 카드 안의 블록 진도.
        case slim
        /// 12px — 트랙 표의 행. 토큰 칸 크기의 2배다.
        case tall

        public var points: CGFloat {
            switch self {
            case .slim: Rules.progressCellSize
            case .tall: Rules.progressCellSize * 2
            }
        }
    }

    private let states: [ProgressCellState]
    private let height: Height

    /// 조립 결과. 렌더 없이 칸 배열을 단언하기 위한 창구다.
    var cellStates: [ProgressCellState] { states }

    public init(_ states: [ProgressCellState], height: Height = .slim) {
        self.states = states
        self.height = height
    }

    /// 완료 개수와 전체 개수에서 조립한다. `completed` 번째 칸이 현재 칸이 된다.
    /// - Parameter showsCurrent: 트랙이 끝났거나 아직 시작 전이면 `false`.
    public init(completed: Int, total: Int, height: Height = .slim, showsCurrent: Bool = true) {
        let done = max(0, min(completed, total))
        let states = (0..<max(0, total)).map { index -> ProgressCellState in
            if index < done { return .done }
            if index == done, showsCurrent { return .current }
            return .future
        }
        self.init(states, height: height)
    }

    public var body: some View {
        HStack(spacing: Rules.progressCellGap) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                Rectangle()
                    .fill(state.fill)
                    .overlay {
                        Rectangle().strokeBorder(state.stroke, lineWidth: Rules.thickness)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: height.points)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진도 \(states.count(where: { $0 == .done })) / \(states.count)")
    }
}
