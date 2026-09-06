/// 컴파일러·린터·테스트 러너가 뱉는 진단 하나를 언어 중립으로 정규화한 것.
///
/// 언어마다 원본 형식이 다르다 — `clang -fdiagnostics-format=json`, `cargo` 의 JSON,
/// `pytest` 리포트, SQLite 의 평문 에러. 어댑터가 전부 이 타입으로 옮기고,
/// UI 는 원본 형식을 몰라도 gutter 에 찍을 수 있다.
public struct Diagnostic: Hashable, Sendable, Codable {
    public enum Severity: String, Hashable, Sendable, Codable {
        case note, warning, error
    }

    /// 워크스페이스 기준 상대 경로. 파일을 특정할 수 없는 진단은 nil.
    public var file: String?
    /// 1-기반. 열 위치는 UTF-16 오프셋이 아니라 표시용 칼럼이다.
    public var line: Int?
    public var column: Int?
    public var severity: Severity
    public var message: String
    /// 러너가 규칙 id 를 주는 경우에만 (예: clippy 의 lint 이름).
    public var ruleID: String?

    public init(
        file: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        severity: Severity,
        message: String,
        ruleID: String? = nil
    ) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        self.ruleID = ruleID
    }
}
