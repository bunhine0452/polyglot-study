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

/// 한 출처가 낸 진단 묶음과 **그것이 계산된 소스 스냅샷**.
///
/// 스냅샷을 출처마다 따로 드는 이유: `swiftc` 진단은 마지막으로 **실행한** 코드
/// 기준이고 `sourcekit-lsp` 진단은 **지금 편집 중인** 코드 기준이다. 둘이 한 화면에
/// 같이 뜨는 동안 두 스냅샷은 다를 수 있고, 인라인 진단 행은 "그 줄의 소스 텍스트" 를
/// 같이 그리므로 어느 쪽 스냅샷인지가 실제로 눈에 보인다.
struct DiagnosticSourceGroup {
    /// 라벨에 찍힐 이름. `"swiftc"`·`"sourcekit-lsp"`.
    let toolName: String
    /// 이 진단들이 가리키는 소스.
    let code: String
    let diagnostics: [Diagnostic]
}

enum EditorDiagnosticPresentation {
    /// 줄 번호가 있는 진단만 행으로 접는다. 줄 번호가 없는 드라이버 오류(링크 실패 등)는
    /// 이 목록에 들어갈 자리가 없다 — 원문 그대로는 stderr 패널이 보여준다.
    static func rows(code: String, diagnostics: [Diagnostic], toolName: String) -> [InlineDiagnosticRow] {
        rows(groups: [DiagnosticSourceGroup(toolName: toolName, code: code, diagnostics: diagnostics)])
    }

    /// 여러 출처의 진단을 **같은 컴포넌트**로 그리기 위해 한 목록으로 접는다.
    /// `{#lsp-diagnostics}`: 출처는 뷰가 아니라 **라벨**로만 구분된다.
    ///
    /// 같은 줄에 두 출처가 겹치면 행 하나로 접고 라벨에 둘 다 적는다
    /// (`"4행 9열 · sourcekit-lsp/swiftc · 2개"`). 코드 줄은 **먼저 온 그룹**의
    /// 스냅샷에서 가져온다 — 호출자가 신선한 쪽을 앞에 놓는다.
    static func rows(groups: [DiagnosticSourceGroup]) -> [InlineDiagnosticRow] {
        var order: [Int] = []
        var byLine: [Int: [(tool: String, diagnostic: Diagnostic)]] = [:]
        var snapshotByLine: [Int: String] = [:]

        for group in groups {
            let lines = group.code.components(separatedBy: "\n")
            for diagnostic in group.diagnostics {
                guard let line = diagnostic.line else { continue }
                if byLine[line] == nil { order.append(line) }
                byLine[line, default: []].append((group.toolName, diagnostic))
                // 먼저 온 그룹이 이긴다. 뒤 그룹은 자기 스냅샷을 덮어쓰지 않는다.
                if snapshotByLine[line] == nil {
                    snapshotByLine[line] = (line >= 1 && line <= lines.count) ? lines[line - 1] : ""
                }
            }
        }
        guard !order.isEmpty else { return [] }

        return order.sorted().map { line in
            let entries = byLine[line] ?? []
            let first = entries[0].diagnostic
            return InlineDiagnosticRow(
                id: line,
                line: line,
                column: first.column,
                codeLine: snapshotByLine[line] ?? "",
                message: first.message,
                severity: worstSeverity(of: entries.map(\.diagnostic)),
                locationLabel: label(
                    line: line,
                    column: first.column,
                    tools: distinctTools(in: entries),
                    count: entries.count
                )
            )
        }
    }

    /// 등장 순서를 지키면서 중복만 없앤다. `Set` 을 쓰면 라벨이 실행마다 뒤집힌다.
    private static func distinctTools(in entries: [(tool: String, diagnostic: Diagnostic)]) -> [String] {
        var seen: Set<String> = []
        return entries.map(\.tool).filter { seen.insert($0).inserted }
    }

    private static func worstSeverity(of diagnostics: [Diagnostic]) -> Diagnostic.Severity {
        if diagnostics.contains(where: { $0.severity == .error }) { return .error }
        if diagnostics.contains(where: { $0.severity == .warning }) { return .warning }
        return .note
    }

    private static func label(line: Int, column: Int?, tools: [String], count: Int) -> String {
        let location = column.map { "\(line)행 \($0)열" } ?? "\(line)행"
        return "\(location) · \(tools.joined(separator: "/")) · \(count)개"
    }
}
