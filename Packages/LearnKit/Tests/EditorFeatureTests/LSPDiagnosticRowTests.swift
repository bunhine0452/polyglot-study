import Foundation
import LearnCore
import LSPKit
import Testing

@testable import EditorFeature

/// `{#lsp-diagnostics}` — 언어 서버 진단이 `swiftc` 진단과 **같은 컴포넌트**로
/// 그려지고 출처는 **라벨로만** 구분된다.
@Suite("`{#lsp-diagnostics}` · 두 출처가 한 컴포넌트로")
struct LSPDiagnosticRowTests {
    static let source = "struct Counter {\n    var count = 0\n    func increment() {\n        count += 1\n    }\n}\n"

    static func diagnostic(
        line: Int, column: Int? = nil, severity: Diagnostic.Severity = .error, message: String = "boom"
    ) -> Diagnostic {
        Diagnostic(file: "Solution.swift", line: line, column: column, severity: severity, message: message)
    }

    /// 완료 기준 그대로: 같은 행 구조, 라벨만 다르다.
    @Test("언어 서버 진단이 swiftc 진단과 같은 행 구조로 나오고 라벨만 다르다")
    func bothSourcesProduceTheSameRowShape() {
        let diagnostic = Self.diagnostic(line: 4, column: 9, message: "'self' 는 불변입니다.")

        let fromCompiler = EditorDiagnosticPresentation.rows(
            groups: [DiagnosticSourceGroup(toolName: "swiftc", code: Self.source, diagnostics: [diagnostic])]
        )
        let fromServer = EditorDiagnosticPresentation.rows(
            groups: [
                DiagnosticSourceGroup(toolName: "sourcekit-lsp", code: Self.source, diagnostics: [diagnostic])
            ]
        )

        #expect(fromCompiler.count == 1)
        #expect(fromServer.count == 1)
        // 라벨 말고는 전부 같다 — 같은 뷰가 같은 재료를 받는다는 뜻이다.
        #expect(fromCompiler[0].line == fromServer[0].line)
        #expect(fromCompiler[0].column == fromServer[0].column)
        #expect(fromCompiler[0].codeLine == fromServer[0].codeLine)
        #expect(fromCompiler[0].message == fromServer[0].message)
        #expect(fromCompiler[0].severity == fromServer[0].severity)
        // 다른 것은 라벨뿐이다.
        #expect(fromCompiler[0].locationLabel == "4행 9열 · swiftc · 1개")
        #expect(fromServer[0].locationLabel == "4행 9열 · sourcekit-lsp · 1개")
    }

    @Test("같은 줄에 두 출처가 겹치면 한 행으로 접히고 라벨에 둘 다 남는다")
    func overlappingLinesCollapseAndNameBothSources() {
        let rows = EditorDiagnosticPresentation.rows(groups: [
            DiagnosticSourceGroup(
                toolName: "sourcekit-lsp", code: Self.source,
                diagnostics: [Self.diagnostic(line: 4, column: 9, message: "서버가 본 것")]
            ),
            DiagnosticSourceGroup(
                toolName: "swiftc", code: Self.source,
                diagnostics: [Self.diagnostic(line: 4, column: 9, severity: .warning, message: "컴파일러가 본 것")]
            ),
        ])
        #expect(rows.count == 1)
        #expect(rows[0].locationLabel == "4행 9열 · sourcekit-lsp/swiftc · 2개")
        // 심각도는 나쁜 쪽이 이긴다.
        #expect(rows[0].severity == .error)
        // 대표 메시지는 앞 그룹의 것이다.
        #expect(rows[0].message == "서버가 본 것")
    }

    @Test("서로 다른 줄이면 각자 자기 출처만 라벨에 적는다")
    func separateLinesKeepSeparateLabels() {
        let rows = EditorDiagnosticPresentation.rows(groups: [
            DiagnosticSourceGroup(
                toolName: "sourcekit-lsp", code: Self.source,
                diagnostics: [Self.diagnostic(line: 2, message: "서버")]
            ),
            DiagnosticSourceGroup(
                toolName: "swiftc", code: Self.source,
                diagnostics: [Self.diagnostic(line: 4, message: "컴파일러")]
            ),
        ])
        #expect(rows.map(\.line) == [2, 4])
        #expect(rows[0].locationLabel == "2행 · sourcekit-lsp · 1개")
        #expect(rows[1].locationLabel == "4행 · swiftc · 1개")
    }

