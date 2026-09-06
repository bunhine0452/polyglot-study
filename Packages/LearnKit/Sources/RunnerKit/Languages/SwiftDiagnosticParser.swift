public import LearnCore
internal import Foundation

/// `swiftc` 의 텍스트 진단을 `Diagnostic` 으로 정규화한다.
///
/// **swiftc 에는 JSON 진단이 없다.** `-fdiagnostics-format=json` 은 clang 전용이고
/// swiftc 에 넘기면 알 수 없는 인자로 거부된다. 유일하게 안정적인 것은
/// `-diagnostic-style=llvm` 이 내는 한 줄 형식이라, 그걸 파싱한다.
///
/// 필수 플래그 세 개와 이유:
///   - `-diagnostic-style=llvm` — 기본 `swift` 스타일은 상자 그림과 여러 줄 스니펫을
///     섞어 내서 줄 단위 파싱이 불가능하다.
///   - `-no-color-diagnostics` — ANSI 이스케이프가 끼면 정규식이 무너진다.
///     터미널이 아니어도 켜지는 경우가 있어 명시적으로 끈다.
///   - `-print-diagnostic-groups` — 메시지 끝에 `[#GroupName]` 이 붙는다.
///     이게 있어야 `Diagnostic.ruleID` 를 채울 수 있다(clippy 의 lint 이름과 같은 자리).
public enum SwiftDiagnosticParser {
    /// - Parameter workspaceRoot: 진단의 파일 경로를 이 디렉터리 기준 상대경로로 접는다.
    ///   `Diagnostic.file` 은 워크스페이스 기준이라는 계약이라 절대경로가 새면 안 된다.
    public static func parse(_ text: String, workspaceRoot: String? = nil) -> [Diagnostic] {
        // `Regex` 는 `Sendable` 이 아니라 전역 상수로 둘 수 없다. 줄마다 만들면 비싸므로
        // 호출당 한 번만 만들어 재사용한다.
        let located = /^(?<file>[^\n:]+):(?<line>\d+):(?<column>\d+): (?<severity>error|warning|note|remark): (?<message>.*)$/
        let lineOnly = /^(?<file>[^\n:]+):(?<line>\d+): (?<severity>error|warning|note|remark): (?<message>.*)$/
        let bare = /^(?:<unknown>:0: )?(?<severity>error|warning|note|remark): (?<message>.*)$/
        let group = /\s\[(?<ids>#[^\]]+)\]$/

        var diagnostics: [Diagnostic] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let match = line.wholeMatch(of: located) {
                diagnostics.append(make(
                    file: String(match.file),
                    line: Int(match.line),
                    column: Int(match.column),
                    severity: String(match.severity),
                    message: String(match.message),
                    group: group,
                    workspaceRoot: workspaceRoot
                ))
            } else if let match = line.wholeMatch(of: lineOnly) {
                diagnostics.append(make(
                    file: String(match.file),
                    line: Int(match.line),
                    column: nil,
                    severity: String(match.severity),
                    message: String(match.message),
                    group: group,
                    workspaceRoot: workspaceRoot
                ))
            } else if let match = line.wholeMatch(of: bare) {
                // 드라이버 수준 오류 — 링크 실패처럼 파일이 없는 진단이 여기로 온다.
                diagnostics.append(make(
                    file: nil,
                    line: nil,
                    column: nil,
                    severity: String(match.severity),
                    message: String(match.message),
                    group: group,
                    workspaceRoot: workspaceRoot
                ))
            }
            // 소스 스니펫과 캐럿 줄은 어느 패턴에도 안 맞는다 — 조용히 버린다.
        }
        return diagnostics
    }

    private static func make(
        file: String?,
        line: Int?,
        column: Int?,
        severity: String,
        message: String,
        group: Regex<(Substring, ids: Substring)>,
        workspaceRoot: String?
    ) -> Diagnostic {
        var text = message
        var ruleID: String?
        if let match = text.firstMatch(of: group) {
            // `[#no-usage]` 또는 `[#a, #b]`. `#` 은 표기이지 id 의 일부가 아니다.
            ruleID = String(match.ids)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                .joined(separator: ",")
            text.removeSubrange(match.range)
        }
        return Diagnostic(
            file: file.map { relative($0, to: workspaceRoot) },
            line: line,
            column: column,
            severity: Self.severity(severity),
            message: text.trimmingCharacters(in: .whitespaces),
            ruleID: ruleID
        )
    }

    private static func severity(_ text: String) -> Diagnostic.Severity {
        switch text {
        case "error": .error
        case "warning": .warning
        default: .note
        }
    }

    private static func relative(_ path: String, to root: String?) -> String {
        guard let root else { return path }
        let normalizedRoot = root.hasSuffix("/") ? root : root + "/"
        if path.hasPrefix(normalizedRoot) { return String(path.dropFirst(normalizedRoot.count)) }
        // `/private/var/...` 와 `/var/...` 는 같은 곳을 가리키는 다른 문자열이다.
        let resolvedRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().path + "/"
        if path.hasPrefix(resolvedRoot) { return String(path.dropFirst(resolvedRoot.count)) }
        return path
    }
}
