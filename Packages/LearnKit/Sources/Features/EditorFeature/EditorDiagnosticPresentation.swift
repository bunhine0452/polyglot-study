internal import Foundation
internal import LearnCore

/// 인라인 진단 행 하나가 그릴 재료. `Diagnostic` 목록에서 순수하게 조립된다 — 뷰를
/// 만들지 않고 테스트할 수 있다.
///
/// `{#inline-diagnostic-row}`: 거터 6px 사각 + 코드 아래 한국어 설명 + 위치 라벨을
/// `Diagnostic` 에서 조립한다. 진단이 붙은 행만 배경이 바뀐다 — 그래서 이 값은 그 행의
/// **소스 텍스트 자체**(`codeLine`)를 들고 있다. 마지막으로 돈 소스 스냅샷 기준이라,
/// 그 뒤 편집기에서 코드를 더 고쳐도 여기 보이는 줄은 진단이 실제로 가리켰던 그 줄이다.
struct InlineDiagnosticRow: Hashable, Identifiable {
    let id: Int
    let line: Int
    let column: Int?
    let codeLine: String
    let message: String
    let severity: Diagnostic.Severity
    /// "4행 9열 · swiftc · 1개".
    let locationLabel: String
}

enum EditorDiagnosticPresentation {
    /// 줄 번호가 있는 진단만 행으로 접는다. 줄 번호가 없는 드라이버 오류(링크 실패 등)는
    /// 이 목록에 들어갈 자리가 없다 — 원문 그대로는 stderr 패널이 보여준다.
    static func rows(code: String, diagnostics: [Diagnostic], toolName: String) -> [InlineDiagnosticRow] {
        guard !diagnostics.isEmpty else { return [] }
        let lines = code.components(separatedBy: "\n")

        var order: [Int] = []
        var byLine: [Int: [Diagnostic]] = [:]
        for diagnostic in diagnostics {
            guard let line = diagnostic.line else { continue }
            if byLine[line] == nil { order.append(line) }
            byLine[line, default: []].append(diagnostic)
        }

        return order.sorted().map { line in
            let group = byLine[line] ?? []
            let first = group[0]
            let severity = worstSeverity(of: group)
            let codeLine = (line >= 1 && line <= lines.count) ? lines[line - 1] : ""
            return InlineDiagnosticRow(
                id: line,
                line: line,
                column: first.column,
                codeLine: codeLine,
                message: first.message,
                severity: severity,
                locationLabel: label(line: line, column: first.column, tool: toolName, count: group.count)
            )
        }
    }

    private static func worstSeverity(of diagnostics: [Diagnostic]) -> Diagnostic.Severity {
        if diagnostics.contains(where: { $0.severity == .error }) { return .error }
        if diagnostics.contains(where: { $0.severity == .warning }) { return .warning }
        return .note
    }

    private static func label(line: Int, column: Int?, tool: String, count: Int) -> String {
        let location = column.map { "\(line)행 \($0)열" } ?? "\(line)행"
        return "\(location) · \(tool) · \(count)개"
    }
}
