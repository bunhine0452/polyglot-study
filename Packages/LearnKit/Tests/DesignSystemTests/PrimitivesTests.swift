import SwiftUI
import Testing

@testable import DesignSystem

/// 색을 0xRRGGBB 로 되돌린다. 토큰과 프리미티브가 **같은 값**을 쓰는지 보기 위한 것이라
/// 근사 비교가 아니라 정수 일치로 본다.
func hexValue(_ color: Color) -> UInt32 {
    let converted = NSColor(color).usingColorSpace(.sRGB)!
    let r = UInt32((converted.redComponent * 255).rounded())
    let g = UInt32((converted.greenComponent * 255).rounded())
    let b = UInt32((converted.blueComponent * 255).rounded())
    return (r << 16) | (g << 8) | b
}

@Suite("프리미티브 · 기하")
struct PrimitivesGeometryTests {
    @Test("룰은 두 종류의 1px 과 하나의 2px 강조가 전부다")
    func ruleWeights() {
        #expect(Rule.Weight.allCases.count == 3)
        #expect(Rule.Weight.hard.thickness == Rules.thickness)
        #expect(Rule.Weight.soft.thickness == Rules.thickness)
        #expect(Rule.Weight.emphasis.thickness == Rules.emphasisThickness)
        #expect(hexValue(Rule.Weight.hard.color) == 0x141414)
        #expect(hexValue(Rule.Weight.soft.color) == 0xD9D9D6)
        // 강조는 굵기만 다른 같은 잉크색이다 — 세 번째 색을 만들지 않는다.
        #expect(hexValue(Rule.Weight.emphasis.color) == hexValue(Rule.Weight.hard.color))
    }

    @Test("상태 도트는 8px, 거터 표식은 6px — 둘 다 토큰에서 온다")
    func statusDotSizes() {
        #expect(StatusDot.Size.dot.points == Rules.statusDotSize)
        #expect(StatusDot.Size.dot.points == 8)
        #expect(StatusDot.Size.gutterMark.points == Rules.gutterMarkSize)
        #expect(StatusDot.Size.gutterMark.points == 6)
        #expect(StatusDot.Size.allCases.count == 2)
    }

    @Test("진도칸은 6px 이고 표 안에서만 그 두 배가 된다")
    func progressCellHeights() {
        #expect(SegmentedProgress.Height.slim.points == Rules.progressCellSize)
        #expect(SegmentedProgress.Height.slim.points == 6)
        #expect(SegmentedProgress.Height.tall.points == Rules.progressCellSize * 2)
        #expect(SegmentedProgress.Height.allCases.count == 2)
    }

    @Test("버튼 높이는 36px 하나뿐이다")
    func buttonHeight() {
        #expect(FlatButton.height == 36)
    }
}

@Suite("프리미티브 · 색")
struct PrimitivesColorTests {
    @Test("도트 5종의 채움과 테두리가 전부 토큰 값이다")
    func statusDotPalette() {
        #expect(hexValue(StatusDot.Style.pass.fill) == 0x2F8F4E)
        #expect(hexValue(StatusDot.Style.fail.fill) == 0xC8372D)
        #expect(hexValue(StatusDot.Style.ink.fill) == 0x141414)
        #expect(hexValue(StatusDot.Style.empty.fill) == 0xF4F4F2)
        #expect(hexValue(StatusDot.Style.emptyInk.fill) == 0xF4F4F2)

        #expect(StatusDot.Style.pass.stroke == nil)
        #expect(StatusDot.Style.fail.stroke == nil)
        #expect(StatusDot.Style.ink.stroke == nil)
        #expect(hexValue(StatusDot.Style.empty.stroke!) == 0x9A9A97)
        #expect(hexValue(StatusDot.Style.emptyInk.stroke!) == 0x141414)
    }

    @Test("채색 도트는 통과와 실패 둘뿐 — 나머지는 무채색")
    func onlyTwoChromaticDots() {
        func chroma(_ color: Color) -> Double {
            let c = NSColor(color).usingColorSpace(.sRGB)!
            let comps = [c.redComponent, c.greenComponent, c.blueComponent]
            return comps.max()! - comps.min()!
        }
        let chromatic = StatusDot.Style.allCases.filter { chroma($0.fill) > 0.05 }
        #expect(chromatic == [.pass, .fail])
    }

