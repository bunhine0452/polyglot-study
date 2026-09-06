public import LearnCore

/// 매니페스트가 거부되는 이유. **깨진 방식마다 케이스가 다르다** — 하나로 뭉치면
/// "매니페스트가 잘못됐습니다"만 남고, 팩을 고치는 사람은 어디를 고칠지 알 수 없다.
public enum PackManifestError: Error, Hashable, Sendable, CustomStringConvertible {
    /// 레슨이 하나도 없다.
    case emptyLessons
    /// 같은 `stableID` 가 두 번.
    case duplicateLessonID(LessonID)
    /// 같은 파일 경로가 `files` 에 두 번.
    case duplicateFilePath(String)
    /// 레슨이 가리키는 파일이 `files` 에 등록돼 있지 않다.
    case unregisteredFile(path: String, referencedBy: LessonID)
    /// `version` 또는 `minAppVersion` 이 semver 가 아니다.
    case invalidVersion(field: String, raw: String, reason: SemanticVersionError)
    /// 경로가 팩 밖을 가리킨다 (`..`, 절대경로, 역슬래시).
    case unsafePath(field: String, raw: String, reason: PackPathError)
    /// `lessons[].language` 가 `languages` 에 없다.
    case unknownLanguage(LanguageID, lesson: LessonID)

    case invalidSchemaVersion(Int)
    case emptyDisplayName
    case invalidPackID(String)
    case invalidStableID(String)
    case emptyLanguages
    case duplicateLanguage(LanguageID)
    case invalidTimestamp(String)
    case invalidChecksum(path: String, raw: String)
    case negativeFileSize(path: String, bytes: Int)
    /// 레이아웃 6종 디렉터리 밖의 파일이 `files` 에 등록됐다.
    case fileOutsideLayout(String)
    /// 같은 언어 안에서 `order` 가 겹친다.
    case duplicateOrder(language: LanguageID, order: Int)
    /// 선수 레슨이 이 팩에 없다.
    case unknownPrerequisite(lesson: LessonID, prerequisite: LessonID)
    /// 레슨 본문이 `lessons/` 밖에 있다.
    case lessonPathOutsideLessonsDirectory(lesson: LessonID, path: String)

    public var description: String {
        switch self {
        case .emptyLessons:
            "lessons 가 비어 있다 — 레슨이 없는 팩은 설치할 수 없다"
        case .duplicateLessonID(let id):
            "stableID 가 중복이다: \(id.rawValue)"
        case .duplicateFilePath(let path):
            "files 에 같은 경로가 두 번 등록됐다: \(path)"
        case .unregisteredFile(let path, let lesson):
            "레슨 \(lesson.rawValue) 이 참조하는 \(path) 가 files 에 등록돼 있지 않다"
        case .invalidVersion(let field, let raw, let reason):
            "\(field) 가 semver 가 아니다 (\(raw)): \(reason)"
        case .unsafePath(let field, let raw, let reason):
            "\(field) 의 경로가 안전하지 않다 (\(raw)): \(reason)"
        case .unknownLanguage(let language, let lesson):
            "레슨 \(lesson.rawValue) 의 언어 \(language.rawValue) 가 languages 에 없다"
        case .invalidSchemaVersion(let value):
            "schemaVersion 은 1 이상의 정수여야 한다: \(value)"
        case .emptyDisplayName:
            "displayName 이 비어 있다"
        case .invalidPackID(let raw):
            "packID 는 소문자·숫자·하이픈만 쓸 수 있다: \(raw)"
        case .invalidStableID(let raw):
            "stableID 는 소문자·숫자·하이픈만 쓸 수 있다: \(raw)"
        case .emptyLanguages:
            "languages 가 비어 있다"
        case .duplicateLanguage(let language):
            "languages 에 \(language.rawValue) 가 두 번 있다"
        case .invalidTimestamp(let raw):
            "generatedAt 은 2026-09-06T12:34:56Z 형태의 UTC 초 정밀도여야 한다: \(raw)"
        case .invalidChecksum(let path, let raw):
            "\(path) 의 sha256 이 소문자 hex 64자가 아니다: \(raw)"
        case .negativeFileSize(let path, let bytes):
            "\(path) 의 bytes 가 음수다: \(bytes)"
        case .fileOutsideLayout(let path):
            "팩 레이아웃 밖의 파일은 등록할 수 없다: \(path)"
        case .duplicateOrder(let language, let order):
            "\(language.rawValue) 트랙에 order \(order) 가 두 번 있다"
        case .unknownPrerequisite(let lesson, let prerequisite):
            "레슨 \(lesson.rawValue) 의 선수 레슨 \(prerequisite.rawValue) 가 이 팩에 없다"
        case .lessonPathOutsideLessonsDirectory(let lesson, let path):
            "레슨 \(lesson.rawValue) 의 본문은 lessons/ 아래에 있어야 한다: \(path)"
        }
    }
}

/// 팩이 이 앱보다 새로울 때. **거부하되 크래시하지 않는다** — 사용자에게 그대로
/// 보여줄 수 있는 문구를 에러가 직접 들고 있다.
public enum PackCompatibilityError: Error, Hashable, Sendable, CustomStringConvertible {
    case schemaTooNew(packSchema: Int, supported: Int, packID: PackID)
    case schemaTooOld(packSchema: Int, supported: Int, packID: PackID)
    case appTooOld(required: SemanticVersion, current: SemanticVersion, packID: PackID)

    /// UI 가 그대로 띄울 한국어 문구. 로그 문자열과 분리해 둔 이유는 둘의 수명이
    /// 다르기 때문이다 — 로그는 개발자용이고 이쪽은 번역·문구 검토 대상이다.
    public var userMessage: String {
        switch self {
        case .schemaTooNew(_, _, let packID):
            "‘\(packID.rawValue)’ 팩은 이 앱보다 새로운 형식입니다. 앱을 업데이트한 뒤 다시 시도하세요."
        case .schemaTooOld(_, _, let packID):
            "‘\(packID.rawValue)’ 팩은 더 이상 지원하지 않는 오래된 형식입니다. 새 팩을 내려받으세요."
        case .appTooOld(let required, _, let packID):
            "‘\(packID.rawValue)’ 팩에는 앱 \(required) 이상이 필요합니다. 앱을 업데이트한 뒤 다시 시도하세요."
        }
    }

    public var description: String {
        switch self {
        case .schemaTooNew(let packSchema, let supported, let packID):
            "\(packID.rawValue): schemaVersion \(packSchema) > 지원 \(supported)"
        case .schemaTooOld(let packSchema, let supported, let packID):
            "\(packID.rawValue): schemaVersion \(packSchema) < 지원 \(supported)"
        case .appTooOld(let required, let current, let packID):
            "\(packID.rawValue): minAppVersion \(required) > 현재 앱 \(current)"
        }
    }
}
