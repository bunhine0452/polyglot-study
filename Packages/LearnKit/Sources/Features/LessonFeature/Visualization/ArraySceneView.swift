public import ContentKit
public import DesignSystem
internal import SwiftUI

/// 배열 장면 하나. 정렬·이진 탐색·투 포인터·슬라이딩 윈도우가 전부 이 뷰를 쓴다 —
/// 장면 모델이 이미 그 넷을 하나로 묶었으므로(``ArrayVisual``) 렌더러도 하나면 된다.
///
/// 세 줄로 그린다: 값 칸 · 인덱스 · 포인터 이름. `design/AlgorithmLesson.dc.html` 의
/// 배열 장면과 같은 순서다.
struct ArraySceneView: View {
    let visual: ArrayVisual
    let frameIndex: Int

    /// 디자인 실측 40px 정사각 칸. `Tokens` 의 8px 그리드에 없는 값이라 여기서 고정한다
    /// (`FlatButton.height` 와 같은 관용구).
    private static let cellSize: CGFloat = 40

    private var frame: ArrayFrame { visual.frames[frameIndex] }
    private var values: [Int] { visual.values(at: frameIndex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    cell(at: index, value: value)
                }
            }
            HStack(spacing: 0) {
                ForEach(values.indices, id: \.self) { index in
                    MonoText("\(index)", size: .micro, color: Palette.faint)
                        .frame(width: Self.cellSize)
                }
            }
            HStack(spacing: 0) {
                ForEach(values.indices, id: \.self) { index in
                    MonoText(pointerLabel(at: index) ?? "", size: .micro, weight: .medium)
                        .frame(width: Self.cellSize)
                }
            }
        }
    }

    private func cell(at index: Int, value: Int) -> some View {
        let role = segmentRole(at: index)
        return MonoText(
            "\(value)", size: .code,
            weight: role == .highlighted ? .semibold : .regular,
            color: textColor(for: role)
        )
        .frame(width: Self.cellSize, height: Self.cellSize)
        .background(role == .highlighted ? Palette.ink : Palette.card)
        .overlay { Rectangle().strokeBorder(borderColor(for: role), lineWidth: Rules.thickness) }
    }

    private func textColor(for role: ArraySegmentRole?) -> Color {
        switch role {
        case .highlighted: Palette.paper
        case .excluded: Palette.faint
        case nil: Palette.ink
        }
    }

    private func borderColor(for role: ArraySegmentRole?) -> Color {
        switch role {
        case .highlighted: Palette.ink
        case .excluded: Palette.ruleSoft
        case nil: Palette.ink
        }
    }

    /// 이 인덱스를 덮는 구간의 역할. 여러 구간이 겹치면 강조가 이긴다 — "지금 봐야 할 곳"이
    /// "이제 상관없는 곳"보다 항상 위다.
    private func segmentRole(at index: Int) -> ArraySegmentRole? {
        var found: ArraySegmentRole?
        for segment in frame.segments where (segment.start...segment.end).contains(index) {
            if segment.role == .highlighted { return .highlighted }
            found = segment.role
        }
        return found
    }

    /// 이 인덱스를 가리키는 포인터 이름들. 겹치는 경우는 드물지만 있으면 쉼표로 잇는다.
    private func pointerLabel(at index: Int) -> String? {
        let names = frame.pointers.filter { $0.index == index }.map(\.name)
        return names.isEmpty ? nil : names.joined(separator: ",")
    }
}
