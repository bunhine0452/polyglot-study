public import LearnCore
internal import Foundation

/// `clang++` 의 텍스트 진단을 `Diagnostic` 으로 정규화한다.
///
/// **Apple clang 에는 JSON 진단이 없다.** `-fdiagnostics-format=json` 은 업스트림 clang 의
/// 기능이고 Apple clang 21 에 넘기면 `invalid value 'json'` 으로 거부된다(실측 2026-09-07).
/// `SwiftDiagnosticParser` 와 같은 이유로 한 줄 텍스트를 파싱한다.
///
/// 필수 플래그 둘과 이유:
///   - `-fno-color-diagnostics` — ANSI 이스케이프가 끼면 정규식이 무너진다. 터미널이
///     아니어도 켜지는 경우가 있어 명시적으로 끈다.
///   - `-fno-caret-diagnostics` — 캐럿·소스 스니펫 줄이 사라져 줄 단위 파싱이 깨끗해진다.
///     (없어도 스니펫은 어느 패턴에도 안 맞아 버려지지만, 출력이 몇 배로 길어져 학습자에게
///     흘려보내는 stderr 예산을 먹는다.)
///
/// swiftc 와 달리 **경고 그룹이 기본으로 붙는다** — `[-Wunused-variable]` 형태다.
/// 그래서 `-print-diagnostic-groups` 같은 추가 플래그 없이 `ruleID` 를 채울 수 있다.
public enum CppDiagnosticParser {
    /// - Parameter workspaceRoot: 진단의 파일 경로를 이 디렉터리 기준 상대경로로 접는다.
    ///   `Diagnostic.file` 은 워크스페이스 기준이라는 계약이라 절대경로가 새면 안 된다.
    public static func parse(_ text: String, workspaceRoot: String? = nil) -> [Diagnostic] {
        // `Regex` 는 `Sendable` 이 아니라 전역 상수로 둘 수 없다. 호출당 한 번만 만든다.
        let located =
            /^(?<file>[^\n:]+):(?<line>\d+):(?<column>\d+): (?<severity>error|warning|note|remark|fatal error): (?<message>.*)$/
        let lineOnly =
            /^(?<file>[^\n:]+):(?<line>\d+): (?<severity>error|warning|note|remark|fatal error): (?<message>.*)$/
        // 드라이버·링커 오류. `ld: symbol(s) not found` 처럼 파일이 없는 진단이 여기로 온다.
        let bare = /^(?:clang(?:\+\+)?|ld): (?<severity>error|warning|fatal error): (?<message>.*)$/
        let group = /\s\[(?<ids>-[^\]]+)\]$/

        var diagnostics: [Diagnostic] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let match = line.wholeMatch(of: located) {
                diagnostics.append(make(
                    file: String(match.file), line: Int(match.line), column: Int(match.column),
                    severity: String(match.severity), message: String(match.message),
                    group: group, workspaceRoot: workspaceRoot))
            } else if let match = line.wholeMatch(of: lineOnly) {
                diagnostics.append(make(
                    file: String(match.file), line: Int(match.line), column: nil,
                    severity: String(match.severity), message: String(match.message),
                    group: group, workspaceRoot: workspaceRoot))
            } else if let match = line.wholeMatch(of: bare) {
                diagnostics.append(make(
                    file: nil, line: nil, column: nil,
                    severity: String(match.severity), message: String(match.message),
                    group: group, workspaceRoot: workspaceRoot))
            }
            // 소스 스니펫·캐럿·`In file included from` 줄은 어느 패턴에도 안 맞는다 — 버린다.
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
            // `[-Wunused-variable]`. 선행 `-W` 는 표기가 아니라 이름의 일부다 — clang 의
            // 문서와 `-Wno-…` 로 끄는 이름이 그 형태라 그대로 둔다. (swiftc 의 `#` 은
            // 표기라서 벗기는 것과 대비된다.)
            ruleID = String(match.ids)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
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
        case "error", "fatal error": .error
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
