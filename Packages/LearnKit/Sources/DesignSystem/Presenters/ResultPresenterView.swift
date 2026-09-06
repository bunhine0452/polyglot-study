public import LearnCore
public import SwiftUI

/// 프리젠터 라우터. `GradeResult.Presenter` 네 케이스를 뷰로 가른다.
///
/// `switch` 가 **exhaustive** 하다는 것이 이 타입의 존재 이유다 — 언어가 늘어
/// 케이스가 하나 붙으면 여기가 컴파일 에러로 막는다. 지금 실제 뷰가 있는 것은
/// 콘솔과 표 둘이고, 브라우저·레지스터는 준비중 뷰로 간다. 준비중도 **같은 자리에
/// 같은 크기**로 그려진다 — 트랙을 바꿨을 때 레이아웃이 튀지 않게.
///
/// 받는 것은 도메인 값 그대로다(`GradeResult.Presenter`·`ResultSet`). 예전에는 둘 다
/// 표시용으로 옮겨 적은 사본이었다 — 경위는 ``PresenterRoute`` 옆 주석에 있다.
public struct ResultPresenterView: View {
    private let presenter: GradeResult.Presenter
    private let transcript: ConsoleTranscript
    private let resultSet: ResultSet?

    public init(
        _ presenter: GradeResult.Presenter,
        transcript: ConsoleTranscript = .empty,
        resultSet: ResultSet? = nil
    ) {
        self.presenter = presenter
        self.transcript = transcript
        self.resultSet = resultSet
    }

    public var body: some View {
        switch presenter {
        case .console:
            ConsolePresenterView(transcript: transcript)
        case .table:
            TablePresenterView(
                resultSet: resultSet ?? ResultSet(columns: []), transcript: transcript)
        case .browser:
            PendingPresenterView(presenter: .browser)
        case .registers:
            PendingPresenterView(presenter: .registers)
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
                title: GradeResult.Presenter.console.title, status: transcript.statusLabel)
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

/// 표. 헤더 행 + 데이터 행.
///
/// - Note: 예전 `ResultTable` 미러에는 행·셀에 붙는 diff 표식(`Mark`·`isMismatch`)이
///   있었지만 **채우는 코드가 한 줄도 없었다** — 언제나 기본값이라 실제로 그려진 적이
///   없다. 미러를 걷어내면서 함께 지웠다. 기대 결과와의 비교는 지금
///   `RunnerKit.SQLResultDiff` 가 하고, 그 모듈은 러너를 들고 있어 디자인 시스템이
///   의존할 수 없다. 표에 diff 를 그릴 때가 오면 `LearnCore` 쪽 값 타입으로 올라온 뒤에
///   여기 붙는다.
struct TablePresenterView: View {
    let resultSet: ResultSet
    let transcript: ConsoleTranscript

    /// 열 폭은 고정하지 않는다 — 디자인 실측 폭을 그대로 박으면 사이드바를 더했을 때
    /// 창을 넘친다(온보딩 표에서 실제로 잘렸다). 최소 폭 + 균등 신축으로 둔다.
    static let minimumColumnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: ResultSlotMetrics.headerGap) {
            PresenterHeader(title: GradeResult.Presenter.table.title, status: status)
            if resultSet.columns.isEmpty {
                MonoText("—", size: .code, color: Palette.faint)
                    .frame(height: ResultSlotMetrics.lineHeight, alignment: .leading)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        Rule(.hard)
                        ForEach(Array(resultSet.rows.enumerated()), id: \.offset) { _, row in
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

    /// 머리줄 오른쪽 문구. 뷰를 렌더하지 않고 단언할 수 있게 internal 로 둔다.
    var status: String {
        if transcript.isRunning { return "실행 중" }
        if resultSet.columns.isEmpty { return "실행 전" }
        let base = "\(resultSet.rowCount) 행 · \(resultSet.columnCount) 열"
        return resultSet.isTruncated ? base + " · 잘림" : base
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(resultSet.columns.enumerated()), id: \.offset) { _, column in
                LabelText(column.name)
                    .frame(minWidth: Self.minimumColumnWidth, alignment: .leading)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func dataRow(_ row: [ResultSet.Value]) -> some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                MonoText(
                    value.displayText,
                    size: .code,
                    color: value.isNull ? Palette.faint : Palette.ink
                )
                .frame(
                    minWidth: Self.minimumColumnWidth,
                    minHeight: ResultSlotMetrics.lineHeight,
                    alignment: .leading
                )
            }
        }
        .padding(.vertical, Spacing.xs / 2)
    }
}

/// 준비중. 자리는 잡되 아무 것도 약속하지 않는다.
struct PendingPresenterView: View {
    let presenter: GradeResult.Presenter

    var body: some View {
        VStack(alignment: .leading, spacing: ResultSlotMetrics.headerGap) {
            PresenterHeader(title: presenter.title, status: "준비중")
            if let reason = presenter.pendingReason {
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
