internal import DesignSystem
internal import SwiftUI

/// 48px 상단 바 — 뒤로, 트랙·레슨 번호, 제목, 블록 카운터, 제출·실행.
///
/// `{#screen-editor-console}` 의 헤더. 색은 전부 무채색이다 — 버튼 강조조차 잉크
/// 채움/테두리일 뿐 유채색이 아니다.
struct EditorTopBar: View {
    let trackCaption: String
    let title: String
    let blockCaption: String
    let onBack: (() -> Void)?
    let canRun: Bool
    let canSubmit: Bool
    let onRun: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.unit + Spacing.xs) {
            if let onBack {
                Button(action: onBack) {
                    EditorBackGlyph().contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("레슨으로 돌아가기")
            }
            LabelText(trackCaption)
            Text(title)
                .font(AppFont.sans(.label, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: Spacing.m)
            LabelText(blockCaption)
            FlatButton("제출", emphasis: .secondary, isEnabled: canSubmit, action: onSubmit)
            FlatButton("실행", emphasis: .primary, shortcutHint: "⌘↩", isEnabled: canRun, action: onRun)
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, EditorLayout.barPadding)
        .frame(height: EditorLayout.topBarHeight)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
        .overlay(alignment: .bottom) { Rule(.hard) }
    }
}

/// 56px 과제 바 — 과제 번호, 설명(인라인 코드 포함), 오른쪽 채점 안내.
struct EditorTaskBar: View {
    let ordinalLabel: String
    let prose: String
    let trailingLabel: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                LabelText(ordinalLabel, color: Palette.ink)
                    .fixedSize()
                InlineCodeText(prose)
                    .lineLimit(2)
            }
            Spacer(minLength: Spacing.m)
            LabelText(trailingLabel)
                .fixedSize()
        }
        .padding(.horizontal, EditorLayout.barPadding)
        .frame(height: EditorLayout.taskBarHeight)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
        .overlay(alignment: .bottom) { Rule(.soft) }
    }
}

/// 백틱(`` `code` ``)만 인라인 코드로 가르는 최소 렌더러. 과제 바 설명은 항상 한
/// 문단짜리 짧은 문장이라 ``ProseView`` 의 블록 파서 전체를 태울 이유가 없다 — 단일
/// `Text` 로 이어 붙여야 디자인처럼 한 줄 흐름으로 자연스럽게 줄바꿈된다.
struct InlineCodeText: View {
    let source: String

    init(_ source: String) { self.source = source }

    var body: some View {
        Self.segments(of: source).reduce(Text("")) { partial, segment in
            partial + Self.text(for: segment)
        }
        .foregroundStyle(Palette.ink)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    struct Segment: Equatable { let text: String; let isCode: Bool }

    /// 백틱 쌍으로 가른다. 짝이 안 맞는 마지막 백틱은 평문으로 남는다.
    static func segments(of source: String) -> [Segment] {
        var result: [Segment] = []
        var remainder = Substring(source)
        while let open = remainder.firstIndex(of: "`") {
            let before = remainder[remainder.startIndex..<open]
            if !before.isEmpty { result.append(Segment(text: String(before), isCode: false)) }
            let afterOpen = remainder[remainder.index(after: open)...]
            guard let close = afterOpen.firstIndex(of: "`") else {
                result.append(Segment(text: String(remainder[open...]), isCode: false))
                remainder = Substring("")
                break
            }
            result.append(Segment(text: String(afterOpen[afterOpen.startIndex..<close]), isCode: true))
            remainder = afterOpen[afterOpen.index(after: close)...]
        }
        if !remainder.isEmpty { result.append(Segment(text: String(remainder), isCode: false)) }
        return result
    }

    private static func text(for segment: Segment) -> Text {
        segment.isCode
            ? Text(segment.text).font(AppFont.mono(.code))
            : Text(segment.text).font(AppFont.sans(.note))
    }
}

/// 뒤로 가기 갈매기. `LessonFeature.BackGlyph` 와 같은 모양이지만 모듈 경계를 넘어
/// 공유할 공개 프리미티브가 아니라서 이 화면 것을 따로 둔다.
struct EditorBackGlyph: View {
    var size: CGFloat = 16
    var color: Color = Palette.ink

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 10 / 16, y: size * 3 / 16))
            path.addLine(to: CGPoint(x: size * 5 / 16, y: size * 8 / 16))
            path.addLine(to: CGPoint(x: size * 10 / 16, y: size * 13 / 16))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
