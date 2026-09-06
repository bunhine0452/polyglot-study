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
        public var language: LanguageID
        public var title: String
        /// 트랙 안에서의 표시 순서. 언어별로 1부터.
        public var order: Int
        /// `lessons/<...>.md`.
        public var path: String
        public var objectives: [String]
        public var prerequisites: [LessonID]

        public init(
            stableID: LessonID,
            language: LanguageID,
            title: String,
            order: Int,
            path: String,
            objectives: [String] = [],
            prerequisites: [LessonID] = []
        ) {
            self.stableID = stableID
            self.language = language
            self.title = title
            self.order = order
            self.path = path
            self.objectives = objectives
            self.prerequisites = prerequisites
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

    public init(
        schemaVersion: Int = PackManifest.currentSchemaVersion,
        packID: PackID,
        displayName: String,
        version: String,
        minAppVersion: String,
        generatedAt: String,
        languages: [LanguageID],
        lessons: [LessonEntry],
        files: [FileEntry]
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
    }

    // MARK: - 파생

    public var parsedVersion: SemanticVersion? { try? SemanticVersion(parsing: version) }
    public var parsedMinAppVersion: SemanticVersion? { try? SemanticVersion(parsing: minAppVersion) }

    public func lesson(_ id: LessonID) -> LessonEntry? {
        lessons.first { $0.stableID == id }
    }

    /// 언어별 레슨을 `order` 순으로.
    public func lessons(for language: LanguageID) -> [LessonEntry] {
        lessons.filter { $0.language == language }.sorted { $0.order < $1.order }
    }

    /// 검증을 통과한 매니페스트의 파일 색인. ``validate()`` 뒤에만 부른다.
    public func fileIndex() -> [String: FileEntry] {
        Dictionary(files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
