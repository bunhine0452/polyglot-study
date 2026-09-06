internal import AppKit
internal import DesignSystem
internal import SwiftUI

/// `Typography` 토큰의 이름을 실제 `Font` 로 바꾼다.
///
/// `DesignSystem.AppFont` 가 같은 일을 하지만 **internal** 이라 다른 모듈에서 보이지
/// 않는다. 프리미티브 6종이 덮지 못하는 자리(제목 24pt, 본문 15pt, 라벨 13pt)가 이
/// 화면에 있어 지역 헬퍼를 둔다 — 온보딩 화면도 같은 이유로 같은 헬퍼를 갖고 있다.
enum LessonFont {
    static func sans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        if let family = resolvedSans {
            return .custom(family, fixedSize: size.rawValue).weight(weight)
        }
        return .system(size: size.rawValue, weight: weight)
    }

    static let resolvedSans: String? = {
        let families = Set(NSFontManager.shared.availableFontFamilies)
        for candidate in [Typography.sansFamily, Typography.sansFallback] {
            if families.contains(candidate) || NSFont(name: candidate, size: 12) != nil {
                return candidate
            }
        }
        return nil
    }()
}

/// 이 화면의 치수. 디자인 실측이지만 **폭은 최대값으로만 쓴다** — 아트보드 폭을 고정
/// 폭으로 박으면 사이드바 232 를 더했을 때 창을 넘긴다(온보딩 표에서 실제로 잘렸다).
enum LessonLayout {
    /// 상단 바. 디자인 실측 48px.
    static let topBarHeight: CGFloat = Spacing.xxl
    /// 스텝바. 디자인 실측 44px.
    static let stepBarHeight: CGFloat = Spacing.xl + Spacing.unit + Spacing.xs
    /// 본문 열의 **최대** 폭. 창이 좁으면 줄어든다.
    static let columnMaxWidth: CGFloat = 800
    /// 본문 좌우 여백. 디자인 실측 40px.
    static let horizontalPadding: CGFloat = Spacing.xl + Spacing.unit
    /// 상단 바·스텝바 안쪽 여백.
    static let barPadding: CGFloat = Spacing.l
    /// 스텝 칸 안쪽 여백. 디자인 실측 20px.
    static let stepPadding: CGFloat = Spacing.m + Spacing.xs
    /// 활성 카드 안쪽 여백. 디자인 실측 20px 24px 24px.
    static let cardPaddingTop: CGFloat = Spacing.m + Spacing.xs
    static let cardPaddingHorizontal: CGFloat = Spacing.l
    static let cardPaddingBottom: CGFloat = Spacing.l
    /// 접힌 행 높이. 토큰에서 온다.
    static let rowHeight: CGFloat = Spacing.collapsedBlockHeight
    /// 12px — 8px 그리드에 없어서 반 칸을 더한다. 디자인의 `gap:12px`.
    static let rowGap: CGFloat = Spacing.unit + Spacing.xs
}

/// 체크 표식. 디자인의 `M2 6.5l3 3 5-7` 을 정규화한 것.
struct CheckGlyph: View {
    var size: CGFloat = 12
    var color: Color = Palette.ink

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 2 / 12, y: size * 6.5 / 12))
            path.addLine(to: CGPoint(x: size * 5 / 12, y: size * 9.5 / 12))
            path.addLine(to: CGPoint(x: size * 10 / 12, y: size * 2.5 / 12))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 뒤로 가기 갈매기. 디자인의 `M10 3L5 8l5 5`.
struct BackGlyph: View {
    var size: CGFloat = 16
    var color: Color = Palette.ink

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 10 / 16, y: size * 3 / 16))
            path.addLine(to: CGPoint(x: size * 5 / 16, y: size * 8 / 16))
            path.addLine(to: CGPoint(x: size * 10 / 16, y: size * 13 / 16))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 재생 삼각형. 실행 버튼 앞에 붙는다.
struct RunGlyph: View {
    var size: CGFloat = 10
    var color: Color = Palette.paper

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.2, y: size * 0.1))
            path.addLine(to: CGPoint(x: size * 0.9, y: size * 0.5))
            path.addLine(to: CGPoint(x: size * 0.2, y: size * 0.9))
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
