import SwiftUI
import Testing

@testable import DesignSystem

@Suite("앱 셸 · 내비게이션")
struct ShellDestinationTests {
    @Test("최상위 목적지는 정확히 5개, 디자인 순서 그대로")
    func fourDestinationsInOrder() {
        #expect(ShellDestination.allCases.map(\.title) == ["오늘", "트랙", "복습", "연습장", "툴체인"])
    }

    @Test("설정은 목적지가 아니다 — 푸터 크롬이다")
    func settingsIsNotADestination() {
        #expect(!ShellDestination.allCases.map(\.title).contains("설정"))
    }

    @Test("rawValue 는 저장·복원용 안정 키다")
    func stableRawValues() {
        #expect(ShellDestination.allCases.map(\.rawValue) == ["today", "tracks", "review", "scratch", "toolchain"])
        #expect(ShellDestination(rawValue: "review") == .review)
        #expect(ShellDestination(rawValue: "settings") == nil)
    }
}

@Suite("앱 셸 · 사이드바 크롬")
struct SidebarChromeTests {
    @Test("사이드바는 232px 이고 그 안에 오른쪽 1px 룰이 포함된다")
    func sidebarWidthIncludesItsRule() {
        // 디자인의 border-box 와 같아야 한다 — 룰을 밖에 더하면 본문이 1px 밀린다.
        #expect(Spacing.sidebarWidth == 232)
        #expect(Sidebar.horizontalPadding + Rules.thickness < Spacing.sidebarWidth)
        let contentWidth = Spacing.sidebarWidth - Rules.thickness
        #expect(contentWidth + Rules.thickness == Spacing.sidebarWidth)
        #expect(contentWidth == 231)
    }

    @Test("행 높이 40px 과 좌우 여백 24px 은 8px 그리드 위에 있다")
    func sidebarMetricsOnGrid() {
        #expect(Sidebar.rowHeight == 40)
        #expect(Sidebar.rowHeight.truncatingRemainder(dividingBy: Spacing.unit) == 0)
        #expect(Sidebar.horizontalPadding == Spacing.l)
        // 브랜드 상단 여백만 그리드 밖이다. 디자인 실측값이라 그대로 둔다.
        #expect(Sidebar.topPadding == 28)
    }

    @Test("활성 항목은 잉크 반전이다 — 강조색도 캡슐도 아니다")
    func activeRowIsInkInversion() {
        #expect(hexValue(SidebarRowStyle.background(isSelected: true, isHovering: false)) == hexValue(Palette.ink))
        #expect(hexValue(SidebarRowStyle.foreground(isSelected: true, isInteractive: true)) == hexValue(Palette.paper))
        // 호버 여부가 활성 행의 색을 바꾸지 않는다.
        #expect(
            hexValue(SidebarRowStyle.background(isSelected: true, isHovering: true))
                == hexValue(SidebarRowStyle.background(isSelected: true, isHovering: false))
        )
    }

    @Test("비활성 항목은 종이 위 잉크, 눌리지 않는 푸터는 2차색")
    func inactiveRowColors() {
        #expect(hexValue(SidebarRowStyle.background(isSelected: false, isHovering: false)) == hexValue(Palette.paper))
        #expect(hexValue(SidebarRowStyle.foreground(isSelected: false, isInteractive: true)) == hexValue(Palette.ink))
        #expect(hexValue(SidebarRowStyle.foreground(isSelected: false, isInteractive: false)) == hexValue(Palette.secondary))
    }

    @Test("호버 배경은 무채색 한 단계 — 반투명이 아니다")
    func hoverStaysOpaque() {
        let hover = SidebarRowStyle.background(isSelected: false, isHovering: true)
        #expect(hexValue(hover) == hexValue(Palette.card))
        #expect(NSColor(hover).usingColorSpace(.sRGB)!.alphaComponent == 1)
    }
}

@Suite("앱 셸 · 조립")
struct AppShellAssemblyTests {
    @Test("셸이 선택을 바인딩으로 되돌려 준다")
    func selectionRoundTrips() {
        var stored: ShellDestination = .today
        let binding = Binding(get: { stored }, set: { stored = $0 })
        _ = AppShell(selection: binding) { destination in
            Text(destination.title)
        }
        binding.wrappedValue = .toolchain
        #expect(stored == .toolchain)
    }

    @Test("배지 기본값은 전부 nil — 셸이 카운트를 지어내지 않는다")
    func badgeDefaultsToNil() {
        var selection: ShellDestination = .today
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let shell = AppShell(selection: binding) { _ in EmptyView() }
        #expect(ShellDestination.allCases.allSatisfy { shell.badge($0) == nil })
    }

    @Test("배지는 주입한 그대로 전달된다")
    func badgeIsPassedThrough() {
        var selection: ShellDestination = .today
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let shell = AppShell(selection: binding, badge: { $0 == .review ? "12" : nil }) { _ in EmptyView() }
        #expect(shell.badge(.review) == "12")
        #expect(shell.badge(.today) == nil)
        #expect(shell.badge(.toolchain) == nil)
    }
}
