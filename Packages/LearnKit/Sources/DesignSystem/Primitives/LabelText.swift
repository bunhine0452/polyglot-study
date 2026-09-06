public import SwiftUI

/// 섹션 라벨과 캡션. 11px · 미디엄 · 넓은 자간 · 2차색이 고정이다.
///
/// 디자인 파일의 `.lbl` 클래스가 그대로 이것이다. 화면 코드가 `Text(...).font(...)` 로
/// 라벨을 다시 조립하면 자간이 빠지면서 이 디자인의 인상이 무너진다.
public struct LabelText: View {
    /// 11px 기준 0.04em. 자간만 토큰에 없어서 여기서 유도한다.
    private static let trackingRatio: CGFloat = 0.04

    private let content: String
    private let color: Color

    public init(_ content: String, color: Color = Palette.secondary) {
        self.content = content
        self.color = color
    }

    public var body: some View {
        Text(content)
            .font(AppFont.sans(.micro, weight: .medium))
            .tracking(Typography.Sans.micro.rawValue * Self.trackingRatio)
            .foregroundStyle(color)
    }
}
