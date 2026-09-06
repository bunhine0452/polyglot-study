internal import SwiftUI
internal import DesignSystem

/// 마이크로 라벨 텍스트(11px, 넓은 자간, 2차색). **임시 로컬 헬퍼** —
/// `DesignSystem.LabelText` 프리미티브가 나오면 이걸로 교체한다.
struct LabelTextView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppFont.sans(.micro, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(Palette.secondary)
    }
}
