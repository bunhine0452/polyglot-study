public import SwiftUI

/// 1px 선. 이 디자인에서 영역을 가르는 유일한 수단이다 — 카드 테두리도, 그림자도,
/// 배경 대비도 쓰지 않는다.
///
/// `Divider` 를 쓰지 않는 이유: `Divider` 의 색과 두께는 시스템이 정하고 hairline 으로
/// 흐려진다. 여기서는 논리 1px 과 정확한 토큰 색이 필요하다.
public struct Rule: View {
    /// 두 종류의 룰 + 레슨 활성 카드의 2px 강조. 셋이 전부다.
    public enum Weight: Sendable, CaseIterable {
        /// 영역을 가르는 굵은 선. 잉크색 1px.
        case hard
        /// 같은 영역 안의 행 구분. 흐린 1px.
        case soft
        /// 활성 블록 카드의 상단 강조. 잉크색 2px.
        case emphasis

        public var color: Color {
            switch self {
            case .hard, .emphasis: Palette.ruleHard
            case .soft: Palette.ruleSoft
            }
        }

        public var thickness: CGFloat {
            switch self {
            case .hard, .soft: Rules.thickness
            case .emphasis: Rules.emphasisThickness
            }
        }
    }

    public enum Axis: Sendable, CaseIterable {
        case horizontal
        case vertical
    }

    private let weight: Weight
    private let axis: Axis

    public init(_ weight: Weight = .hard, axis: Axis = .horizontal) {
        self.weight = weight
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(weight.color)
            .frame(
                width: axis == .vertical ? weight.thickness : nil,
                height: axis == .horizontal ? weight.thickness : nil
            )
            .accessibilityHidden(true)
    }
}
