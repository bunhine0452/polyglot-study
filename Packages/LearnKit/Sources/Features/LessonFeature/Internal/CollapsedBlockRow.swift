internal import DesignSystem
internal import SwiftUI

/// 접힌 블록 한 줄 — 40px. 완료·다음·묶음 셋 다 같은 높이의 같은 행이다.
///
/// 높이를 하나로 고정하는 이유는 활성 카드의 상단 y 좌표 때문이다. 완료 블록이
/// 내용에 따라 다른 높이로 접히면, 블록을 넘길 때마다 카드가 다른 자리에서 시작한다.
struct CollapsedBlockRow: View {
    enum Tone: Sendable {
        /// 완료 — 잉크색 이름 + 체크 + 다시 보기.
        case done
        /// 다음 하나 — 흐림.
        case next
        /// 그 뒤 전부 — 흐림, 번호가 구간이다.
        case remaining
    }

    let ordinal: String
    let name: String
    let summary: String
    let tone: Tone
    let onRevisit: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LessonLayout.rowGap) {
                MonoText(ordinal, size: .micro, color: numberColor)
                Text(name)
                    .font(LessonFont.sans(.label, weight: .medium))
                    .foregroundStyle(nameColor)
                    .fixedSize()
                Text(summary)
                    .font(LessonFont.sans(.label))
                    .foregroundStyle(summaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Spacing.m)
                trailing
            }
            // 룰까지 합쳐 정확히 40px 이어야 활성 카드의 상단 y 좌표가 8px 그리드에 남는다.
            .frame(height: LessonLayout.rowHeight - Rules.thickness)
            Rule(.soft)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch tone {
        case .done:
            HStack(spacing: LessonLayout.rowGap) {
                HStack(spacing: Spacing.unit - 2) {
                    Text("완료")
                        .font(LessonFont.sans(.label))
                        .foregroundStyle(Palette.secondary)
                    CheckGlyph(size: 12, color: Palette.secondary)
                }
                if let onRevisit {
                    Button(action: onRevisit) {
                        Text("다시 보기")
                            .font(LessonFont.sans(.label))
                            .foregroundStyle(Palette.ink)
                            .overlay(alignment: .bottom) {
                                Rule(.hard).offset(y: Rules.thickness)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case .next:
            Text("다음")
                .font(LessonFont.sans(.label))
                .foregroundStyle(Palette.faint)
        case .remaining:
            EmptyView()
        }
    }

    private var numberColor: Color {
        tone == .done ? Palette.secondary : Palette.faint
    }

    private var nameColor: Color {
        tone == .done ? Palette.ink : Palette.faint
    }

    private var summaryColor: Color {
        tone == .done ? Palette.secondary : Palette.faint
    }
}
