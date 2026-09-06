import Testing
import AppKit
@testable import EditorUI
import CodeEditSourceEditor
import DesignSystem

/// `SourceEditorConfiguration` 조임 값을 고정한다 — 미니맵·폴딩 리본 끄기, 괄호 강조 제거,
/// 12.5pt 에서 행 높이 20px. 마지막 것은 상수를 그대로 비교하지 않고 **`NSFont` 실측값을
/// 통해 역산이 맞는지** 검사한다 — 폴백 폰트가 바뀌어도(예: `IBMPlexMono` 가 나중에 등록돼도)
/// 20px 이 유지되는지가 핵심이라, 상수 하나만 박아두면 그 회귀를 못 잡는다.
@Suite("에디터 설정 조임")
struct EditorUIConfigurationTests {
    @Test("미니맵·폴딩 리본이 꺼져 있다")
    func minimapAndFoldingRibbonOff() {
        let config = EditorUIConfiguration.make()
        #expect(config.peripherals.showMinimap == false)
        #expect(config.peripherals.showFoldingRibbon == false)
    }

    @Test("괄호 강조가 없다 — 무채색 규칙의 예외를 만들지 않는다")
    func noBracketPairEmphasis() {
        let config = EditorUIConfiguration.make()
        #expect(config.appearance.bracketPairEmphasis == nil)
    }

    @Test("폰트 크기가 디자인 토큰의 코드 크기(12.5pt)와 같다")
    func fontSizeMatchesDesignToken() {
        let config = EditorUIConfiguration.make()
        #expect(config.appearance.font.pointSize == Typography.Mono.code.rawValue)
        #expect(Typography.Mono.code.rawValue == 12.5)
    }

    @Test("12.5pt 에서 행 높이가 실측으로 20px 이 된다")
    func lineHeightIsMeasuredAt20Points() {
        let config = EditorUIConfiguration.make()
        let font = config.appearance.font
        // `font.lineHeight` 는 CodeEditSourceEditor 가 공개하는 `NSLayoutManager
        // .defaultLineHeight(for:)` 실측값이다 — 우리가 만든 상수가 아니다.
        let measuredLineHeight = font.lineHeight * config.appearance.lineHeightMultiple
        #expect(abs(measuredLineHeight - Double(Typography.codeLineHeight)) < 0.01)
    }

    @Test("lineHeightMultiple(for:) 은 어떤 폰트 크기에도 20px 을 맞춘다")
    func lineHeightMultipleGeneralizes() {
        // Menlo 14pt 처럼 디자인 기본값이 아닌 폰트로도 역산이 성립하는지 확인한다 —
        // 하드코딩한 배수가 아니라 진짜 함수인지 증명한다.
        let font = EditorUIConfiguration.font(size: 14)
        let multiple = EditorUIConfiguration.lineHeightMultiple(for: font)
        #expect(abs(font.lineHeight * multiple - Double(Typography.codeLineHeight)) < 0.01)
    }

    @Test("폰트 폴백이 실제로 해석된다 — IBMPlexMono 미등록 시 Menlo 로")
    func fontFallbackResolves() {
        let font = EditorUIConfiguration.font()
        #expect(font.pointSize == 12.5)
        // 이 테스트 환경엔 IBMPlexMono 가 등록돼 있지 않다(TokensTests 의 실측과 동일 전제).
        // 그래도 폴백 체인 끝(Menlo 또는 시스템 모노스페이스)까지 반드시 값이 나온다.
        #expect(font.isFixedPitch)
    }
}
