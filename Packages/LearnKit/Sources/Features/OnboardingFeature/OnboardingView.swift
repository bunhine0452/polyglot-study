public import SwiftUI
internal import DesignSystem
internal import Foundation
internal import LanguageKit

/// 온보딩 화면 — 앱의 첫 실제 화면. 목 데이터가 아니라 `OnboardingModel` 이 부르는
/// 실제 `ToolchainProbe` 감지 결과를 그린다.
///
/// 레이아웃은 `design/Onboarding.dc.html` 을 그대로 따른다: 10행 표(열 폭
/// 120/120/128/480/352), 상단 집계, 하단 다시 검사·시작 버튼. `DesignSystem` 에 아직
/// `Rule`·`StatusDot`·`MonoText`·`FlatButton`·`LabelText` 프리미티브가 없어서(같은 시각에
/// 다른 세션이 작업 중) `Internal/` 아래에 지역 헬퍼로 그렸다 — 프리미티브가 나오면
/// 그 자리만 교체하면 되도록 작은 뷰로 쪼개 뒀다.
public struct OnboardingView: View {
    @State private var model: OnboardingModel
    private let onContinue: () -> Void

    /// MVP 트랙(HANDOFF.md 의 제품 결정 — Python·SQL·Swift). 감지 결과가 아니라
    /// 고정된 제품 범위라 하드코딩이다.
    private static let mvpToolIDs: Set<String> = ["python3", "sqlite3", "swiftc"]

    public init(model: OnboardingModel = OnboardingModel(), onContinue: @escaping () -> Void = {}) {
        _model = State(wrappedValue: model)
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header
            summaryBar
            tableSection
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.l)
        .background(Palette.paper)
        .task { await model.scan() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("툴체인 진단")
                        .font(.appSans(.display, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(
                        "10개 도구를 --version 으로 직접 실행해 종료 코드까지 확인했습니다 " +
                        "(도구당 2초 제한). 이 앱은 아무것도 대신 설치하지 않습니다 — " +
                        "필요한 명령을 복사해 터미널에서 직접 실행하세요."
                    )
                    .font(.appSans(.body))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.l)
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    LabelTextView("검사 환경")
                    MonoTextView(text: environmentSummary, size: .label, color: Palette.ink)
                }
            }
            .padding(.bottom, Spacing.m)
            RuleView(color: Palette.ruleHard)
        }
    }

    private var environmentSummary: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osLabel = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let when = model.lastScanFinishedAt.map(Self.timeFormatter.string(from:)) ?? "확인 중…"
        return "\(osLabel) · \(Self.architecture) · \(when)"
    }

    private static let architecture: String = {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "알 수 없음"
        #endif
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: Spacing.xl) {
            summaryItem(glyph: .filledPass, tint: Palette.pass, label: "설치됨", count: model.summary.installed)
            summaryItem(glyph: .emptySquare, tint: Palette.faint, label: "미설치", count: model.summary.missing)
            summaryItem(glyph: .filledFail, tint: Palette.fail, label: "문제", count: model.summary.problem)
            Text("스텁 — 실행 파일은 있지만 실행이 실패하는 상태. 설치된 것으로 오인하기 쉽습니다.")
                .font(.appSans(.label))
                .foregroundStyle(Palette.faint)
        }
    }

    private func summaryItem(glyph: StatusGlyph, tint: Color, label: String, count: Int) -> some View {
        HStack(spacing: Spacing.s) {
            StatusGlyphView(glyph: glyph, tint: tint)
            Text(label)
                .font(.appSans(.label, weight: .medium))
                .foregroundStyle(Palette.ink)
            MonoTextView(text: "\(count)", size: .label, color: Palette.secondary)
        }
    }

    // MARK: - Table

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            tableHeader
            ForEach(model.rows) { row in
                DiagnosticRowView(row: row, onCopy: model.copyInstallHint)
            }
        }
    }

    private var tableHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                LabelTextView("트랙").frame(width: OnboardingLayout.trackWidth, alignment: .leading)
                LabelTextView("도구").frame(width: OnboardingLayout.toolWidth, alignment: .leading)
                LabelTextView("상태").frame(width: OnboardingLayout.statusWidth, alignment: .leading)
                LabelTextView("확인 결과").frame(minWidth: OnboardingLayout.detailMinWidth, maxWidth: .infinity, alignment: .leading)
                LabelTextView("설치 명령").frame(minWidth: OnboardingLayout.commandMinWidth, maxWidth: OnboardingLayout.commandMinWidth * 1.6, alignment: .leading)
            }
            .padding(.bottom, Spacing.s)
            RuleView(color: Palette.ruleHard)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.l) {
            Text("미설치 트랙은 나중에 설치해도 됩니다. 설치한 뒤 '다시 검사'를 누르면 바로 활성화됩니다.")
                .font(.appSans(.label))
                .foregroundStyle(Palette.faint)
            Spacer(minLength: Spacing.l)
            FlatButtonView(title: "다시 검사", style: .outline, isEnabled: !model.isScanning) {
                Task { await model.scan() }
            }
            FlatButtonView(title: "Python · SQL · Swift 로 시작", style: .filled, isEnabled: mvpReady) {
                onContinue()
            }
        }
    }

    /// MVP 3종(Python·SQL·Swift)이 전부 `.ready` 일 때만 시작을 허용한다.
    private var mvpReady: Bool {
        let mvpRows = model.rows.filter { Self.mvpToolIDs.contains($0.id) }
        guard mvpRows.count == Self.mvpToolIDs.count else { return false }
        return mvpRows.allSatisfy {
            if case let .resolved(availability) = $0.status { return availability.isReady }
            return false
        }
    }
}
