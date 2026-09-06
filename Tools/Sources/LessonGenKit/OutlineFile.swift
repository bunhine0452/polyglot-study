public import Foundation
public import LearnCore

/// `tracks/<lang>.outline.json` 읽고 쓰기.
///
/// **자동 커밋하지 않는다.** 이 워크플로는 사람이 리뷰한 뒤에만 커밋한다 (쟁점 4) —
/// 여기서 하는 일은 파일을 놓는 것까지다.
public enum OutlineFile {
    public static func fileName(for language: LanguageID) -> String {
        "\(language.rawValue).outline.json"
    }

    public static func url(inDirectory directory: URL, language: LanguageID) -> URL {
        directory.appendingPathComponent(fileName(for: language), isDirectory: false)
    }

    /// 결정적 인코딩. 같은 개요는 항상 같은 바이트가 된다 — 리뷰 diff 가 실제 변경만
    /// 보여 주도록.
    public static func encode(_ outline: TrackOutline) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(outline)
        // POSIX 텍스트 파일은 개행으로 끝난다.
        data.append(0x0A)
        return data
    }

    public static func decode(_ data: Data) throws -> TrackOutline {
        try JSONDecoder().decode(TrackOutline.self, from: data)
    }

    /// 디렉터리를 만들고 파일을 쓴다. 쓰인 경로를 돌려준다.
    @discardableResult
    public static func write(
        _ outline: TrackOutline,
        toDirectory directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = url(inDirectory: directory, language: outline.language)
        try encode(outline).write(to: target, options: .atomic)
        return target
    }
}
