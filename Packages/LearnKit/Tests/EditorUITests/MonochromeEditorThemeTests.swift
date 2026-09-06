import Testing
import AppKit
@testable import EditorUI
import CodeEditSourceEditor

/// `EditorTheme` 16개 속성이 전부 무채색이고, 위계가 굵기 2단 × 회색 3단으로만
/// 만들어지는지 고정한다. `Packages/LearnKit/Tests/DesignSystemTests/TokensTests.swift`
/// 의 `chroma` 관용구를 그대로 쓴다 — 잉크·종이가 미세하게 따뜻해서 `r==g==b` 대신
/// "채도가 낮다" 를 검사한다.
@Suite("무채색 에디터 테마")
struct MonochromeEditorThemeTests {
    static func components(_ color: NSColor) -> (r: Double, g: Double, b: Double) {
        let rgb = color.usingColorSpace(.sRGB)!
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }

    static func chroma(_ color: NSColor) -> Double {
        let c = components(color)
        return max(c.r, c.g, c.b) - min(c.r, c.g, c.b)
    }

    static func allColors(_ theme: EditorTheme) -> [(name: String, color: NSColor)] {
        [
            ("text", theme.text.color),
            ("insertionPoint", theme.insertionPoint),
            ("invisibles", theme.invisibles.color),
            ("background", theme.background),
            ("lineHighlight", theme.lineHighlight),
            ("selection", theme.selection),
            ("keywords", theme.keywords.color),
            ("commands", theme.commands.color),
            ("types", theme.types.color),
            ("attributes", theme.attributes.color),
            ("variables", theme.variables.color),
            ("values", theme.values.color),
            ("numbers", theme.numbers.color),
            ("strings", theme.strings.color),
            ("characters", theme.characters.color),
            ("comments", theme.comments.color),
        ]
    }

    @Test("16개 속성을 전부 찾았다")
    func has16Properties() {
        let theme = MonochromeEditorTheme.make()
        #expect(Self.allColors(theme).count == 16)
    }

    @Test("16개 속성이 전부 무채색이다 — 코드 블록에 유채색이 0건")
    func allPropertiesAreAchromatic() {
        let theme = MonochromeEditorTheme.make()
        for (name, color) in Self.allColors(theme) {
            #expect(Self.chroma(color) < 0.05, "\(name) 이 무채색이 아니다(채도 \(Self.chroma(color)))")
        }
    }

    @Test("이탤릭은 어디에도 쓰지 않는다 — 굵기와 회색만으로 구분한다")
    func noItalicAnywhere() {
        let theme = MonochromeEditorTheme.make()
        let attributes: [(String, EditorTheme.Attribute)] = [
            ("text", theme.text), ("invisibles", theme.invisibles), ("keywords", theme.keywords),
            ("commands", theme.commands), ("types", theme.types), ("attributes", theme.attributes),
            ("variables", theme.variables), ("values", theme.values), ("numbers", theme.numbers),
            ("strings", theme.strings), ("characters", theme.characters), ("comments", theme.comments),
        ]
        #expect(attributes.count == 12)
        for (name, attribute) in attributes {
            #expect(!attribute.italic, "\(name) 이 이탤릭을 쓴다")
        }
    }

    @Test("키워드가 가장 어둡고 굵다 — 구조적으로 가장 두드러진다")
    func keywordsAreMostProminent() {
        let theme = MonochromeEditorTheme.make()
        #expect(theme.keywords.bold)
        #expect(Self.components(theme.keywords.color).r < Self.components(theme.types.color).r)
    }

    @Test("타입은 키워드보다 옅고, 문자열은 타입과 같은 회색이지만 굵지 않다")
    func typesAndStringsShareGrayButNotWeight() {
        let theme = MonochromeEditorTheme.make()
        #expect(theme.types.bold)
        #expect(!theme.strings.bold)
        let typesGray = Self.components(theme.types.color).r
        let stringsGray = Self.components(theme.strings.color).r
        #expect(abs(typesGray - stringsGray) < 0.001, "types 와 strings 는 같은 회색 단이어야 한다")
    }

    @Test("주석이 가장 옅다 — 가장 덜 두드러진다")
    func commentsAreFaintest() {
        let theme = MonochromeEditorTheme.make()
        #expect(!theme.comments.bold)
        let commentsGray = Self.components(theme.comments.color).r
        let typesGray = Self.components(theme.types.color).r
        let keywordsGray = Self.components(theme.keywords.color).r
        #expect(keywordsGray < typesGray)
        #expect(typesGray < commentsGray)
    }

    @Test("같은 make() 호출은 같은 테마를 만든다 — 상태 없는 순수 팩토리")
    func makeIsDeterministic() {
        #expect(MonochromeEditorTheme.make() == MonochromeEditorTheme.make())
    }
}
