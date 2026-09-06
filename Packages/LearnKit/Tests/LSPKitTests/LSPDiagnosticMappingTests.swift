import Foundation
import LearnCore
import Testing

@testable import LSPKit

@Suite("LSP 진단 → LearnCore.Diagnostic")
struct LSPDiagnosticMappingTests {
    static func diagnostic(
        line: Int, character: Int, severity: Int? = 1,
        message: String = "boom", source: String? = "SourceKit", code: LSPCode? = nil
    ) -> LSPDiagnostic {
        LSPDiagnostic(
            severity: severity,
            range: LSPRange(
                start: LSPPosition(line: line, character: character),
                end: LSPPosition(line: line, character: character + 1)
            ),
            message: message,
            source: source,
            code: code
        )
    }

    @Test("0-기반 LSP 좌표가 1-기반 도메인 좌표가 된다")
    func coordinatesShiftByOne() {
        let mapped = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 3, character: 14),
            path: "Solution.swift", documentText: nil, workspaceRoot: nil
        )
        #expect(mapped.line == 4)
        #expect(mapped.column == 15)
    }

    /// 실측 그대로: sourcekit-lsp 가 `print(greeting.)` 에 대해 이 진단을 낸다.
    @Test("실측 진단이 그대로 옮겨진다")
    func realWorldDiagnosticMapsFaithfully() {
        let text = "import Foundation\n\nlet greeting = \"hello\"\nprint(greeting.)\n"
        let mapped = LSPDiagnosticMapping.map(
            Self.diagnostic(
                line: 3, character: 14, severity: 1,
                message: "Expected member name following '.'"
            ),
            path: "Solution.swift", documentText: text, workspaceRoot: nil
        )
        #expect(mapped.line == 4)
        #expect(mapped.column == 15)
        #expect(mapped.severity == .error)
        #expect(mapped.message == "Expected member name following '.'")
        #expect(mapped.file == "Solution.swift")
        // `source`("SourceKit")는 규칙 id 가 아니다. 그건 인라인 행의 라벨로 간다.
        #expect(mapped.ruleID == nil)
    }

    @Test("심각도 네 단계가 세 단계로 접힌다")
    func severityFoldsFromFourToThree() {
        #expect(LSPDiagnosticMapping.severity(1) == .error)
        #expect(LSPDiagnosticMapping.severity(2) == .warning)
        #expect(LSPDiagnosticMapping.severity(3) == .note)
        #expect(LSPDiagnosticMapping.severity(4) == .note)
    }

    @Test("심각도가 없으면 error 다 — 놓치는 것보다 과한 편이 낫다")
    func missingSeverityBecomesError() {
        #expect(LSPDiagnosticMapping.severity(nil) == .error)
        #expect(LSPDiagnosticMapping.severity(99) == .error)
    }

    @Test("code 는 ruleID 로, 정수든 문자열이든")
    func codeBecomesRuleID() {
        let numeric = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 0, character: 0, code: .number(42)),
            path: nil, documentText: nil, workspaceRoot: nil
        )
        #expect(numeric.ruleID == "42")

        let textual = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 0, character: 0, code: .string("unused-variable")),
            path: nil, documentText: nil, workspaceRoot: nil
        )
        #expect(textual.ruleID == "unused-variable")
    }

    // MARK: - UTF-16 ↔ 표시 칼럼

    /// LSP 의 `character` 는 **UTF-16 코드 단위**다. 이모지·국기가 섞이면 눈으로 센
    /// 칼럼과 어긋난다.
    @Test("UTF-16 오프셋이 표시 칼럼으로 환산된다")
    func utf16OffsetBecomesDisplayColumn() {
        // "let 🇰🇷 = 1" — 태극기는 Character 하나, UTF-16 으로는 네 단위.
        let line = "let 🇰🇷 = 1"
        #expect(line.count == 9)
        #expect(line.utf16.count == 12)

        // 태극기 **앞**(offset 4) 은 5열.
        #expect(LSPDiagnosticMapping.displayColumn(utf16Offset: 4, in: line) == 5)
        // 태극기 **뒤**(offset 8) 는 6열이다. 그대로 +1 하면 9열이라고 거짓말한다.
        #expect(LSPDiagnosticMapping.displayColumn(utf16Offset: 8, in: line) == 6)
    }

    @Test("본문이 없으면 UTF-16 오프셋 + 1 로 떨어진다")
    func withoutDocumentTextColumnFallsBack() {
        let mapped = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 0, character: 8),
            path: nil, documentText: nil, workspaceRoot: nil
        )
        #expect(mapped.column == 9)
    }

    @Test("ASCII 에서는 환산해도 값이 같다 — swiftc 와 같은 자리를 가리킨다")
    func asciiColumnsAgreeWithSwiftc() {
        let line = "        count += 1"
        for offset in 0...line.utf16.count {
            #expect(LSPDiagnosticMapping.displayColumn(utf16Offset: offset, in: line) == offset + 1)
        }
    }

    @Test("줄 끝을 넘는 오프셋은 줄 끝 다음 칼럼이다")
    func offsetPastEndClampsToEnd() {
        #expect(LSPDiagnosticMapping.displayColumn(utf16Offset: 99, in: "abc") == 4)
    }

    @Test("범위 밖 줄 번호여도 깨지지 않는다")
    func outOfRangeLineDoesNotCrash() {
        let mapped = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 999, character: 3),
            path: nil, documentText: "한 줄뿐\n", workspaceRoot: nil
        )
        #expect(mapped.line == 1000)
        #expect(mapped.column == 4)
    }

    @Test("CRLF 본문에서도 칼럼이 맞는다")
    func crlfDocumentColumnsAreCorrect() {
        let text = "let a = 1\r\nlet b = 2\r\n"
        let mapped = LSPDiagnosticMapping.map(
            Self.diagnostic(line: 1, character: 4),
            path: nil, documentText: text, workspaceRoot: nil
        )
        #expect(mapped.line == 2)
        #expect(mapped.column == 5)
    }

    // MARK: - URI

    @Test("file URI 가 경로가 되고 경로가 URI 가 된다")
    func uriRoundTrips() throws {
        let path = "/tmp/learnkit/Solution.swift"
        let uri = LSPDiagnosticMapping.uri(forPath: path)
        #expect(uri.hasPrefix("file://"))
        #expect(LSPDiagnosticMapping.path(fromURI: uri) == path)
    }

    @Test("공백과 한글이 든 경로도 왕복한다")
    func uriHandlesSpacesAndHangul() throws {
        let path = "/tmp/내 작업 공간/해답.swift"
        let uri = LSPDiagnosticMapping.uri(forPath: path)
        // 퍼센트 인코딩이 실제로 일어났는지 확인한다 — 안 하면 서버가 URI 를 거부한다.
        #expect(uri.contains("%"))
        #expect(LSPDiagnosticMapping.path(fromURI: uri) == path)
    }

    @Test("file 스킴이 아니면 경로가 아니다")
    func nonFileURIHasNoPath() {
        #expect(LSPDiagnosticMapping.path(fromURI: "https://example.com/a.swift") == nil)
        #expect(LSPDiagnosticMapping.path(fromURI: "not a uri at all") == nil)
    }

    /// `SwiftDiagnosticParser` 와 같은 규칙이어야 인라인 진단 행이 두 출처를 한 줄로
    /// 접을 수 있다. `/var` ↔ `/private/var` 도 같은 곳이다.
    @Test("절대경로는 워크스페이스 기준 상대경로로 접힌다")
    func absolutePathsFoldToWorkspaceRelative() {
        #expect(
            LSPDiagnosticMapping.relative("/tmp/ws/Solution.swift", to: "/tmp/ws") == "Solution.swift"
        )
        #expect(
            LSPDiagnosticMapping.relative("/tmp/ws/Solution.swift", to: "/tmp/ws/") == "Solution.swift"
        )
        #expect(LSPDiagnosticMapping.relative("/elsewhere/a.swift", to: "/tmp/ws") == "/elsewhere/a.swift")
        #expect(LSPDiagnosticMapping.relative("/tmp/ws/a.swift", to: nil) == "/tmp/ws/a.swift")
    }

    @Test("publishDiagnostics 한 묶음이 통째로 옮겨진다")
    func publishDiagnosticsParamsMapWholesale() {
        let params = PublishDiagnosticsParams(
            uri: LSPDiagnosticMapping.uri(forPath: "/tmp/ws/Solution.swift"),
            version: 3,
            diagnostics: [
                Self.diagnostic(line: 0, character: 0, severity: 1, message: "첫째"),
                Self.diagnostic(line: 4, character: 2, severity: 2, message: "둘째"),
            ]
        )
        let mapped = LSPDiagnosticMapping.map(params, documentText: nil, workspaceRoot: "/tmp/ws")
        #expect(mapped.count == 2)
        #expect(mapped.allSatisfy { $0.file == "Solution.swift" })
        #expect(mapped[0].severity == .error)
        #expect(mapped[1].severity == .warning)
        #expect(mapped[1].line == 5)
    }

    @Test("진단이 비면 결과도 빈다 — 고쳤을 때 행이 사라지는 경로")
    func emptyDiagnosticsClearTheList() {
        let params = PublishDiagnosticsParams(uri: "file:///tmp/a.swift", diagnostics: [])
        #expect(LSPDiagnosticMapping.map(params, documentText: nil, workspaceRoot: nil).isEmpty)
    }
}
