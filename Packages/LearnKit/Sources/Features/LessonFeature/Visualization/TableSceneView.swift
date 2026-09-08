public import ContentKit
public import DesignSystem
internal import SwiftUI

/// 표 장면 하나. DP(배낭·LCS)가 이 뷰를 쓴다.
///
/// 이미 채워진 칸 전부의 참조선을 한꺼번에 그리면 격자가 금방 어수선해지므로, 참조선은
/// 지금 이 프레임에서 막 계산되는(`current`) 칸의 것만 그린다 — "이 값이 어디서 왔는가"가
/// 가장 궁금한 순간이 바로 그 칸이 확정되는 순간이다.
struct TableSceneView: View {
    let visual: TableVisual
    let frameIndex: Int

    private static let cellSize: CGFloat = 34
    private static let headerWidth: CGFloat = 34

    private var frame: TableFrame { visual.frames[frameIndex] }

    private struct Position: Hashable {
        let row: Int
        let column: Int
    }

    /// 같은 칸이 두 번 채워져 있어도(저작 실수) 죽지 않게 마지막 값을 남긴다 — 그림자
    /// 모델에는 `ContentKit` 쪽 유일성 검증이 없다.
    private var cellsByPosition: [Position: TableCell] {
        Dictionary(
            frame.cells.map { (Position(row: $0.row, column: $0.column), $0) },
            uniquingKeysWith: { _, latest in latest })
    }

    var body: some View {
        let cells = cellsByPosition
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            ForEach(0..<visual.rowCount, id: \.self) { row in
                dataRow(row: row, cells: cells)
            }
        }
        .overlay(alignment: .topLeading) { referenceLines }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.headerWidth, height: Self.cellSize)
            ForEach(visual.columnHeaders.indices, id: \.self) { index in
                MonoText(visual.columnHeaders[index], size: .micro, color: Palette.secondary)
                    .frame(width: Self.cellSize, height: Self.cellSize)
            }
        }
    }

    private func dataRow(row: Int, cells: [Position: TableCell]) -> some View {
        HStack(spacing: 0) {
            MonoText(visual.rowHeaders[row], size: .micro, color: Palette.secondary)
                .frame(width: Self.headerWidth, height: Self.cellSize)
            ForEach(0..<visual.columnCount, id: \.self) { column in
                cellView(cells[Position(row: row, column: column)])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: TableCell?) -> some View {
        if let cell {
            MonoText(
                "\(cell.value)", size: .micro,
                weight: cell.role == .current ? .semibold : .regular,
                color: textColor(for: cell.role)
            )
            .frame(width: Self.cellSize, height: Self.cellSize)
            .background(cell.role == .current ? Palette.ink : Palette.card)
            .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: Rules.thickness) }
        } else {
            Rectangle()
                .fill(Palette.paper)
                .overlay { Rectangle().strokeBorder(Palette.faint, lineWidth: Rules.thickness) }
                .frame(width: Self.cellSize, height: Self.cellSize)
        }
    }

    private func textColor(for role: TableCellRole) -> Color {
        switch role {
        case .current: Palette.paper
        case .filled: Palette.secondary
        case .base: Palette.ink
        }
    }

    /// `current` 칸이 참조하는 칸들로 점선을 긋는다. 한 프레임에 `current` 칸이 여럿이면
    /// 전부 그린다 — 하나뿐이라고 가정하지 않는다.
    private var referenceLines: some View {
        Canvas { context, _ in
            for cell in frame.cells where cell.role == .current {
                let toCenter = center(row: cell.row, column: cell.column)
                for ref in cell.from {
                    let fromCenter = center(row: ref.row, column: ref.column)
                    var path = Path()
                    path.move(to: fromCenter)
                    path.addLine(to: toCenter)
                    context.stroke(
                        path, with: .color(Palette.secondary),
                        style: StrokeStyle(lineWidth: Rules.thickness, dash: [3, 2]))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func center(row: Int, column: Int) -> CGPoint {
        CGPoint(
            x: Self.headerWidth + CGFloat(column) * Self.cellSize + Self.cellSize / 2,
            y: Self.cellSize + CGFloat(row) * Self.cellSize + Self.cellSize / 2
        )
    }
}
