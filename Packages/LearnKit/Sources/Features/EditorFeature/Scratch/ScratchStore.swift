public import Foundation

/// 연습장 파일을 디스크에 두는 곳.
///
/// **DB 가 아니라 파일이다.** 학습자가 쓴 코드는 앱이 소유한 상태가 아니라 그 사람의
/// 것이고, 앱을 지워도 남아야 하며, 필요하면 Finder 에서 열어 다른 도구로 편집할 수
/// 있어야 한다. `LearnPersistence` 에 넣으면 그 셋 다 잃는다.
///
/// 언어마다 디렉터리를 가른다 — `Scratch/rust/main.rs` 처럼. 같은 디렉터리에 섞으면
/// 실행기에 넘길 파일을 고를 때 확장자로 걸러야 하고, 그러면 `.h` 처럼 확장자만으로는
/// 언어를 못 가르는 파일에서 무너진다.
public struct ScratchStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// 기본 자리 — `Application Support/LearnKit/Scratch`. DB 와 설치된 팩 옆이다.
    public static func defaultRoot() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("LearnKit", isDirectory: true)
            .appendingPathComponent("Scratch", isDirectory: true)
    }

    public func directory(for language: ScratchLanguage) -> URL {
        root.appendingPathComponent(language.rawValue, isDirectory: true)
    }

    /// 그 언어의 파일 전부. 진입점이 **언제나 맨 앞**이고 나머지는 이름순이다.
    ///
    /// 디렉터리가 없거나 비어 있으면 진입점 하나를 시작 코드와 함께 만들어 돌려준다 —
    /// 빈 목록을 화면에 그리는 상태를 아예 만들지 않는다.
    public func load(_ language: ScratchLanguage) -> [ScratchFile] {
        let directory = self.directory(for: language)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var files: [ScratchFile] = []
        for name in names.sorted() where !name.hasPrefix(".") {
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let contents = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            files.append(ScratchFile(name: name, contents: contents))
        }

        if !files.contains(where: { $0.name == language.entryFileName }) {
            let entry = ScratchFile(
                name: language.entryFileName, contents: language.starterContents)
            try? write(entry, language: language)
            files.append(entry)
        }
        return files.sorted { lhs, rhs in
            if lhs.name == language.entryFileName { return true }
            if rhs.name == language.entryFileName { return false }
            return lhs.name < rhs.name
        }
    }

    /// 파일 하나를 쓴다. 디렉터리는 없으면 만든다.
    ///
    /// **실패를 삼키지 않는다** — 저장이 안 되는데 화면이 저장된 것처럼 보이면 학습자가
    /// 쓴 것을 잃는다. 호출자가 그 사실을 화면에 남길 수 있어야 한다.
    public func write(_ file: ScratchFile, language: ScratchLanguage) throws {
        let directory = self.directory(for: language)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        try Data(file.contents.utf8).write(
            to: directory.appendingPathComponent(file.name), options: .atomic)
    }

    public func delete(_ name: String, language: ScratchLanguage) throws {
        let url = directory(for: language).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// 이름이 파일 하나를 가리키는지. 경로 구분자와 상위 참조를 막는다 —
    /// 학습자가 `../../x` 를 적어도 연습장 밖으로 나가지 않는다.
    public static func isValidFileName(_ name: String, language: ScratchLanguage) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return false }
        guard !trimmed.hasPrefix(".") else { return false }
        guard !trimmed.contains("/"), !trimmed.contains("\\"), trimmed != "..", trimmed != "."
        else { return false }
        // 확장자는 그 언어의 것이거나, C++ 의 헤더처럼 함께 쓰는 것이어야 한다.
        let allowed = allowedExtensions(for: language)
        return allowed.contains { trimmed.hasSuffix(".\($0)") }
    }

    static func allowedExtensions(for language: ScratchLanguage) -> [String] {
        switch language {
        case .cpp: ["cpp", "cc", "cxx", "h", "hpp"]
        default: [language.fileExtension]
        }
    }
}
