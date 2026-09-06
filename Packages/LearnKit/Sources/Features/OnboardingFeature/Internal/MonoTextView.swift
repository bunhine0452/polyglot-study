internal import SwiftUI
internal import DesignSystem

/// 모노스페이스 텍스트. **임시 로컬 헬퍼** — `DesignSystem.MonoText` 프리미티브가 나오면
/// 이걸로 교체한다.
struct MonoTextView: View {
    let text: String
    var size: Typography.Mono = .label
    var color: Color = Palette.ink

    var body: some View {
        Text(text)
            .font(.appMono(size))
            .foregroundStyle(color)
    }
}
