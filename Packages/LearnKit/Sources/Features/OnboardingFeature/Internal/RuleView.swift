internal import SwiftUI
internal import DesignSystem

/// 1px 룰. **임시 로컬 헬퍼** — `DesignSystem.Rule` 프리미티브가 나오면 이걸로 교체한다.
struct RuleView: View {
    var color: Color = Palette.ruleSoft
    var thickness: CGFloat = Rules.thickness

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
    }
}
