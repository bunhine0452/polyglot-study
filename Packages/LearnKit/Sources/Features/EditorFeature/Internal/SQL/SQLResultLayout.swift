internal import DesignSystem
internal import LearnCore
internal import RunnerKit
internal import SQLite3
internal import SwiftUI

/// `{#screen-sql-result}` — 위 쿼리 패널 + 아래 결과 섹션(내 결과 / 예상 결과 2단 표).
///
/// SQL 은 `실행`·`제출` 둘 다 결과셋 비교다(`EditorModel.run()` 참고) — 원문 출력과
/// 채점된 표가 따로 있지 않다. 그래서 이 화면에는 콘솔 화면의 탭·stderr·stdout 이 없다.
struct SQLResultLayout: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            EditorCodePanel(
                fileName: model.task.entryFileName,
                engineLabel: engineLabel,
                language: model.task.language,
                code: $model.code,
                isEditable: model.canRun
            )
            .frame(height: queryPanelHeight)
            .overlay(alignment: .bottom) { Rule(.hard) }

            ScrollView(.vertical) {
                resultsSection
                    .padding(.horizontal, EditorLayout.barPadding)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 쿼리는 보통 몇 줄이다 — 코드 패널이 화면 절반을 먹지 않게 줄 수에서 유도한다.
    private var queryPanelHeight: CGFloat {
        let lines = max(3, model.code.split(separator: "\n", omittingEmptySubsequences: false).count)
        return EditorLayout.codeHeaderHeight
            + CGFloat(min(lines, 12)) * Typography.codeLineHeight
            + Spacing.m * 2
    }

    private var engineLabel: String {
        let database = model.task.database?.lastPathComponent ?? "메모리 DB"
        return "sqlite \(SQLiteEngineInfo.versionString) · \(database) · 읽기 전용"
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let tables = model.sqlDiffTables, let expected = model.sqlExpected {
            VStack(alignment: .leading, spacing: Spacing.m) {
                summaryRow(expected: expected)
                HStack(alignment: .top, spacing: Spacing.l) {
                    column(
                        title: "내 결과",
                        countLabel: "\(model.sqlActual?.rowCount ?? 0)행",
                        columns: actualColumns,
                        rows: tables.actual
                    )
                    column(
                        title: "예상 결과",
                        countLabel: expectedCountLabel(tables: tables, expected: expected),
                        columns: expected.columns,
                        rows: tables.expected
                    )
                }
                footer
            }
        } else {
            emptyState
        }
    }

    private var actualColumns: [ResultSet.Column] {
        (model.sqlComparison?.projectedActual ?? model.sqlActual)?.columns ?? []
    }

    private func expectedCountLabel(tables: SQLDiffTables, expected: ResultSet) -> String {
        let missingShown = tables.expected.filter {
            if case .data(let highlighted) = $0.kind { return highlighted }
            return false
        }.count
        guard missingShown > 0 else { return "\(expected.rowCount)행" }
        return "\(expected.rowCount)행 · 표시된 \(missingShown)행이 내 결과에 없음"
    }

    private func summaryRow(expected: ResultSet) -> some View {
        let matches = model.gradeState.result?.passed ?? false
        let matchedRows = expected.rowCount - (model.sqlComparison?.diff.missingRowCount ?? 0)
        return HStack {
            HStack(alignment: .lastTextBaseline, spacing: Spacing.m) {
                Text("결과")
                    .font(AppFont.sans(.subtitle, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                MonoText(
                    "\((model.sqlActual?.rowCount ?? 0))행 × \(actualColumns.count)열 · \(model.gradeState.result?.durationMilliseconds ?? 0) ms",
                    size: .label, color: Palette.secondary
                )
            }
            Spacer(minLength: Spacing.m)
            HStack(spacing: Spacing.unit + Spacing.xs) {
                Text(matches ? "결과셋 일치" : "예상 결과와 다름")
                    .font(AppFont.sans(.note, weight: .medium))
                    .foregroundStyle(Palette.ink)
                MonoText("일치 \(matchedRows) / \(expected.rowCount) 행", size: .label, color: Palette.secondary)
                Rectangle()
                    .fill(matches ? Palette.pass : Palette.fail)
                    .frame(width: Rules.statusDotSize, height: Rules.statusDotSize)
            }
        }
    }

    private func column(
        title: String, countLabel: String, columns: [ResultSet.Column], rows: [SQLDiffRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                LabelText(title, color: Palette.ink)
                Spacer(minLength: Spacing.s)
                LabelText(countLabel)
            }
            SQLDiffTable(columns: columns, rows: rows)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let hint = model.task.resultHint {
                    Text(hint)
                        .font(AppFont.sans(.note))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("쿼리 문자열이 아니라 결과셋을 비교합니다. 열 이름과 행 순서는 무시하고 값만 봅니다."
                    + " 다른 방식으로 풀어도 결과가 같으면 통과입니다.")
                    .font(AppFont.sans(.note))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FlatButton("다시 실행", emphasis: .secondary, isEnabled: model.canRun) {
                Task { await model.run() }
            }
        }
        .padding(.top, Spacing.s)
        .overlay(alignment: .top) { Rule(.soft) }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            LabelText("결과")
            MonoText("실행 전", size: .code, color: Palette.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.m)
    }
}

/// 실제로 링크된 SQLite 버전. 목 데이터를 안 만든다는 원칙은 문구 한 줄에도 적용된다.
enum SQLiteEngineInfo {
    static let versionString: String = String(cString: sqlite3_libversion())
}
