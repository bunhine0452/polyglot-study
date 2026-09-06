public import SwiftUI

/// 코드·수치 텍스트. 버전 문자열, 진도 분수(`7 / 24`), 종료 코드, 헥스 덤프가 전부 이걸 쓴다.
///
/// 항상 `monospacedDigit` 이다 — 실행 중 숫자가 바뀌어도 열이 흔들리면 안 된다.
public struct MonoText: View {
    private let content: String
    private let size: Typography.Mono
    private let weight: Font.Weight
    private let color: Color

    public init(
        _ content: String,
        size: Typography.Mono = .label,
        weight: Font.Weight = .regular,
        color: Color = Palette.ink
    ) {
        self.content = content
        self.size = size
        self.weight = weight
        self.color = color
    }

    public var body: some View {
        Text(content)
            .font(AppFont.mono(size, weight: weight))
            .foregroundStyle(color)
    }
}
