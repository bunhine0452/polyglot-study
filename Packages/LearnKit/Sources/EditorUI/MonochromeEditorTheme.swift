public import CodeEditSourceEditor
import AppKit
import SwiftUI
import DesignSystem

/// 에디터 문법 하이라이팅 테마. **전부 무채색**이다 — 이 앱의 규칙("색은 상태 표시에만")이
/// 코드 블록 안까지 그대로 적용된다. 화면에 유채색이 보이면 그건 반드시 통과/실패 상태다.
///
/// `EditorTheme` 는 16개 속성을 갖는다(`text`·`insertionPoint`·`invisibles`·`background`·
/// `lineHighlight`·`selection`·`keywords`·`commands`·`types`·`attributes`·`variables`·
/// `values`·`numbers`·`strings`·`characters`·`comments`). 전부 `Palette` 의 무채색
/// 토큰(`ink`·`secondary`·`faint`·`card`·`ruleSoft`)에서만 값을 가져온다 — 새 색을
/// 정의하지 않는다.
///
/// ## `Attribute` 의 한계 — 근사한 부분 `{#theme-weight-limitation}`
///
/// `EditorTheme.Attribute` 는 `bold` 와 `italic` 두 불리언만 지원한다. 이 디자인의 타이포
/// 스케일에는 500(medium) 굵기가 있지만 이 타입으로는 표현할 방법이 없다 — `NSFont` 트레잇
/// 차원이 굵음/기울임뿐이라서다. 그래서 "약한 강조" 는 medium 굵기 대신 **회색을 한 단
/// 낮추는 것**으로 근사했다(`secondary` 대신 `ink`, 또는 `faint` 대신 `secondary`).
/// 키워드·타입·문자열·주석의 위계는 최종적으로 **굵기 2단(regular/bold) × 회색 3단
/// (`ink`/`secondary`/`faint`)** 으로만 만들어진다 — 이탤릭은 어디에도 쓰지 않는다.
public enum MonochromeEditorTheme {
    /// 무채색 문법 테마를 만든다.
    public static func make() -> EditorTheme {
        // 굵기 2단 × 회색 3단. 이 넷의 조합이 이 테마의 위계 전부다.
        let plain = attribute(.ink, bold: false)
        let structural = attribute(.ink, bold: true)      // 키워드 — 가장 두드러진다
        let secondaryStrong = attribute(.secondary, bold: true)   // 타입 — 구조적이지만 한 단 옅다
        let secondaryPlain = attribute(.secondary, bold: false)   // 문자열·값·숫자·데코레이터
        let faintPlain = attribute(.faint, bold: false)           // 주석·투명문자 — 가장 옅다

        return EditorTheme(
            text: plain,
            insertionPoint: nsColor(.ink),
            invisibles: faintPlain,
            background: nsColor(.card),
            lineHighlight: nsColor(.ruleSoft),
            // 선택 영역은 새 색이 아니라 기존 잉크 토큰의 불투명도만 낮춘 워시다.
            selection: nsColor(.ink, opacity: 0.12),
            keywords: structural,
            commands: secondaryStrong,
            types: secondaryStrong,
            attributes: secondaryPlain,
            variables: plain,
            values: secondaryPlain,
            numbers: secondaryPlain,
            strings: secondaryPlain,
            characters: secondaryPlain,
            comments: faintPlain
        )
    }

    /// `Palette` 토큰 이름. 새 색을 만들지 않는다는 규칙을 타입으로도 강제한다 —
    /// 이 enum 의 케이스가 곧 이 테마가 쓸 수 있는 색의 전부다.
    private enum Token {
        case ink, secondary, faint, card, ruleSoft
    }

    private static func color(_ token: Token) -> Color {
        switch token {
        case .ink: Palette.ink
        case .secondary: Palette.secondary
        case .faint: Palette.faint
        case .card: Palette.card
        case .ruleSoft: Palette.ruleSoft
        }
    }

    private static func nsColor(_ token: Token, opacity: Double = 1) -> NSColor {
        NSColor(color(token).opacity(opacity))
    }

    private static func attribute(_ token: Token, bold: Bool) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: nsColor(token), bold: bold, italic: false)
    }
}
