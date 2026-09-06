public import CodeEditSourceEditor
public import AppKit
public import DesignSystem

/// 이 앱이 실제로 쓰는 `SourceEditorConfiguration`. 기본값을 그대로 쓰지 않고 조인다
/// `{#editor-config-tuning}`.
///
/// - 미니맵과 폴딩 리본을 끈다 — 레슨 예제는 수십 줄을 넘지 않고, 스위스 그리드 디자인에
///   화면을 잠식하는 보조 위젯을 두지 않는다는 원칙과도 맞지 않는다.
/// - 괄호 강조(`bracketPairEmphasis`)를 없앤다 — 강조 애니메이션과 테두리색이 이 무채색
///   규칙에서 예외를 만든다. 괄호 짝은 색 없이도 들여쓰기로 충분히 읽힌다.
/// - 12.5pt 모노(`Typography.Mono.code`)에서 행 높이가 정확히 20px(`Typography.
///   codeLineHeight`)이 되도록 `lineHeightMultiple` 을 **폰트 실측값으로 역산**한다.
///   `CodeEditSourceEditor` 는 절대 픽셀이 아니라 배수로 행간을 받기 때문에, 하드코딩한
///   배수를 쓰면 폴백 폰트가 바뀔 때마다(`IBMPlexMono` 미등록 시 `Menlo`) 조용히 어긋난다.
public enum EditorUIConfiguration {
    /// 코드 블록에 쓸 모노 폰트. `IBMPlexMono` 가 등록돼 있지 않으면(현재 앱 상태) `Menlo` 로,
    /// 그것도 실패하면 시스템 모노스페이스로 떨어진다 — 셋 다 `Typography` 에 이미 기록된
    /// 폴백 순서다.
    public static func font(size: CGFloat = Typography.Mono.code.rawValue) -> NSFont {
        NSFont(name: Typography.monoFamily, size: size)
            ?? NSFont(name: Typography.monoFallback, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// 주어진 폰트에서 `Typography.codeLineHeight` 를 만드는 배수. `NSFont.lineHeight` 는
    /// `CodeEditSourceEditor` 가 공개하는 실측 헬퍼(`NSLayoutManager().defaultLineHeight`) 다 —
    /// 여기서 상수를 하드코딩하지 않고 그 실측값으로 나눈다.
    public static func lineHeightMultiple(for font: NSFont) -> Double {
        Double(Typography.codeLineHeight) / font.lineHeight
    }

    /// 이 앱의 기본 에디터 설정. 언어(`CodeLanguage`)는 `SourceEditorConfiguration` 이
    /// 아니라 `SourceEditor` 생성자가 직접 받으므로 여기엔 없다.
    public static func make() -> SourceEditorConfiguration {
        let resolvedFont = font()
        return SourceEditorConfiguration(
            appearance: .init(
                theme: MonochromeEditorTheme.make(),
                font: resolvedFont,
                lineHeightMultiple: lineHeightMultiple(for: resolvedFont),
                wrapLines: true,
                // 무채색 규칙 예외를 만드는 강조 하이라이트를 없앤다.
                bracketPairEmphasis: nil
            ),
            peripherals: .init(
                showMinimap: false,
                showFoldingRibbon: false
            )
        )
    }
}
