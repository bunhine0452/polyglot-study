public import LearnCore

/// 콘텐츠 팩 매니페스트 스키마 v1.
///
/// 이 타입은 **와이어 포맷 그대로**다. 버전·경로가 `String` 인 것은 의도한 것이다 —
/// 잘못된 semver 나 탈출 경로가 `Decodable` 단계에서 `DecodingError` 로 터지면
/// "매니페스트가 왜 거부됐는지"가 Foundation 의 문자열 안으로 사라진다. 디코딩은
/// **모양만** 보고, 내용은 전부 ``validate()`` 가 본다. 그래야 깨진 매니페스트마다
/// 서로 다른 ``PackManifestError`` 가 나온다.
public struct PackManifest: Hashable, Sendable, Codable {
    /// 이 앱이 이해하는 스키마 버전. 팩이 이보다 크면 거부한다.
    public static let currentSchemaVersion = 1

    public struct LessonEntry: Hashable, Sendable, Codable {
        /// 콘텐츠가 갱신돼도 절대 바뀌지 않는 식별자. 진도가 `(PackID, LessonID)` 로
        /// 매달려 있으므로 여기가 흔들리면 학습 기록이 고아가 된다.
        public var stableID: LessonID
        /// 이 레슨을 풀 수 있는 언어들 — **선언 순서 그대로**, 비어 있지 않다.
        ///
        /// 알고리즘처럼 한 레슨을 여러 언어로 풀 수 있는 트랙 때문에 복수다
        /// ({#manifest-languages-plural}). 언어가 하나인 레슨은 원소 하나짜리 배열이고,
        /// v1 매니페스트의 `"language"` 단수 표기도 그대로 읽는다.
        public var languages: [LanguageID]
        public var title: String
        /// 트랙 안에서의 표시 순서. 언어별로 1부터.
        public var order: Int
        /// `lessons/<...>.md`.
        public var path: String
        public var objectives: [String]
        public var prerequisites: [LessonID]

        /// 목록의 첫 언어. 트랙 이름·복습 큐처럼 **하나만 필요한** 자리가 쓴다.
        public var primaryLanguage: LanguageID { languages[0] }

        public init(
            stableID: LessonID,
            languages: [LanguageID],
            title: String,
            order: Int,
            path: String,
            objectives: [String] = [],
            prerequisites: [LessonID] = []
        ) {
            self.stableID = stableID
            self.languages = languages
            self.title = title
            self.order = order
            self.path = path
            self.objectives = objectives
            self.prerequisites = prerequisites
        }

        // MARK: Codable
        //
        // 손으로 쓰는 이유는 **v1 매니페스트의 바이트를 지키기 위해서**다.
        //
        // 읽기: `"language": "rust"` 단수와 `"languages": [...]` 복수를 모두 받는다.
        // 리포의 팩 5종이 단수로 쓰여 있다.
        //
        // 쓰기: **언어가 하나면 단수로, 여럿이면 복수로** 쓴다. 항상 복수로 통일하고
        // 싶었지만 그러면 기존 팩을 다시 구울 때 바이트가 달라진다 — `packtool sign` 이
        // **정규 매니페스트 바이트에 서명**하므로 그 순간 기존 서명이 전부 무효가 되고,
        // "다시 구우면 바이트가 같다" 는 보장도 깨진다. 복수 표기는 단수로 적을 수 없는
        // 경우(여러 언어)에만 나타난다 — 표기가 둘인 것이 아니라 **복수가 단수의 확장**이다.
        private enum CodingKeys: String, CodingKey {
            case stableID, language, languages, title, order, path, objectives, prerequisites
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            stableID = try container.decode(LessonID.self, forKey: .stableID)
            if let plural = try container.decodeIfPresent([LanguageID].self, forKey: .languages) {
                languages = plural
            } else {
                // 단수 표기. 없으면 둘 다 없는 것이라 그대로 디코딩 실패다.
                languages = [try container.decode(LanguageID.self, forKey: .language)]
            }
            title = try container.decode(String.self, forKey: .title)
            order = try container.decode(Int.self, forKey: .order)
            path = try container.decode(String.self, forKey: .path)
            objectives = try container.decodeIfPresent([String].self, forKey: .objectives) ?? []
            prerequisites =
                try container.decodeIfPresent([LessonID].self, forKey: .prerequisites) ?? []
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(stableID, forKey: .stableID)
            if languages.count == 1 {
                try container.encode(languages[0], forKey: .language)
            } else {
                try container.encode(languages, forKey: .languages)
            }
            try container.encode(title, forKey: .title)
            try container.encode(order, forKey: .order)
            try container.encode(path, forKey: .path)
            try container.encode(objectives, forKey: .objectives)
            try container.encode(prerequisites, forKey: .prerequisites)
        }
    }

