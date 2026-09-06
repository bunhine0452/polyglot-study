public import SwiftUI

/// 정사각 상태 표식. **원이 아니다** — 이 디자인에 곡선은 없다.
///
/// 크기는 두 가지뿐이고 둘 다 토큰에서 온다: 8px 도트(`Rules.statusDotSize`)와
/// 에디터 거터의 6px 표식(`Rules.gutterMarkSize`).
public struct StatusDot: View {
    /// 디자인 파일에 실제로 등장하는 다섯 가지가 전부다.
    /// 임의 색을 받지 않는 이유는 "빨강이 보이면 반드시 실패" 규칙을 지키기 위해서다.
    public enum Style: Sendable, CaseIterable {
        /// 통과·설치됨. 녹색 채움.
        case pass
        /// 실패·스텁. 적색 채움.
        case fail
        /// 값이 있음(레지스터 비트 1 등). 잉크 채움.
        case ink
        /// 미설치. 종이 바탕에 흐린 1px 테두리.
        case empty
        /// 값이 없음(레지스터 비트 0 등). 종이 바탕에 잉크 1px 테두리.
        case emptyInk

        var fill: Color {
            switch self {
            case .pass: Palette.pass
            case .fail: Palette.fail
            case .ink: Palette.ink
            case .empty, .emptyInk: Palette.paper
            }
        }

        var stroke: Color? {
            switch self {
            case .pass, .fail, .ink: nil
            case .empty: Palette.faint
            case .emptyInk: Palette.ink
            }
        }
    }

    public enum Size: Sendable, CaseIterable {
        /// 8px — 표·목록의 상태 도트.
        case dot
        /// 6px — 에디터 거터의 진단 표식, SQL diff 의 누락 행 표식.
        case gutterMark

        public var points: CGFloat {
            switch self {
            case .dot: Rules.statusDotSize
            case .gutterMark: Rules.gutterMarkSize
            }
        }
    }

    private let style: Style
    private let size: Size
    private let label: String?

    /// - Parameter label: 보이스오버용 설명. 도트는 시각 정보만 담으므로 없으면 숨긴다.
    public init(_ style: Style, size: Size = .dot, label: String? = nil) {
        self.style = style
        self.size = size
        self.label = label
    }

    public var body: some View {
        Rectangle()
            .fill(style.fill)
            .overlay {
                if let stroke = style.stroke {
                    Rectangle().strokeBorder(stroke, lineWidth: Rules.thickness)
                }
            }
            .frame(width: size.points, height: size.points)
            .accessibilityHidden(label == nil)
            .accessibilityLabel(label ?? "")
    }
}
