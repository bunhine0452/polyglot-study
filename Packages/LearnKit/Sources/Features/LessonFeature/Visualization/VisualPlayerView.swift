public import ContentKit
public import DesignSystem
public import SwiftUI

/// 알고리즘 시각화 재생기. `VisualFrameSet` 하나를 받아 프레임을 순서대로, 또는 임의
/// 순서로(스크럽) 보여준다. `design/AlgorithmLesson.dc.html` 우측 패널의 시각화 영역이
/// 이 뷰다.
///
/// - Note: 받는 `VisualFrameSet` 은 지금 `ContentKit.VisualFrameSet` 의 그림자다 —
///   자세한 사정과 없애는 방법은 `VisualFrameSet.swift` 머리말.
///
/// ## 키보드 이동
///
/// 좌/우 화살표가 이전/다음, Home/End 가 처음/끝, 스페이스가 재생/일시정지다. 처음/끝은
/// 눈에 보이는 전용 버튼이 없다 — `design/AlgorithmLesson.dc.html` 의 스크러버가 이전·
/// 재생·다음 세 아이콘뿐이라 그 모양을 그대로 따랐고, 대신 프레임 눈금의 첫/마지막 칸을
/// 눌러도 같은 자리로 간다(스크럽이 이미 요구 기능이므로 새 버튼을 더하지 않았다).
/// 키보드 단축키는 그래서 눈에 안 보이는 버튼(`jumpShortcuts`)에 붙어 있다.
public struct VisualPlayerView: View {
    private let frameSet: VisualFrameSet
    private let tickInterval: Duration
    @State private var state: VisualPlayerState

    public init(_ frameSet: VisualFrameSet, tickInterval: Duration = .milliseconds(900)) {
        self.frameSet = frameSet
        self.tickInterval = tickInterval
        self._state = State(initialValue: VisualPlayerState(frameCount: frameSet.scene.frameCount))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            header
            scene
            caption
            scrubber
        }
        .background(jumpShortcuts)
        .task(id: state.isPlaying) {
            guard state.isPlaying else { return }
            while true {
                try? await Task.sleep(for: tickInterval)
                if Task.isCancelled { return }
                state.tick()
                if !state.isPlaying { return }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            MonoText(frameSet.id, size: .micro, color: Palette.secondary)
            Spacer(minLength: Spacing.s)
            MonoText(
                "단계 \(state.currentIndex + 1) / \(state.frameCount)", size: .label,
                color: Palette.secondary)
        }
    }

    @ViewBuilder
    private var scene: some View {
        switch frameSet.scene {
        case .array(let visual):
            ArraySceneView(visual: visual, frameIndex: state.currentIndex)
        case .graph(let visual):
            GraphSceneView(visual: visual, frameIndex: state.currentIndex)
        case .table(let visual):
            TableSceneView(visual: visual, frameIndex: state.currentIndex)
        }
    }

    /// 자막은 매 프레임 항상 보인다 — 그림만으로는 "왜" 가 안 남는다.
    private var caption: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Rule(.emphasis, axis: .vertical)
            // 범위 밖이면 빈 문자열이다 — 재생기는 언제나 한 줄을 그리고, 그 자리가
            // 비는 것과 화면이 흔들리는 것 중 전자를 고른다.
            Text(frameSet.scene.caption(at: state.currentIndex) ?? "")
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scrubber: some View {
        HStack(spacing: Spacing.m) {
            controlCluster
            frameTicks
        }
    }

    private var controlCluster: some View {
        HStack(spacing: 0) {
            controlButton(system: "backward.fill", isEnabled: !state.isAtStart) {
                state.stepBackward()
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            Rule(.hard, axis: .vertical)
            controlButton(system: state.isPlaying ? "pause.fill" : "play.fill", isEnabled: true, inverted: state.isPlaying) {
                state.togglePlaying()
            }
            .keyboardShortcut(.space, modifiers: [])
            Rule(.hard, axis: .vertical)
            controlButton(system: "forward.fill", isEnabled: !state.isAtEnd) {
                state.stepForward()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: Rules.thickness) }
    }

    private func controlButton(
        system: String, isEnabled: Bool, inverted: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(inverted ? Palette.paper : Palette.ink)
                .frame(width: 27, height: 27)
                .background(inverted ? Palette.ink : Palette.paper)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    /// 눈금 하나가 프레임 하나다. 지나온 프레임은 잉크, 남은 프레임은 흐린 룰 색.
    /// 눌러 스크럽한다 — 첫/마지막 눈금이 곧 처음/끝으로 가는 길이다.
    private var frameTicks: some View {
        HStack(spacing: 3) {
            ForEach(0..<state.frameCount, id: \.self) { index in
                Button {
                    state.scrub(to: index)
                } label: {
                    Rectangle()
                        .fill(index <= state.currentIndex ? Palette.ink : Palette.ruleSoft)
                        .frame(height: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("프레임 눈금")
        .accessibilityValue("\(state.currentIndex + 1) / \(state.frameCount)")
    }

    /// Home/End 를 처음/끝으로 매핑하는 숨은 버튼. 크기 0 + 투명이라 화면엔 안 보이지만
    /// 뷰 계층에는 남아 있어 단축키가 계속 반응한다.
    private var jumpShortcuts: some View {
        HStack(spacing: 0) {
            Button("") { state.jumpToStart() }
                .keyboardShortcut(.home, modifiers: [])
            Button("") { state.jumpToEnd() }
                .keyboardShortcut(.end, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}
