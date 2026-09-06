import Testing
import SwiftUI
@testable import DesignSystem

@Suite("디자인 토큰")
struct TokensTests {
    @Test("상태색은 둘뿐이다 — 나머지는 전부 무채색")
    func onlyTwoStatusColors() {
        // 무채색이란 R==G==B 는 아니다. 종이·잉크는 미세하게 따뜻하다(F4F4F2, 141414).
        // 여기서 검사하는 것은 "채도가 낮다" 이고, 상태색만 그 선을 넘는다.
        func chroma(_ color: Color) -> Double {
            let c = NSColor(color).usingColorSpace(.sRGB)!
            let comps = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)]
            return comps.max()! - comps.min()!
        }
        let neutrals: [Color] = [
            Palette.paper, Palette.card, Palette.ink, Palette.secondary,
            Palette.faint, Palette.zeroDigit, Palette.ruleHard, Palette.ruleSoft, Palette.cellEmpty,
        ]
        for color in neutrals {
            #expect(chroma(color) < 0.05, "무채색이어야 하는데 채도가 \(chroma(color))")
        }
        #expect(chroma(Palette.pass) > 0.2)
        #expect(chroma(Palette.fail) > 0.2)
    }

    @Test("간격은 전부 8px 베이스라인의 배수 또는 반 칸")
    func spacingOnGrid() {
        let values: [CGFloat] = [Spacing.s, Spacing.m, Spacing.l, Spacing.xl, Spacing.xxl]
        for v in values {
            #expect(v.truncatingRemainder(dividingBy: Spacing.unit) == 0, "\(v) 가 8의 배수가 아님")
        }
        #expect(Spacing.xs == Spacing.unit / 2)
    }

    @Test("폴백 폰트 이름이 이 머신에서 실제로 해석된다")
    func fallbackFontsResolve() {
        // "SF Mono" 가 NSFont(name:) 으로 해석되지 않는 것을 실측하고 Menlo 로 바꿨다.
        // 폴백 이름이 죽어 있으면 화면은 우연히 맞아도 토큰이 거짓말을 한다.
        #expect(NSFont(name: Typography.sansFallback, size: 13) != nil,
                "\(Typography.sansFallback) 해석 실패")
        #expect(NSFont(name: Typography.monoFallback, size: 13) != nil,
                "\(Typography.monoFallback) 해석 실패")
    }

    @Test("타입 스케일이 디자인 실측값과 일치한다")
    func typeScaleMatchesDesign() {
        #expect(Typography.Sans.allCases.map(\.rawValue).sorted() == [11, 12, 13, 14, 15, 18, 20, 24, 28, 32])
        #expect(Typography.Mono.allCases.map(\.rawValue).sorted() == [11, 11.5, 12, 12.5])
    }
}
