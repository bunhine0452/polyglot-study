public import Foundation

/// `.env` 파일에서 읽은 설정.
///
/// **프로세스 환경변수가 항상 이긴다.** `.env` 는 개발 셸의 편의일 뿐이고, CI 나
/// 명시적 `export` 로 준 값을 파일이 덮는 일은 없어야 한다 — 그 반대는 "왜 내 키가
/// 안 먹지" 를 만드는 고전적 함정이다.
///
/// 외부 dotenv 의존성을 들이지 않는다. 우리가 쓰는 문법은 네 줄이면 끝나고, 이 파일이
/// **비밀값을 읽는 경로**라서 남의 파서를 신뢰 경계 안에 넣을 이유가 없다.
///
/// 지원하는 문법:
/// ```
/// # 주석
/// KEY=value
/// KEY="따옴표 안의 값"      # 큰따옴표·작은따옴표 벗김
/// export KEY=value          # 셸에 그대로 source 하는 사람들 대비
/// ```
/// 지원하지 않는 것: 여러 줄 값, 변수 보간(`${OTHER}`), 이스케이프 시퀀스. 필요해지면
/// 그때 늘린다 — 지금 넣으면 검증되지 않은 코드가 비밀값 경로에 앉는다.
public struct DotEnv: Sendable {
    /// 위로 올라가며 찾을 파일 이름.
    public static let fileName = ".env"

    public let values: [String: String]
    /// 실제로 읽은 파일. 못 찾았으면 `nil`.
    public let sourceURL: URL?

    public init(values: [String: String], sourceURL: URL? = nil) {
        self.values = values
        self.sourceURL = sourceURL
    }

    /// 아무것도 없는 상태.
    public static let empty = DotEnv(values: [:])

    /// 텍스트를 판다. 파일 시스템을 건드리지 않는 **순수 함수**라 전량 검증된다.
    public static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        // `split(separator: "\n")` 를 쓰면 안 된다 — Swift 에서 `\r\n` 은 **문자 하나**라
        // CRLF 파일이 한 줄로 뭉쳐 버린다. `isNewline` 은 그 조합을 구분자로 본다.
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            result[key] = unquote(value)
        }
        return result
    }

    /// 따옴표로 감싼 값에서 따옴표만 벗긴다. 안쪽은 손대지 않는다.
    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        for quote in ["\"", "'"] where value.hasPrefix(quote) && value.hasSuffix(quote) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    /// `directory` 에서 시작해 루트까지 올라가며 첫 `.env` 를 읽는다.
    ///
    /// - Parameter limit: 올라갈 최대 단계. 무한 루프 방어이자, 홈 디렉터리 밖까지
    ///   훑지 않게 하는 상한이다.
    public static func discover(
        startingAt directory: URL,
        fileName: String = DotEnv.fileName,
        limit: Int = 12,
        fileManager: FileManager = .default
    ) -> DotEnv {
        var current = directory.standardizedFileURL
        for _ in 0..<limit {
            let candidate = current.appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: candidate.path),
               let text = try? String(contentsOf: candidate, encoding: .utf8) {
                return DotEnv(values: parse(text), sourceURL: candidate)
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path { break }
            current = parent
        }
        return .empty
    }

    /// 명시된 파일 하나만 읽는다. `--env-file` 이 쓴다. 없으면 던진다 — 사용자가
    /// 경로를 짚어 줬는데 조용히 무시하면 안 된다.
    public static func load(from url: URL) throws -> DotEnv {
        let text = try String(contentsOf: url, encoding: .utf8)
        return DotEnv(values: parse(text), sourceURL: url)
    }
}

/// 프로세스 환경변수와 `.env` 를 겹쳐 놓은 조회 창구.
///
/// 키와 모델을 읽는 **모든** 경로가 이걸 통과하게 해서 우선순위 규칙이 한 군데에만
/// 있게 한다.
public struct EnvironmentSource: Sendable {
    public let process: [String: String]
    public let dotEnv: DotEnv

    public init(
        process: [String: String] = ProcessInfo.processInfo.environment,
        dotEnv: DotEnv = .empty
    ) {
        self.process = process
        self.dotEnv = dotEnv
    }

    /// 현재 작업 디렉터리에서 위로 올라가며 `.env` 를 찾아 겹친다.
    public static func discovering(
        process: [String: String] = ProcessInfo.processInfo.environment,
        startingAt directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> EnvironmentSource {
        EnvironmentSource(process: process, dotEnv: DotEnv.discover(startingAt: directory))
    }

    /// 프로세스 환경변수 우선, 없으면 `.env`.
    public subscript(name: String) -> String? {
        if let value = process[name], !value.isEmpty { return value }
        return dotEnv.values[name]
    }

    /// 이 값이 어디서 왔는지. 로그에 남긴다 — **이름만이고 값은 아니다.**
    public func origin(of name: String) -> String? {
        if let value = process[name], !value.isEmpty { return "환경변수" }
        guard dotEnv.values[name] != nil else { return nil }
        return dotEnv.sourceURL.map { "\($0.lastPathComponent) (\($0.deletingLastPathComponent().path))" } ?? ".env"
    }

    /// 평평한 사전. `APIKey.fromEnvironment(_:)` 처럼 사전을 받는 자리에 넘긴다.
    public var merged: [String: String] {
        dotEnv.values.merging(process.filter { !$0.value.isEmpty }) { _, processValue in processValue }
    }
}