    /// 두 출처의 스냅샷이 다를 수 있다 — `swiftc` 진단은 마지막으로 **실행한** 코드,
    /// 언어 서버 진단은 **지금 편집 중인** 코드 기준이다.
    @Test("코드 줄은 먼저 온 그룹의 스냅샷에서 온다")
    func codeLineComesFromTheFirstGroupSnapshot() {
        let fresh = "첫 줄\n서버가 보는 둘째 줄\n"
        let stale = "첫 줄\n실행했을 때의 둘째 줄\n"
        let rows = EditorDiagnosticPresentation.rows(groups: [
            DiagnosticSourceGroup(
                toolName: "sourcekit-lsp", code: fresh, diagnostics: [Self.diagnostic(line: 2)]
            ),
            DiagnosticSourceGroup(
                toolName: "swiftc", code: stale, diagnostics: [Self.diagnostic(line: 2)]
            ),
        ])
        #expect(rows.count == 1)
        #expect(rows[0].codeLine == "서버가 보는 둘째 줄")
    }

    @Test("한 출처만 있으면 예전 진입점과 결과가 같다 — 회귀 방어")
    func singleGroupMatchesTheLegacyEntryPoint() {
        let diagnostics = [
            Self.diagnostic(line: 4, column: 9, message: "첫 번째"),
            Self.diagnostic(line: 4, column: 9, severity: .warning, message: "두 번째"),
        ]
        let legacy = EditorDiagnosticPresentation.rows(
            code: Self.source, diagnostics: diagnostics, toolName: "swiftc"
        )
        let grouped = EditorDiagnosticPresentation.rows(groups: [
            DiagnosticSourceGroup(toolName: "swiftc", code: Self.source, diagnostics: diagnostics)
        ])
        #expect(legacy == grouped)
        #expect(legacy.first?.locationLabel == "4행 9열 · swiftc · 2개")
    }

    @Test("그룹이 비면 행도 없다")
    func emptyGroupsProduceNoRows() {
        #expect(EditorDiagnosticPresentation.rows(groups: []).isEmpty)
        #expect(
            EditorDiagnosticPresentation.rows(groups: [
                DiagnosticSourceGroup(toolName: "swiftc", code: Self.source, diagnostics: [])
            ]).isEmpty
        )
    }

    /// LSP 매핑에서 나온 진단이 이 행 조립기를 그대로 통과하는지 — 두 계층이 만나는
    /// 지점이라 따로 본다.
    @Test("LSPKit 이 매핑한 진단이 그대로 행이 된다")
    func mappedLSPDiagnosticsFlowIntoRows() {
        let text = "import Foundation\n\nlet count: Int = \"틀렸다\"\n"
        let params = PublishDiagnosticsParams(
            uri: LSPDiagnosticMapping.uri(forPath: "/tmp/ws/Solution.swift"),
            diagnostics: [
                LSPDiagnostic(
                    severity: 1,
                    range: LSPRange(
                        start: LSPPosition(line: 2, character: 17),
                        end: LSPPosition(line: 2, character: 22)
                    ),
                    message: "Cannot convert value of type 'String' to specified type 'Int'",
                    source: "SourceKit"
                )
            ]
        )
        let mapped = LSPDiagnosticMapping.map(params, documentText: text, workspaceRoot: "/tmp/ws")
        let rows = EditorDiagnosticPresentation.rows(groups: [
            DiagnosticSourceGroup(toolName: "sourcekit-lsp", code: text, diagnostics: mapped)
        ])
        #expect(rows.count == 1)
        #expect(rows[0].line == 3)
        #expect(rows[0].codeLine == "let count: Int = \"틀렸다\"")
        #expect(rows[0].severity == .error)
        #expect(rows[0].locationLabel.hasSuffix("· sourcekit-lsp · 1개"))
        // `source`("SourceKit")가 규칙 id 로 새지 않았다 — 출처는 라벨의 몫이다.
        #expect(mapped[0].ruleID == nil)
    }
}
