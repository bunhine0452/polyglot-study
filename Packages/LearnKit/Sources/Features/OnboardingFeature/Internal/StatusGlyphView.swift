internal import SwiftUI
internal import DesignSystem

/// 상태 도트(실제로는 라운딩 없는 사각) 표시. **임시 로컬 헬퍼** — `DesignSystem.StatusDot`
/// 프리미티브가 나오면 이걸로 교체한다.
struct StatusGlyphView: View {
    let glyph: StatusGlyph
    let tint: Color

    var body: some View {
        Group {
            switch glyph {
            case .filledPass, .filledFail:
                Rectangle().fill(tint)
            case .emptySquare:
                Rectangle().strokeBorder(tint, lineWidth: Rules.thickness)
            }
        }
        .frame(width: Rules.statusDotSize, height: Rules.statusDotSize)
    }
}
