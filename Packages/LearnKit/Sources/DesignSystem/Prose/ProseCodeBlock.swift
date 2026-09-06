public import SwiftUI

/// 읽기 전용 코드 블록. **산문 경로를 지나지 않는다.**
///
/// `AttributedString(markdown:)` 에 코드를 태우면 두 가지를 잃는다 — 모노 폰트가
/// 런 단위로만 붙어 들여쓰기 정렬이 깨지고, 긴 줄이 줄바꿈되면서 가로 스크롤이
/// 사라진다. 코드에서는 그 둘이 곧 의미라서, 별도 뷰로 뺐다.
///
/// 하이라이팅은 하지 않는다. 이 디자인에서 색은 통과·실패 두 상태에만 쓴다 —
/// 화면에 빨강이 보이면 그건 반드시 실패라는 규칙이 그 대가로 유지된다.
public struct ProseCodeBlock: View {
    private let code: String
    private let language: String?

    public init(_ code: String, language: String? = nil) {
        self.code = code
        self.language = language
    }

    /// 마지막 개행 때문에 빈 줄이 하나 더 그려지는 것을 막는다.
    var displayedCode: String {
        var trimmed = Substring(code)
        while trimmed.last == "\n" || trimmed.last == " " { trimmed = trimmed.dropLast() }
        return String(trimmed)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                LabelText(language.uppercased(), color: Palette.faint)
                    .padding(.bottom, Spacing.xs)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                // 줄바꿈을 허용하면 들여쓰기 정렬이 깨진다. 넘치면 가로로 스크롤한다.
                Text(displayedCode)
                    .font(AppFont.mono(.code))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(ProseMetrics.codeLineSpacing)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .padding(.vertical, ProseMetrics.codePaddingVertical)
        .padding(.horizontal, ProseMetrics.codePaddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper)
    }
}
