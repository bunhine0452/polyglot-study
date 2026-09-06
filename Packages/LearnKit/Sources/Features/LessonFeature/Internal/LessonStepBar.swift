internal import DesignSystem
internal import SwiftUI

/// 6블록 스텝바. 완료는 체크, 지금은 반전, 이후는 흐림.
///
/// 여섯 칸이 화면 폭을 **균등 분할**한다(디자인의 `repeat(6, minmax(0,1fr))`).
/// 칸 폭을 실측값으로 박으면 사이드바 폭을 더했을 때 창을 넘긴다.
struct LessonStepBar: View {
    let steps: [LessonModel.Step]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps) { step in
                cell(step)
                if step.index < steps.count - 1 {
                    Rule(step.state == .active ? .hard : .soft, axis: .vertical)
                }
            }
        }
        .frame(height: LessonLayout.stepBarHeight)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cell(_ step: LessonModel.Step) -> some View {
        let isActive = step.state == .active
        Button {
            onSelect(step.index)
        } label: {
            HStack(spacing: Spacing.s) {
                MonoText(step.ordinal, size: .micro, color: numberColor(step))
                Text(step.name)
                    .font(AppFont.sans(.label, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(nameColor(step))
                    .lineLimit(1)
                if step.state == .done {
                    CheckGlyph(size: 12, color: Palette.ink)
                }
                Spacer(minLength: 0)
                if isActive {
                    LabelText("지금", color: Palette.paper)
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, LessonLayout.stepPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(isActive ? Palette.ink : Palette.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 앞으로 건너뛰기는 없다 — 스텝바가 진도를 뜻해야 한다.
        .disabled(step.state == .upcoming)
        .accessibilityLabel("\(step.ordinal) \(step.name)")
    }

    private func numberColor(_ step: LessonModel.Step) -> Color {
        switch step.state {
        case .done: Palette.secondary
        case .active: Palette.paper
        case .upcoming: Palette.faint
        }
    }

    private func nameColor(_ step: LessonModel.Step) -> Color {
        switch step.state {
        case .done: Palette.ink
        case .active: Palette.paper
        case .upcoming: Palette.faint
        }
    }
}

/// 상단 바 — 뒤로, 트랙·레슨 번호, 제목, 블록 카운터.
struct LessonTopBar: View {
    let trackCaption: String
    let title: String
    let blockCaption: String
    let onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.unit + Spacing.xs) {
            if let onBack {
                Button(action: onBack) {
                    BackGlyph()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("트랙으로 돌아가기")
            }
            LabelText(trackCaption)
            Text(title)
                .font(AppFont.sans(.label, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: Spacing.m)
            LabelText(blockCaption)
        }
        .padding(.horizontal, LessonLayout.barPadding)
        .frame(height: LessonLayout.topBarHeight)
        .frame(maxWidth: .infinity)
    }
}
