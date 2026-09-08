public import ContentKit
public import DesignSystem
internal import SwiftUI

/// 그래프 장면 하나. BFS·DFS·다익스트라와, 특수 경우인 트리가 전부 이 뷰를 쓴다.
///
/// 좌표는 저작 시점에 이미 정해져 있다(``GraphNode/x``·``GraphNode/y``) — 이 뷰는 배치를
/// 계산하지 않고, 저작된 좌표를 지금 뷰 크기에 맞게 **선형으로만** 늘리고 줄인다(``Layout``).
struct GraphSceneView: View {
    let visual: GraphVisual
    let frameIndex: Int

    /// 노드 한 변. 그래프는 배열 칸(40px)보다 촘촘하게 배치되는 편이라 조금 줄였다.
    private static let nodeSize: CGFloat = 30
    /// 좌표 정규화의 여백 — 노드 반지름만큼은 비워야 가장자리 노드가 잘리지 않는다.
    private static let padding: CGFloat = nodeSize / 2 + 10

    private var frame: GraphFrame { visual.frames[frameIndex] }

    var body: some View {
        GeometryReader { proxy in
            let layout = Layout(nodes: visual.nodes, size: proxy.size, padding: Self.padding)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for edge in visual.edges {
                        draw(edge, layout: layout, into: &context)
                    }
                }
                ForEach(visual.nodes, id: \.id) { node in
                    nodeView(node)
                        .position(layout.point(for: node))
                }
            }
        }
        .frame(minHeight: 180)
    }

    // MARK: - 간선

    private func draw(_ edge: GraphEdge, layout: Layout, into context: inout GraphicsContext) {
        guard let from = visual.nodes.first(where: { $0.id == edge.from }),
            let to = visual.nodes.first(where: { $0.id == edge.to })
        else { return }
        var path = Path()
        path.move(to: layout.point(for: from))
        path.addLine(to: layout.point(for: to))
        let style = edgeStyle(for: edge)
        context.stroke(
            path, with: .color(style.color),
            style: StrokeStyle(lineWidth: style.width, dash: style.dash))
    }

    private struct EdgeStyle {
        let color: Color
        let width: CGFloat
        let dash: [CGFloat]
    }

    /// 역할별 선 스타일. 팔레트가 무채색뿐이라 굵기·점선으로 구분한다.
    private func edgeStyle(for edge: GraphEdge) -> EdgeStyle {
        guard let state = frame.edgeStates.first(where: { matches($0, edge) }) else {
            return EdgeStyle(color: Palette.ink, width: Rules.thickness, dash: [])
        }
        switch state.role {
        case .frontier:
            return EdgeStyle(color: Palette.faint, width: Rules.thickness, dash: [4, 3])
        case .current:
            return EdgeStyle(color: Palette.ink, width: Rules.emphasisThickness, dash: [4, 3])
        case .visited:
            return EdgeStyle(color: Palette.secondary, width: Rules.thickness, dash: [])
        case .settled:
            return EdgeStyle(color: Palette.ink, width: Rules.emphasisThickness, dash: [])
        }
    }

    /// 무방향 간선은 저작된 순서를 안 가린다 — `GraphVisual.edgeExists` 와 같은 규칙.
    private func matches(_ state: GraphEdgeState, _ edge: GraphEdge) -> Bool {
        (state.from == edge.from && state.to == edge.to)
            || (!edge.directed && state.from == edge.to && state.to == edge.from)
    }

    // MARK: - 노드

    @ViewBuilder
    private func nodeView(_ node: GraphNode) -> some View {
        let role = frame.nodeStates.first(where: { $0.id == node.id })?.role
        let distance = frame.distances.first(where: { $0.id == node.id })?.value

        MonoText(
            node.label, size: .micro,
            weight: role == .current ? .semibold : .regular,
            color: textColor(for: role)
        )
        .frame(width: Self.nodeSize, height: Self.nodeSize)
        .background(role == .current ? Palette.ink : Palette.paper)
        .overlay { Rectangle().strokeBorder(borderColor(for: role), style: strokeStyle(for: role)) }
        .overlay(alignment: .bottom) {
            if let distance {
                MonoText(Self.formatted(distance), size: .micro, color: Palette.faint)
                    .fixedSize()
                    .offset(y: 14)
            }
        }
    }

    private func textColor(for role: GraphRole?) -> Color {
        switch role {
        case .current: Palette.paper
        case .visited: Palette.faint
        case .frontier, .settled, nil: Palette.ink
        }
    }

    private func borderColor(for role: GraphRole?) -> Color {
        switch role {
        case .frontier: Palette.faint
        case .visited: Palette.faint
        case .current, .settled, nil: Palette.ink
        }
    }

    /// `frontier`(아직 후보일 뿐)는 점선, `settled`(최종 확정)는 굵은 실선 — 나머지는
    /// 기본 1px.
    private func strokeStyle(for role: GraphRole?) -> StrokeStyle {
        switch role {
        case .frontier: StrokeStyle(lineWidth: Rules.thickness, dash: [3, 2])
        case .settled: StrokeStyle(lineWidth: Rules.emphasisThickness)
        case .current, .visited, nil: StrokeStyle(lineWidth: Rules.thickness)
        }
    }

    private static func formatted(_ value: Double) -> String {
        let rounded = value.rounded()
        if rounded == value { return String(Int(rounded)) }
        return String((value * 10).rounded() / 10)
    }

    /// 저작된 좌표를 뷰 크기에 맞게 선형 정규화한다 — 배치를 계산하지 않는다.
    private struct Layout {
        let minX: Double
        let maxX: Double
        let minY: Double
        let maxY: Double
        let size: CGSize
        let padding: CGFloat

        init(nodes: [GraphNode], size: CGSize, padding: CGFloat) {
            let xs = nodes.map(\.x)
            let ys = nodes.map(\.y)
            minX = xs.min() ?? 0
            maxX = xs.max() ?? 0
            minY = ys.min() ?? 0
            maxY = ys.max() ?? 0
            self.size = size
            self.padding = padding
        }

        func point(for node: GraphNode) -> CGPoint {
            CGPoint(
                x: normalize(node.x, min: minX, max: maxX, extent: size.width),
                y: normalize(node.y, min: minY, max: maxY, extent: size.height))
        }

        /// 값이 하나뿐이라 범위가 0이면(모든 노드가 한 줄에 몰려 있으면) 가운데로 둔다 —
        /// 0으로 나누는 대신 명시적으로 처리한다.
        private func normalize(_ value: Double, min: Double, max: Double, extent: CGFloat)
            -> CGFloat
        {
            guard max > min else { return extent / 2 }
            let ratio = (value - min) / (max - min)
            return padding + CGFloat(ratio) * (extent - 2 * padding)
        }
    }
}
