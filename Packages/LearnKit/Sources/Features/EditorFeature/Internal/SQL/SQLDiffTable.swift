internal import DesignSystem
internal import LearnCore
internal import SwiftUI

/// SQL 결과 화면(`{#screen-sql-result}`, `{#sql-row-padding}`)의 표 하나 — 28px 행.
///
/// 누락·초과로 짝 없는 행은 `Palette.failWash` 배경 + 6px 적색 사각. 두 표(내 결과·
/// 예상 결과)가 이 뷰를 하나씩 받고, 행 수는 `SQLDiffPresentation` 이 이미 맞춰
/// 왔다 — 이 뷰는 그 결과를 그대로 그리기만 한다.
struct SQLDiffTable: View {
    let columns: [ResultSet.Column]
    let rows: [SQLDiffRow]

    private var minimumColumnWidth: CGFloat { 72 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Rule(.hard)
            ForEach(rows) { row in
                rowView(row)
                Rule(.soft)
            }
        }
        .background(Palette.card)
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.s) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                LabelText(column.name)
                    .frame(minWidth: minimumColumnWidth, alignment: alignment(for: index))
                    .frame(maxWidth: index == 0 ? .infinity : nil, alignment: alignment(for: index))
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: EditorLayout.sqlRowHeight)
    }

    @ViewBuilder
    private func rowView(_ row: SQLDiffRow) -> some View {
        switch row.kind {
        case .data(let highlighted):
            dataRow(row.values, highlighted: highlighted)
        case .placeholder(let summary):
            placeholderRow(summary)
        }
    }

    private func dataRow(_ values: [ResultSet.Value], highlighted: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                cell(value, index: index, highlighted: highlighted)
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: EditorLayout.sqlRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? Palette.failWash : Color.clear)
    }

    @ViewBuilder
    private func cell(_ value: ResultSet.Value, index: Int, highlighted: Bool) -> some View {
        let color = highlighted ? Palette.fail : (value.isNull ? Palette.faint : Palette.ink)
        HStack(spacing: Spacing.xs) {
            MonoText(value.displayText, size: .code, color: color)
            // 짝 없는 행이라는 표식은 첫 열에만 붙는다 — 디자인의 이름 옆 6px 사각.
            if highlighted, index == 0 {
                Rectangle()
                    .fill(Palette.fail)
                    .frame(width: Rules.gutterMarkSize, height: Rules.gutterMarkSize)
            }
        }
        .frame(minWidth: minimumColumnWidth, alignment: alignment(for: index))
        .frame(maxWidth: index == 0 ? .infinity : nil, alignment: alignment(for: index))
    }

    /// 요약이 있는 자리(플레이스홀더의 첫 행)만 점선 적색 테두리 + 안내 문구를 그린다.
    /// 나머지 채움 행은 완전히 빈 자리다 — 높이만 맞추는 것이 목적이다.
    @ViewBuilder
    private func placeholderRow(_ summary: String?) -> some View {
        if let summary {
            HStack {
                MonoText(summary, size: .code, color: Palette.fail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.m)
            .frame(height: EditorLayout.sqlRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                Rectangle().strokeBorder(
                    Palette.fail, style: StrokeStyle(lineWidth: Rules.thickness, dash: [4, 3])
                )
            }
        } else {
            Color.clear.frame(height: EditorLayout.sqlRowHeight).frame(maxWidth: .infinity)
        }
    }

    private func alignment(for columnIndex: Int) -> Alignment {
        columnIndex == 0 ? .leading : .trailing
    }
}
