import LearnCore
import Testing

@testable import EditorFeature

@Suite("`{#inline-diagnostic-row}` · 진단 → 행 조립")
struct EditorDiagnosticPresentationTests {
    static let source = "struct Counter {\n    var count = 0\n    func increment() {\n        count += 1\n    }\n}\n"

    @Test("디자인 예시 그대로 — 4행 9열 · swiftc · 1개")
    func matchesDesignExample() {
        let diagnostic = Diagnostic(
            file: "main.swift", line: 4, column: 9, severity: .error,
            message: "'self' 는 불변이라 count 에 대입할 수 없습니다."
        )
        let rows = EditorDiagnosticPresentation.rows(
            code: Self.source, diagnostics: [diagnostic], toolName: "swiftc"
        )
        #expect(rows.count == 1)
        #expect(rows[0].codeLine == "        count += 1")
        #expect(rows[0].locationLabel == "4행 9열 · swiftc · 1개")
        #expect(rows[0].severity == .error)
    }

    @Test("같은 줄의 여러 진단은 한 행으로 접히고 개수가 라벨에 남는다")
    func sameLineDiagnosticsCollapseIntoOneRow() {
        let diagnostics = [
            Diagnostic(file: "main.swift", line: 4, column: 9, severity: .error, message: "첫 번째"),
            Diagnostic(file: "main.swift", line: 4, column: 9, severity: .warning, message: "두 번째"),
        ]
        let rows = EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: diagnostics, toolName: "swiftc")
        #expect(rows.count == 1)
        #expect(rows[0].locationLabel == "4행 9열 · swiftc · 2개")
        // 심각도는 더 나쁜 쪽(error)이 이긴다.
        #expect(rows[0].severity == .error)
        // 대표 메시지는 첫 진단의 것이다.
        #expect(rows[0].message == "첫 번째")
    }

    @Test("서로 다른 줄은 각각 행이 되고 줄 번호 오름차순으로 정렬된다")
    func differentLinesBecomeSeparateSortedRows() {
        let diagnostics = [
            Diagnostic(file: "main.swift", line: 6, severity: .warning, message: "나중 줄"),
            Diagnostic(file: "main.swift", line: 2, severity: .error, message: "먼저 줄"),
        ]
        let rows = EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: diagnostics, toolName: "swiftc")
        #expect(rows.map(\.line) == [2, 6])
    }

    @Test("열 번호가 없으면 라벨에서 빠진다")
    func missingColumnOmitsFromLabel() {
        let diagnostic = Diagnostic(file: "main.swift", line: 1, severity: .warning, message: "열 정보 없음")
        let rows = EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: [diagnostic], toolName: "python3")
        #expect(rows[0].locationLabel == "1행 · python3 · 1개")
    }

    @Test("줄 번호가 없는 진단(드라이버 오류)은 행이 되지 않는다")
    func lineLessDiagnosticsAreExcluded() {
        let diagnostic = Diagnostic(severity: .error, message: "link command failed")
        let rows = EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: [diagnostic], toolName: "swiftc")
        #expect(rows.isEmpty)
    }

    @Test("진단이 없으면 행도 없다")
    func noDiagnosticsMeansNoRows() {
        #expect(EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: [], toolName: "swiftc").isEmpty)
    }

    @Test("범위를 벗어난 줄 번호는 빈 코드 줄로 떨어진다 — 깨지지 않는다")
    func outOfRangeLineDoesNotCrash() {
        let diagnostic = Diagnostic(line: 999, severity: .error, message: "범위 밖")
        let rows = EditorDiagnosticPresentation.rows(code: Self.source, diagnostics: [diagnostic], toolName: "swiftc")
        #expect(rows.first?.codeLine == "")
    }
}
