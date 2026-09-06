public import SwiftUI

/// 프리젠터 라우터. ``ResultPresentation`` 네 케이스를 뷰로 가른다.
///
/// `switch` 가 **exhaustive** 하다는 것이 이 타입의 존재 이유다 — 언어가 늘어
/// 케이스가 하나 붙으면 여기가 컴파일 에러로 막는다. 지금 실제 뷰가 있는 것은
/// 콘솔과 표 둘이고, 브라우저·레지스터는 준비중 뷰로 간다. 준비중도 **같은 자리에
/// 같은 크기**로 그려진다 — 트랙을 바꿨을 때 레이아웃이 튀지 않게.
public struct ResultPresenterView: View {
    private let presentation: ResultPresentation
    private let transcript: ConsoleTranscript
    private let table: ResultTable?

    public init(
        _ presentation: ResultPresentation,
        transcript: ConsoleTranscript = .empty,
        table: ResultTable? = nil
    ) {
        self.presentation = presentation
        self.transcript = transcript
        self.table = table
    }

    public var body: some View {
        switch presentation {
        case .console:
            ConsolePresenterView(transcript: transcript)
        case .table:
            TablePresenterView(table: table ?? .empty, transcript: transcript)
        case .browser:
            PendingPresenterView(presentation: .browser)
        case .registers:
            PendingPresenterView(presentation: .registers)
        }
    }
}

/// 프리젠터 공통 머리줄 — 왼쪽 제목, 오른쪽 상태. 세 프리젠터가 전부 이걸로 시작한다.
struct PresenterHeader: View {
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            LabelText(title)
            Spacer(minLength: Spacing.s)
            LabelText(status)
        }
        .frame(height: ResultSlotMetrics.headerHeight)
    }
}

/// 콘솔. stdout 은 잉크, stderr 는 실패색, 러너 메모는 흐리게.
struct ConsolePresenterView: View {
    let transcript: ConsoleTranscript

    var body: some View {
        VStack(alignment: .leading, spacing: ResultSlotMetrics.headerGap) {
            PresenterHeader(
                title: ResultPresentation.console.title, status: transcript.statusLabel)
            if transcript.isEmpty {
                MonoText("—", size: .code, color: Palette.faint)
                    .frame(height: ResultSlotMetrics.lineHeight, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(transcript.lines) { line in
                            MonoText(
                                line.text.isEmpty ? " " : line.text,
                                size: .code,
                                color: Self.color(for: line.stream)
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: ResultSlotMetrics.lineHeight,
                                alignment: .leading
                            )
                            .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, ResultSlotMetrics.verticalPadding)
        .padding(.horizontal, Spacing.m)
    }

    static func color(for stream: ConsoleTranscript.Stream) -> Color {
        switch stream {
        case .output: Palette.ink
        case .error: Palette.fail
        case .note: Palette.faint
        }
    }
}

/// 표. 헤더 행 + 데이터 행, 기대와 다른 행만 표식이 붙는다.
struct TablePresenterView: View {
    let table: ResultTable
    let transcript: ConsoleTranscript

    /// 열 폭은 고정하지 않는다 — 디자인 실측 폭을 그대로 박으면 사이드바를 더했을 때
    /// 창을 넘친다(온보딩 표에서 실제로 잘렸다). 최소 폭 + 균등 신축으로 둔다.
    static let minimumColumnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: ResultSlotMetrics.headerGap) {
            PresenterHeader(title: ResultPresentation.table.title, status: status)
            if table.columns.isEmpty {
                MonoText("—", size: .code, color: Palette.faint)
                    .frame(height: ResultSlotMetrics.lineHeight, alignment: .leading)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        Rule(.hard)
                        ForEach(table.rows) { row in
                            dataRow(row)
                            Rule(.soft)
                        }
                    }
                }
            }
        }
        .padding(.vertical, ResultSlotMetrics.verticalPadding)
        .padding(.horizontal, Spacing.m)
    }

    private var status: String {
        if transcript.isRunning { return "실행 중" }
        if table.columns.isEmpty { return "실행 전" }
        let base = "\(table.rowCount) 행 · \(table.columnCount) 열"
        return table.isTruncated ? base + " · 잘림" : base
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(table.columns.enumerated()), id: \.offset) { _, column in
                LabelText(column.name)
                    .frame(minWidth: Self.minimumColumnWidth, alignment: .leading)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func dataRow(_ row: ResultTable.Row) -> some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                MonoText(
                    cell.text,
                    size: .code,
                    color: cell.isNull ? Palette.faint : Palette.ink
                )
                .frame(
                    minWidth: Self.minimumColumnWidth,
                    minHeight: ResultSlotMetrics.lineHeight,
                    alignment: .leading
                )
                .background(cell.isMismatch ? Palette.failWash : Color.clear)
            }
        }
        .padding(.vertical, Spacing.xs / 2)
        .background(row.mark == .missing ? Palette.failWash : Color.clear)
    }
}

/// 준비중. 자리는 잡되 아무 것도 약속하지 않는다.
struct PendingPresenterView: View {
    let presentation: ResultPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: ResultSlotMetrics.headerGap) {
            PresenterHeader(title: presentation.title, status: "준비중")
            if let reason = presentation.pendingReason {
                Text(reason)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, ResultSlotMetrics.verticalPadding)
        .padding(.horizontal, Spacing.m)
    }
}
