internal import Foundation
internal import DesignSystem
internal import OnboardingFeature
internal import SwiftUI

/// 앱 타깃의 **유일한** 컴파일 소스. 화면은 전부 LearnKit 안에 있고 여기서는 셸만 세운다.
@main
struct PolyglotApp: App {
    @State private var selection: ShellDestination = Self.initialDestination

    /// 디버그용 시작 목적지. 스냅샷으로 특정 화면을 굽거나, 개발 중 매번 클릭하지 않기 위해.
    /// 값이 없거나 이상하면 조용히 `.today` 로 떨어진다 — 릴리스 동작에 영향을 주지 않는다.
    private static var initialDestination: ShellDestination {
        ProcessInfo.processInfo.environment["POLYGLOT_START_DESTINATION"]
            .flatMap(ShellDestination.init(rawValue:)) ?? .today
    }

    init() {
        Snapshot.captureAndTerminateIfRequested()
    }

    var body: some Scene {
        WindowGroup("Polyglot") {
            RootView(selection: $selection)
        }
        // 아트보드 실측 1440×900.
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        // 시스템 크롬(신호등·타이틀바·메뉴바)은 OS 가 그린다. 숨기면 신호등이 사이드바
        // 브랜드 블록 위로 겹친다 — 디자인에 그 자리가 없다.
    }
}

private struct RootView: View {
    @Binding var selection: ShellDestination

    /// 툴체인 감지는 서브프로세스를 10번 띄운다. 화면을 오갈 때마다 다시 훑지 않도록
    /// 모델을 셸 수명에 붙인다.
    @State private var onboarding = OnboardingModel()

    var body: some View {
        AppShell(selection: $selection, badge: badge) { destination in
            ShellContent {
                ShellHeader(destination.title, trailing: Self.today)
                switch destination {
                case .toolchain:
                    // 첫 실제 화면. 목 데이터가 아니라 RunnerKit 의 ToolchainProbe 가
                    // 이 머신을 실제로 훑은 결과를 그린다.
                    OnboardingView(model: onboarding)
                case .today, .tracks, .review:
                    PlaceholderPanel(destination: destination)
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 680)
    }

    /// 아직 데이터 계층이 셸에 붙지 않았다. 배지가 붙을 자리만 비워 둔다 —
    /// 화면이 생기면 여기서 실제 카운트를 넘긴다.
    private func badge(for destination: ShellDestination) -> String? {
        // 지금 배지를 낼 수 있는 곳은 툴체인뿐이다 — 나머지는 데이터 계층이 아직 안 붙었다.
        guard destination == .toolchain else { return nil }
        let unresolved = onboarding.summary.missing + onboarding.summary.problem
        return unresolved > 0 ? String(unresolved) : nil
    }

    private static let today: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: Date())
    }()
}

/// 화면 7종이 아직 없다는 사실을 숨기지 않는 자리. 동시에 프리미티브 6종이 실제로
/// 렌더되는지 눈으로 확인하는 지점이기도 하다 — 화면 세션이 들어오면 통째로 사라진다.
private struct PlaceholderPanel: View {
    let destination: ShellDestination

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LabelText("화면 준비 중 · \(destination.rawValue)")

            SegmentedProgress(completed: 3, total: 6)
                .frame(width: 360)

            HStack(spacing: Spacing.m) {
                dot(.pass, "설치됨")
                dot(.empty, "미설치")
                dot(.fail, "스텁 감지")
            }

            HStack(spacing: Spacing.m) {
                FlatButton("이어서 하기", shortcutHint: "↩") {}
                FlatButton("복습 시작", emphasis: .secondary) {}
            }

            Rule(.soft)

            MonoText("DesignSystem · Primitives 6 · Shell 1", size: .label, color: Palette.secondary)
        }
    }

    private func dot(_ style: StatusDot.Style, _ caption: String) -> some View {
        HStack(spacing: Spacing.s) {
            StatusDot(style)
            MonoText(caption, size: .label)
        }
    }
}