    @Test("진도칸 3상태 — 완료만 채워지고 나머지는 테두리로 구분된다")
    func progressCellStates() {
        #expect(hexValue(ProgressCellState.done.fill) == 0x141414)
        #expect(hexValue(ProgressCellState.current.fill) == 0xF4F4F2)
        #expect(hexValue(ProgressCellState.future.fill) == 0xF4F4F2)
        #expect(hexValue(ProgressCellState.done.stroke) == 0x141414)
        #expect(hexValue(ProgressCellState.current.stroke) == 0x141414)
        #expect(hexValue(ProgressCellState.future.stroke) == 0xC9C9C6)
        // 현재와 미래는 채움이 같다 — 테두리 색만으로 갈린다.
        #expect(ProgressCellState.current.stroke != ProgressCellState.future.stroke)
    }

    @Test("버튼 2종은 잉크와 종이의 정확한 반전이다")
    func flatButtonInversion() {
        #expect(hexValue(FlatButton.Emphasis.primary.background) == hexValue(Palette.ink))
        #expect(hexValue(FlatButton.Emphasis.primary.foreground) == hexValue(Palette.paper))
        #expect(hexValue(FlatButton.Emphasis.secondary.background) == hexValue(Palette.paper))
        #expect(hexValue(FlatButton.Emphasis.secondary.foreground) == hexValue(Palette.ink))
        #expect(FlatButton.Emphasis.allCases.count == 2)
    }
}

@Suite("프리미티브 · 진도 조립")
struct SegmentedProgressAssemblyTests {
    @Test("완료 3 / 전체 6 이면 완료3 · 현재1 · 미래2")
    func threeOfSix() {
        let progress = SegmentedProgress(completed: 3, total: 6)
        #expect(progress.cellStates == [.done, .done, .done, .current, .future, .future])
    }

    @Test("아직 시작 전이면 첫 칸이 현재")
    func zeroCompleted() {
        #expect(SegmentedProgress(completed: 0, total: 3).cellStates == [.current, .future, .future])
    }

    @Test("다 끝났으면 현재 칸이 없다")
    func allCompleted() {
        #expect(SegmentedProgress(completed: 4, total: 4).cellStates == [.done, .done, .done, .done])
    }

    @Test("showsCurrent 를 끄면 현재 칸이 생기지 않는다")
    func withoutCurrent() {
        let progress = SegmentedProgress(completed: 1, total: 3, showsCurrent: false)
        #expect(progress.cellStates == [.done, .future, .future])
    }

    @Test("완료 수가 전체를 넘거나 음수여도 칸 수는 전체와 같다")
    func outOfRangeIsClamped() {
        #expect(SegmentedProgress(completed: 99, total: 5).cellStates.count == 5)
        #expect(SegmentedProgress(completed: 99, total: 5).cellStates.allSatisfy { $0 == .done })
        #expect(SegmentedProgress(completed: -3, total: 2).cellStates == [.current, .future])
        #expect(SegmentedProgress(completed: 0, total: 0).cellStates.isEmpty)
        #expect(SegmentedProgress(completed: 1, total: -1).cellStates.isEmpty)
    }
}

@Suite("프리미티브 · 폰트 해석")
struct AppFontTests {
    /// 해석 결과는 토큰이 지목한 두 이름 중 하나이거나 `nil`(시스템 폰트)이다.
    /// 임의의 제3의 폰트로 새는 경로가 없다는 것이 여기서 지키는 것이다.
    @Test("모노는 Plex → SF Mono → 시스템 순으로만 떨어진다")
    func monoFallbackChain() {
        let allowed: [String?] = [Typography.monoFamily, Typography.monoFallback, nil]
        #expect(allowed.contains(AppFont.resolvedMono), "예상 밖 모노 폰트: \(String(describing: AppFont.resolvedMono))")
    }

    @Test("산스도 같은 순서로만 떨어진다")
    func sansFallbackChain() {
        let allowed: [String?] = [Typography.sansFamily, Typography.sansFallback, nil]
        #expect(allowed.contains(AppFont.resolvedSans), "예상 밖 산스 폰트: \(String(describing: AppFont.resolvedSans))")
    }
}
