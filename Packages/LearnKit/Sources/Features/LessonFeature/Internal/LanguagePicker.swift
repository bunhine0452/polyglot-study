internal import DesignSystem
public import LearnCore
import SwiftUI

/// 풀이 언어 선택 — {#lesson-language-picker}.
///
/// 알고리즘처럼 **한 레슨을 여러 언어로 풀 수 있는** 트랙에서만 뜬다. 언어가 하나인
/// 레슨(지금의 122편 전부)에서는 아예 그려지지 않는다 — 고를 것이 없는 선택지를 두면
/// 학습자가 "여기서 뭘 골라야 하나" 를 잠깐 고민한다.
///
/// 드롭다운이 아니라 **가로로 늘어놓은 토글**인 이유: 지금 무엇으로 풀고 있는지가 한눈에
/// 보여야 하고, 후보가 많아야 넷(Rust·Python·Swift·C++)이라 접어 둘 만큼 길지 않다.
struct LanguagePicker: View {
    let languages: [LanguageID]
    let selected: LanguageID
    let onSelect: (LanguageID) -> Void

    var body: some View {
        // 하나뿐이면 그리지 않는다. `isEmpty` 도 같이 걸러진다.
        if languages.count > 1 {
            HStack(spacing: Spacing.s) {
                LabelText("풀이 언어")
                HStack(spacing: 0) {
                    ForEach(Array(languages.enumerated()), id: \.element.rawValue) { index, id in
                        cell(id)
                        if index < languages.count - 1 {
                            Rule(.hard, axis: .vertical)
                        }
                    }
                }
                .fixedSize()
                .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func cell(_ id: LanguageID) -> some View {
        let isSelected = id == selected
        Button {
            onSelect(id)
        } label: {
            MonoText(
                LessonContent.trackName(for: id),
                size: .code,
                weight: isSelected ? .semibold : .regular,
                color: isSelected ? Palette.paper : Palette.ink
            )
            .padding(.horizontal, Spacing.m)
            .frame(height: LanguagePicker.height)
            .background(isSelected ? Palette.ink : Palette.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 상단 바의 다른 컨트롤과 같은 높이. 헤더 줄이 흔들리지 않게 고정한다.
    static let height: CGFloat = 28
}
