public import LearnCore
internal import Foundation

/// `rustc --error-format=json` 의 진단을 `Diagnostic` 으로 정규화한다.
///
/// **셋 중 유일하게 구조화 진단이 있는 툴체인이다.** swiftc 에는 JSON 진단이 아예 없고
/// (`SwiftDiagnosticParser` 참고), Apple clang 은 `-fdiagnostics-format=json` 을 거부한다
/// (`CppDiagnosticParser` 참고). rustc 만 안정판에서 한 줄 하나가 JSON 객체로 나온다 —
/// 그래서 여기는 정규식이 없다.
///
/// 얻는 것이 하나 더 있다: `code.code` 가 `E0308` 처럼 오는데 그게 그대로 `ruleID` 다.
/// 학습자가 `rustc --explain E0308` 로 설명을 펼칠 수 있는 바로 그 값이다.
public enum RustDiagnosticParser {
    /// rustc 가 내는 한 줄 JSON. 필요한 필드만 받는다 — `code.explanation` 은 오류 하나에
    /// 수 KB 짜리 산문이 붙어 오므로 **일부러 디코드하지 않는다.**
    private struct Record: Decodable {
        struct Code: Decodable { var code: String? }
        struct Span: Decodable {
            var file_name: String?
            var line_start: Int?
            var column_start: Int?
            var is_primary: Bool?
        }
        var message: String?
        var level: String?
        var code: Code?
        var spans: [Span]?
    }

    /// - Parameter workspaceRoot: 진단의 파일 경로를 이 디렉터리 기준 상대경로로 접는다.
    ///   `Diagnostic.file` 은 워크스페이스 기준이라는 계약이라 절대경로가 새면 안 된다.
    public static func parse(_ text: String, workspaceRoot: String? = nil) -> [Diagnostic] {
        let decoder = JSONDecoder()
        var diagnostics: [Diagnostic] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // rustc 는 JSON 만 내지만, 러너가 흘린 다른 줄이 섞여도 조용히 지나가야 한다.
            guard line.hasPrefix("{"), let data = line.data(using: .utf8),
                  let record = try? decoder.decode(Record.self, from: data),
                  let message = record.message
            else { continue }

            // `failure-note`("For more information ...")와 `aborting due to N previous
            // errors" 는 요약이지 진단이 아니다. 인라인 진단 행에 그리면 학습자가 고칠
            // 자리를 가리키지 않는 줄이 섞인다.
            let level = record.level ?? "error"
            if level == "failure-note" { continue }
            if message.hasPrefix("aborting due to") { continue }
            if message.hasPrefix("For more information about") { continue }

            // primary span 이 학습자가 고칠 자리다. 없으면(링크 오류 등) 위치 없는 진단이다.
            let span = record.spans?.first { $0.is_primary == true } ?? record.spans?.first
            diagnostics.append(Diagnostic(
                file: span?.file_name.map { relative($0, to: workspaceRoot) },
                line: span?.line_start,
                column: span?.column_start,
                severity: severity(level),
                message: message,
                // `E0308`. `rustc --explain` 에 그대로 넘길 수 있는 값이다.
                ruleID: record.code?.code
            ))
        }
        return diagnostics
    }

    private static func severity(_ level: String) -> Diagnostic.Severity {
        switch level {
        case "error", "error: internal compiler error": .error
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
