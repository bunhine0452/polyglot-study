internal import SwiftUI
internal import DesignSystem

/// "설치 명령" 열의 복사 칩. `installHint` 문자열을 클립보드에 넣기만 한다 —
/// **프로세스를 실행하지 않는다.**
struct InstallCommandView: View {
    let command: String
    let onCopy: (String) -> Void

    @State private var justCopied = false

    var body: some View {
        Button {
            onCopy(command)
            justCopied = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                justCopied = false
            }
        } label: {
            HStack(spacing: Spacing.s) {
                MonoTextView(text: command, color: Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: Spacing.s)
                Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(Palette.secondary)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, Spacing.s)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(Palette.card)
            .overlay(Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: Rules.thickness))
        }
        .buttonStyle(.plain)
        .help("클립보드에 복사— 이 앱은 아무것도 대신 설치하지 않습니다.")
    }
}
