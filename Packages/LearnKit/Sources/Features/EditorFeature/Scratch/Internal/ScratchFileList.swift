internal import DesignSystem
internal import SwiftUI

/// 연습장 왼쪽 칸 — 그 언어의 파일 목록.
///
/// 진입점은 언제나 맨 위이고 지울 수 없다. 그 사실을 목록에서 **보이게** 한다
/// (`실행` 라벨) — 지우기를 눌러 보고서야 알게 하지 않는다.
struct ScratchFileList: View {
    @Bindable var model: ScratchModel
    @Binding var isAddingFile: Bool
    @Binding var newFileName: String
    @Binding var fileError: String?

    @FocusState private var isNameFieldFocused: Bool

    /// 사이드바와 같은 폭 계열이되 좁게. 파일 이름은 짧고, 넓히면 코드 칸을 먹는다.
    private static let width: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rule(.soft)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.files) { file in
                        row(for: file)
                    }
                }
            }
            if isAddingFile { newFileRow }
            if let fileError {
                // 빨강을 쓰지 않는다 (`{#red-budget-guard}`). 이 문구는 바로 위 입력칸
                // 옆에 붙어 나오므로 무엇이 잘못됐는지가 위치로 이미 말해진다.
                Text(fileError)
                    .font(AppFont.sans(.caption))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(width: Self.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            LabelText("파일")
            Spacer(minLength: 0)
            if model.language.allowsMultipleFiles {
                Text("+")
                    .font(AppFont.mono(.label))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: Spacing.l, height: Spacing.l)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fileError = nil
                        newFileName = ""
                        isAddingFile = true
                        isNameFieldFocused = true
                    }
                    .accessibilityLabel("파일 추가")
            }
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: EditorLayout.codeHeaderHeight)
    }

    private func row(for file: ScratchFile) -> some View {
        let isActive = file.name == model.selectedFileName
        let isEntry = file.name == model.language.entryFileName
        return HStack(spacing: Spacing.xs) {
            // `MonoText` 는 색을 **인자로** 받아 내부에서 적용한다 — 바깥에서
            // `.foregroundStyle` 을 걸면 무시돼 잉크 위 잉크가 된다(실측으로 밟았다).
            MonoText(file.name, size: .label, color: isActive ? Palette.paper : Palette.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if isEntry {
                // 진입점임을 목록에서 밝힌다 — 이 파일이 실행되는 그 파일이다.
                Text("실행")
                    .font(AppFont.sans(.micro))
                    .foregroundStyle(isActive ? Palette.paper : Palette.faint)
            } else if isActive {
                Text("지우기")
                    .font(AppFont.sans(.micro))
                    .foregroundStyle(Palette.paper)
                    .contentShape(Rectangle())
                    .onTapGesture { fileError = model.deleteFile(named: file.name) }
            }
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: Spacing.l + Spacing.xs, alignment: .leading)
        .background(isActive ? Palette.ink : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            fileError = nil
            model.select(file.name)
        }
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var newFileRow: some View {
        HStack(spacing: Spacing.xs) {
            TextField("이름.\(model.language.fileExtension)", text: $newFileName)
                .textFieldStyle(.plain)
                .font(AppFont.mono(.label))
                .focused($isNameFieldFocused)
                .onSubmit(commit)
            Text("취소")
                .font(AppFont.sans(.micro))
                .foregroundStyle(Palette.secondary)
                .contentShape(Rectangle())
                .onTapGesture {
                    isAddingFile = false
                    fileError = nil
                }
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: Spacing.l + Spacing.xs)
        .overlay(alignment: .top) { Rule(.soft) }
    }

    private func commit() {
        if let reason = model.addFile(named: newFileName) {
            fileError = reason
            return
        }
        fileError = nil
        isAddingFile = false
        newFileName = ""
    }
}
