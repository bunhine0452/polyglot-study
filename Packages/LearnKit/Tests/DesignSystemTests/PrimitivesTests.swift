import AppKit
import Foundation
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
    ///
    /// **표기는 두 가지**다 — 토큰은 PostScript 형(`"IBMPlexSansKR"`)으로 적혀 있지만,
    /// 같은 폰트가 표시명(`"IBM Plex Sans KR"`)으로 등록돼 있으면 해석기는 그쪽을
    /// 돌려준다. 그래서 이름 그대로가 아니라 **정규화한 키**로 견준다.
    static func resolvesToOneOf(_ resolved: String?, _ tokens: [String]) -> Bool {
        guard let resolved else { return true }  // nil = 시스템 폰트. 허용된 종착지다.
        let allowed = Set(tokens.map(AppFont.normalizedFamilyKey))
        return allowed.contains(AppFont.normalizedFamilyKey(resolved))
    }

    @Test("모노는 Plex → SF Mono → 시스템 순으로만 떨어진다")
    func monoFallbackChain() {
        #expect(
            Self.resolvesToOneOf(
                AppFont.resolvedMono, [Typography.monoFamily, Typography.monoFallback]),
            "예상 밖 모노 폰트: \(String(describing: AppFont.resolvedMono))")
    }

    @Test("산스도 같은 순서로만 떨어진다")
    func sansFallbackChain() {
        #expect(
            Self.resolvesToOneOf(
                AppFont.resolvedSans, [Typography.sansFamily, Typography.sansFallback]),
            "예상 밖 산스 폰트: \(String(describing: AppFont.resolvedSans))")
    }

    @Test("등록되지 않은 이름만 주면 해석은 nil 이다 — 아무 폰트나 집지 않는다")
    func unknownNamesResolveToNil() {
        #expect(AppFont.resolve(["결코-존재하지-않는-패밀리-A", "결코-존재하지-않는-패밀리-B"]) == nil)
    }

    @Test("PostScript 형과 표시명 둘 다 같은 패밀리로 해석된다")
    func bothFamilyNameSpellingsResolve() throws {
        // 이 머신에 실제로 등록된 패밀리 중 이름에 공백이 있는 것 하나를 고른다.
        // 특정 폰트를 가정하지 않는다 — 두 표기가 **같은 곳**으로 가는지만 본다.
        let displayName = try #require(
            NSFontManager.shared.availableFontFamilies.first { $0.contains(" ") },
            "공백이 든 패밀리명이 하나도 없다 — 이 머신의 폰트 목록이 이상하다")
        let postScriptish = displayName.replacingOccurrences(of: " ", with: "")

        #expect(AppFont.resolve([displayName]) == displayName)
        #expect(AppFont.resolve([postScriptish]) == displayName)
    }

    @Test("첫 후보가 없으면 둘째로, 순서를 지킨다")
    func candidateOrderIsHonored() throws {
        let present = try #require(NSFontManager.shared.availableFontFamilies.first)
        #expect(AppFont.resolve(["결코-존재하지-않는-패밀리", present]) == present)
    }
}

/// 화면 넷이 각자 만들었던 폰트 해석 사본이 되살아나지 않는지 본다.
///
/// 사본이 생긴 이유는 단 하나 — `AppFont` 가 internal 이었다는 것 — 이고 그건 고쳤다.
/// 남은 위험은 새 화면이 습관으로 같은 헬퍼를 또 만드는 것이라, 소스를 직접 읽는다.
@Suite("폰트 · 사본 봉인")
struct FontResolutionSealingTests {
    static var featureRoot: URL {
        URL(fileURLWithPath: #filePath)  // .../Tests/DesignSystemTests/PrimitivesTests.swift
            .deletingLastPathComponent()  // .../Tests/DesignSystemTests
            .deletingLastPathComponent()  // .../Tests
            .deletingLastPathComponent()  // .../LearnKit
            .appendingPathComponent("Sources/Features")
    }

    static var swiftFiles: [URL] {
        get throws {
            var found: [URL] = []
            var stack = [featureRoot]
            while let directory = stack.popLast() {
                for entry in try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: [.isDirectoryKey]
                ) {
                    if (try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        stack.append(entry)
                    } else if entry.pathExtension == "swift" {
                        found.append(entry)
                    }
                }
            }
            return found.sorted { $0.path < $1.path }
        }
    }

    @Test("소스 경로 계산이 맞다 — 빈 디렉터리를 훑고 통과하지 않게")
    func sourceRootIsWhereWeThink() throws {
        let names = Set(try Self.swiftFiles.map(\.lastPathComponent))
        for required in ["OnboardingView.swift", "ReviewView.swift", "DashboardView.swift"] {
            #expect(names.contains(required), "\(required) 를 못 찾았다")
        }
    }

    @Test("화면 코드가 폰트를 직접 해석하지 않는다 — AppFont 하나만 판다")
    func featuresDoNotResolveFontsThemselves() throws {
        // `NSFontManager`·`NSFont(name:` 는 해석기의 재료이고, `Font.custom` 은 그 결과다.
        // 화면에 이 셋 중 하나라도 있으면 사본이 다시 생긴 것이다.
        let banned = ["NSFontManager", "NSFont(name:", "Font.custom(", ".custom("]
        var hits: [String] = []
        for file in try Self.swiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                for needle in banned where line.contains(needle) {
                    hits.append("\(file.lastPathComponent):\(offset + 1) — \(needle)")
                }
            }
        }
        #expect(hits.isEmpty, "폰트 해석 사본이 돌아왔다:\n\(hits.joined(separator: "\n"))")
    }
}