    public struct FileEntry: Hashable, Sendable, Codable {
        public var path: String
        /// 소문자 hex 64자.
        public var sha256: String
        public var bytes: Int

        public init(path: String, sha256: String, bytes: Int) {
            self.path = path
            self.sha256 = sha256
            self.bytes = bytes
        }
    }

    public var schemaVersion: Int
    public var packID: PackID
    public var displayName: String
    /// 팩 자체의 버전 (semver 문자열).
    public var version: String
    /// 이 팩을 열 수 있는 최소 앱 버전 (semver 문자열).
    public var minAppVersion: String
    /// `2026-09-06T12:34:56Z`. **git commit date 에서 온다** — 빌드 시각이 아니다.
    /// 시각을 빌드에서 읽으면 같은 소스가 매번 다른 바이트를 굽는다.
    public var generatedAt: String
    public var languages: [LanguageID]
    public var lessons: [LessonEntry]
    /// `manifest.json` 자신을 제외한 팩의 **모든** 파일. 설치기가 이 목록과 디스크를
    /// 양방향으로 대조하므로, 목록에 없는 파일이 디스크에 있어도 거부된다.
    public var files: [FileEntry]
    /// 배포 팩인가. `packtool build` 가 `solutions/` 를 벗기면서 `true` 로 굽는다.
    ///
    /// **원본 팩에는 이 키가 아예 없다** — `nil` 은 인코딩되지 않으므로 이미 구워진
    /// 팩들의 정규 바이트가 이 필드 때문에 바뀌지 않는다.
    ///
    /// 플래그가 아니라 매니페스트에 두는 이유는 서명 때문이다. 서명이 정규 매니페스트
    /// 바이트에 걸리므로 "이 팩은 solutions 가 없는 것이 정상" 이라는 사실도 함께
    /// 서명된다. `--distribution` 같은 명령행 플래그였다면 검증기를 부르는 쪽이
    /// 게이트를 끌 수 있었을 것이다.
    public var distribution: Bool?

    public init(
        schemaVersion: Int = PackManifest.currentSchemaVersion,
        packID: PackID,
        displayName: String,
        version: String,
        minAppVersion: String,
        generatedAt: String,
        languages: [LanguageID],
        lessons: [LessonEntry],
        files: [FileEntry],
        distribution: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.packID = packID
        self.displayName = displayName
        self.version = version
        self.minAppVersion = minAppVersion
        self.generatedAt = generatedAt
        self.languages = languages
        self.lessons = lessons
        self.files = files
        self.distribution = distribution
    }

    // MARK: - 파생

    /// `solutions/` 가 벗겨진 배포 팩인가.
    public var isDistribution: Bool { distribution == true }

    public var parsedVersion: SemanticVersion? { try? SemanticVersion(parsing: version) }
    public var parsedMinAppVersion: SemanticVersion? { try? SemanticVersion(parsing: minAppVersion) }

    public func lesson(_ id: LessonID) -> LessonEntry? {
        lessons.first { $0.stableID == id }
    }

    /// 이 언어로 풀 수 있는 레슨을 `order` 순으로.
    ///
    /// 여러 언어를 담은 레슨은 그 **모든 언어에서** 잡힌다 — 알고리즘 레슨은 Rust 목록에도
    /// Python 목록에도 나와야 한다.
    public func lessons(for language: LanguageID) -> [LessonEntry] {
        lessons.filter { $0.languages.contains(language) }.sorted { $0.order < $1.order }
    }

    /// 검증을 통과한 매니페스트의 파일 색인. ``validate()`` 뒤에만 부른다.
    public func fileIndex() -> [String: FileEntry] {
        Dictionary(files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
