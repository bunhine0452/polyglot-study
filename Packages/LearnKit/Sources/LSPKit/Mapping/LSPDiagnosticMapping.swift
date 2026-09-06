public import LearnCore
internal import Foundation

/// LSP 진단 → `LearnCore.Diagnostic`.
///
/// 이 매핑은 **프로세스가 없다.** 서버 없이 전부 테스트할 수 있어야 한다는 것이 이
/// 저장소의 규약이고, 실제로 여기 있는 세 변환(좌표계·URI·심각도)이 전부 조용히
/// 틀리기 쉬운 것들이다.
///
/// 세 좌표계가 얽힌다:
///   - LSP: `line`·`character` 둘 다 **0-기반**, `character` 는 그 줄의 **UTF-16 코드
///     단위** 오프셋.
///   - `LearnCore.Diagnostic`: `line`·`column` 둘 다 **1-기반**, `column` 은 "UTF-16
///     오프셋이 아니라 표시용 칼럼" 이라고 타입 주석이 못박고 있다.
///   - `swiftc`: 1-기반. 같은 자리에 같은 숫자가 찍혀야 인라인 진단 행이 두 출처를
///     섞어 그릴 수 있다.
public enum LSPDiagnosticMapping {
    /// LSP `DiagnosticSeverity` → 도메인 심각도.
    ///
    /// LSP 에는 네 단계(error·warning·information·hint)가 있고 도메인에는 셋뿐이다.
    /// information·hint 는 둘 다 `note` 로 접는다 — 인라인 행에서 둘을 구분해 봐야
    /// 무채색 UI 에 표현할 자리가 없다.
    ///
    /// **심각도가 없는 진단은 `error` 다.** LSP 스펙은 "클라이언트가 정한다" 고만
    /// 하는데, 이 앱에서 진단이 뜨는 자리는 학습자가 코드를 고쳐야 하는 자리라
    /// 놓치는 쪽보다 과하게 보이는 쪽이 낫다.
    public static func severity(_ raw: Int?) -> Diagnostic.Severity {
        switch raw {
        case 1: .error
        case 2: .warning
        case 3, 4: .note
        default: .error
        }
    }

    /// `file:` URI → 파일 시스템 경로. URI 가 아니거나 file 스킴이 아니면 nil.
    ///
    /// 퍼센트 인코딩을 직접 풀지 않는다 — 공백·한글이 든 경로에서 손으로 푼 구현이
    /// 반드시 틀린다. `URL` 에 맡긴다.
    public static func path(fromURI uri: String) -> String? {
        guard let url = URL(string: uri), url.isFileURL else { return nil }
        return url.path
    }

    /// 파일 시스템 경로 → `file:` URI. `didOpen` 에 실어 보낼 때 쓴다.
    public static func uri(forPath path: String) -> String {
        URL(fileURLWithPath: path).absoluteString
    }

    /// 한 줄 안의 **UTF-16 오프셋**을 1-기반 표시 칼럼으로 옮긴다.
    ///
    /// 이게 필요한 이유: `"let 🇰🇷 = 1"` 에서 태극기는 Character 하나지만 UTF-16 으로는
    /// **네 코드 단위**다. LSP 가 준 `character: 7` 을 그대로 `column: 8` 로 쓰면
    /// 라벨이 "8열" 이라고 하는데 눈으로 세면 5열이다.
    ///
    /// 오프셋이 줄 길이를 넘으면 줄 끝 다음 칼럼으로 붙인다 — 서버가 줄 끝을 가리키는
    /// 진단(예: "여기에 뭔가 빠졌다")을 흔히 낸다.
    public static func displayColumn(utf16Offset: Int, in line: String) -> Int {
        guard utf16Offset > 0 else { return 1 }
        var consumed = 0
        var column = 1
        for character in line {
            if consumed >= utf16Offset { return column }
            consumed += character.utf16.count
            column += 1
        }
        return column
    }

    /// 진단 하나를 옮긴다.
    ///
    /// - Parameters:
    ///   - documentText: 진단이 가리키는 문서의 본문. 있으면 칼럼을 표시용으로 정확히
    ///     환산하고, 없으면 `character + 1` 로 떨어진다(ASCII 에서는 같은 값이다).
    ///   - path: 문서의 파일 시스템 경로. `workspaceRoot` 기준 상대경로로 접는다.
    public static func map(
        _ diagnostic: LSPDiagnostic,
        path: String?,
        documentText: String?,
        workspaceRoot: String?
    ) -> Diagnostic {
        let start = diagnostic.range.start
        let line = start.line + 1
        let column: Int
        if let documentText, let text = LSPPositionConversion.line(start.line, of: documentText) {
            column = displayColumn(utf16Offset: start.character, in: text)
        } else {
            column = start.character + 1
        }

        return Diagnostic(
            file: path.map { relative($0, to: workspaceRoot) },
            line: line,
            column: column,
            severity: severity(diagnostic.severity),
            message: diagnostic.message,
            // `source`("SourceKit")는 규칙 id 가 아니라 **낸 도구**다. 그건 인라인 진단
            // 행의 라벨로 가고, `ruleID` 에는 규칙 id 인 `code` 만 넣는다.
            // 이 구분이 없으면 라벨 자리에 "SourceKit" 이 두 번 찍힌다.
            ruleID: diagnostic.code.map(\.description)
        )
    }

    /// `publishDiagnostics` 알림 하나를 통째로 옮긴다.
    public static func map(
        _ params: PublishDiagnosticsParams,
        documentText: String?,
        workspaceRoot: String?
    ) -> [Diagnostic] {
        let path = self.path(fromURI: params.uri)
        return params.diagnostics.map {
            map($0, path: path, documentText: documentText, workspaceRoot: workspaceRoot)
        }
    }

    /// `SwiftDiagnosticParser` 와 **같은 규칙**이다. 두 출처의 `file` 이 같은 모양이어야
    /// 인라인 진단 행이 둘을 한 줄로 접을 수 있다.
    static func relative(_ path: String, to root: String?) -> String {
        guard let root else { return path }
        let normalizedRoot = root.hasSuffix("/") ? root : root + "/"
        if path.hasPrefix(normalizedRoot) { return String(path.dropFirst(normalizedRoot.count)) }
        // `/private/var/...` 와 `/var/...` 는 같은 곳을 가리키는 다른 문자열이다.
        let resolvedRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().path + "/"
        if path.hasPrefix(resolvedRoot) { return String(path.dropFirst(resolvedRoot.count)) }
        return path
    }
}
