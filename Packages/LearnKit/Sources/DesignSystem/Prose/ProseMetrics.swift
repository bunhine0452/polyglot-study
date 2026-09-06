internal import SwiftUI

/// 산문 렌더러의 치수. **여기 있는 값은 전부 토큰에서 유도하거나, 토큰에 없어서
/// 지역 상수로 둔 것들**이다 — 화면 코드가 이 숫자를 다시 적지 않게 하는 것이 목적이다.
///
/// 토큰에 없어 여기서 정한 것: 행간 세 개(`bodyLineSpacing`·`compactLineSpacing`·
/// `headingLineSpacing`)와 불릿 한 변. `Typography.codeLineHeight` 는 **에디터** 용
/// 20px 이라 산문 안의 코드(디자인 실측 18px)와 값이 다르다.
enum ProseMetrics {
    /// 블록과 블록 사이. 디자인의 `gap:12px`.
    static let blockGap: CGFloat = Spacing.unit + Spacing.xs
    /// 목록 항목 사이. 문단 사이보다 좁다.
    static let listItemGap: CGFloat = Spacing.unit
    /// 마커가 차지하는 열. 본문이 이 열에서 시작한다.
    static let markerColumn: CGFloat = Spacing.m
    /// 인용 막대와 본문 사이.
    static let quoteIndent: CGFloat = Spacing.m
    /// 불릿 한 변. 이 디자인에 원은 없다.
    static let bulletSize: CGFloat = 3

    /// 본문 15pt 에서 행 높이 24px 이 되도록 하는 여유.
    static let bodyLineSpacing: CGFloat = 6
    /// 보조 산문 13pt 에서 행 높이 20px.
    static let compactLineSpacing: CGFloat = 4
    /// 제목의 행간. 24pt 에서 32px.
    static let headingLineSpacing: CGFloat = 3

    /// 산문 안 코드의 행 높이. 디자인 실측 18px — `Typography.codeLineHeight`(20px,
    /// 에디터용)와 의도적으로 다르다.
    static let codeLineSpacing: CGFloat = 4
    static let codePaddingVertical: CGFloat = Spacing.unit + Spacing.xs
    static let codePaddingHorizontal: CGFloat = Spacing.m
}

extension ProseView.Scale {
    /// 본문 서체.
    var baseSize: Typography.Sans {
        switch self {
        case .body: .body
        case .compact: .label
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .body: ProseMetrics.bodyLineSpacing
        case .compact: ProseMetrics.compactLineSpacing
        }
    }

    /// 제목 크기. 6단계를 타입 스케일 네 칸에 접는다 — 레슨 산문에 h4 아래는 없다.
    func headingSize(level: Int) -> Typography.Sans {
        switch (self, max(1, min(level, 6))) {
        case (.body, 1): .title
        case (.body, 2): .subtitle
        case (.body, 3): .brand
        case (.body, _): .body
        case (.compact, 1), (.compact, 2): .brand
        case (.compact, _): .note
        }
    }

    var inlineStyle: InlineMarkdown.Style {
        InlineMarkdown.Style(
            base: AppFont.sans(baseSize),
            mono: AppFont.mono(.code),
            color: Palette.ink,
            codeColor: Palette.ink
        )
    }

    func headingStyle(level: Int) -> InlineMarkdown.Style {
        InlineMarkdown.Style(
            base: AppFont.sans(headingSize(level: level), weight: .semibold),
            mono: AppFont.mono(.code, weight: .semibold),
            color: Palette.ink,
            codeColor: Palette.ink
        )
    }
}
