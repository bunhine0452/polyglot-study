import Foundation
import LearnCore
import Testing

@testable import ContentKit

/// 검증을 통과하는 최소 매니페스트. 테스트는 여기서 한 군데씩만 망가뜨린다 —
/// 그래야 "이 에러가 이 결함 때문"이라는 대응이 흔들리지 않는다.
private func healthyManifest() -> PackManifest {
    PackManifest(
        packID: PackID("sample-pack"),
        displayName: "샘플",
        version: "1.0.0",
        minAppVersion: "0.1.0",
        generatedAt: "2026-09-06T00:00:00Z",
        languages: [.python],
        lessons: [
            PackManifest.LessonEntry(
                stableID: LessonID("py-0001-a"), languages: [.python], title: "첫 레슨", order: 1,
                path: "lessons/py-0001-a.md")
        ],
        files: [
            PackManifest.FileEntry(
                path: "lessons/py-0001-a.md", sha256: String(repeating: "a", count: 64), bytes: 10)
        ])
}

@Suite("PackManifest 검증 — 깨진 방식마다 다른 에러")
struct PackManifestValidationTests {
    @Test("건강한 매니페스트는 통과한다")
    func healthyPasses() throws {
        try healthyManifest().validate()
    }

    @Test("1. 중복 stableID")
    func duplicateLessonID() {
        var manifest = healthyManifest()
        manifest.lessons.append(manifest.lessons[0])
        #expect(error(manifest) == .duplicateLessonID(LessonID("py-0001-a")))
    }

    @Test("2. 미등록 파일")
    func unregisteredFile() {
        var manifest = healthyManifest()
        manifest.files = []
        #expect(
            error(manifest)
                == .unregisteredFile(path: "lessons/py-0001-a.md", referencedBy: LessonID("py-0001-a")))
    }

    @Test("3. 잘못된 semver")
    func invalidSemver() {
        var manifest = healthyManifest()
        manifest.version = "1.0"
        #expect(
            error(manifest)
                == .invalidVersion(
                    field: "version", raw: "1.0", reason: .wrongComponentCount("1.0", 2)))
    }

    @Test("3-b. minAppVersion 도 같은 에러의 다른 필드로 잡힌다")
    func invalidMinAppVersion() {
        var manifest = healthyManifest()
        manifest.minAppVersion = "0.01.0"
        #expect(
            error(manifest)
                == .invalidVersion(
                    field: "minAppVersion", raw: "0.01.0", reason: .malformed("0.01.0")))
    }

    @Test("4. 경로 탈출")
    func pathEscape() {
        var manifest = healthyManifest()
        manifest.files[0].path = "../../etc/passwd"
        #expect(
            error(manifest)
                == .unsafePath(
                    field: "files[].path", raw: "../../etc/passwd",
                    reason: .parentEscape("../../etc/passwd")))
    }

    @Test("5. 빈 lessons")
    func emptyLessons() {
        var manifest = healthyManifest()
        manifest.lessons = []
        #expect(error(manifest) == .emptyLessons)
    }

    @Test("6. 미지 언어")
    func unknownLanguage() {
        var manifest = healthyManifest()
        manifest.lessons[0].languages = [LanguageID("rust")]
        #expect(
            error(manifest) == .unknownLanguage(LanguageID("rust"), lesson: LessonID("py-0001-a")))
    }

    @Test("여섯 결함이 서로 다른 에러를 낸다")
    func sixDefectsAreDistinct() {
        var duplicate = healthyManifest()
        duplicate.lessons.append(duplicate.lessons[0])
        var unregistered = healthyManifest()
        unregistered.files = []
        var badVersion = healthyManifest()
        badVersion.version = "1.0"
        var escaped = healthyManifest()
        escaped.files[0].path = "../x.md"
        var empty = healthyManifest()
        empty.lessons = []
        var unknown = healthyManifest()
        unknown.lessons[0].languages = [LanguageID("rust")]

        let errors = [duplicate, unregistered, badVersion, escaped, empty, unknown]
            .compactMap { error($0) }
        #expect(errors.count == 6)
        #expect(Set(errors).count == 6)
        #expect(Set(errors.map(\.description)).count == 6)
    }

    // MARK: - 나머지 검증

    @Test("레이아웃 밖의 파일은 등록할 수 없다")
    func fileOutsideLayout() {
        var manifest = healthyManifest()
        manifest.files[0].path = "scripts/build.sh"
        #expect(error(manifest) == .fileOutsideLayout("scripts/build.sh"))
    }

    @Test("정규형이 아닌 타임스탬프는 거부된다", arguments: [
        "2026-09-06T00:00:00+09:00", "2026-09-06 00:00:00Z", "2026-09-06T00:00:00.000Z", "",
    ])
    func invalidTimestamp(_ raw: String) {
        var manifest = healthyManifest()
        manifest.generatedAt = raw
        #expect(error(manifest) == .invalidTimestamp(raw))
    }

    @Test("sha256 이 hex 64자가 아니면 거부된다")
    func invalidChecksum() {
        var manifest = healthyManifest()
        manifest.files[0].sha256 = "DEADBEEF"
        #expect(error(manifest) == .invalidChecksum(path: "lessons/py-0001-a.md", raw: "DEADBEEF"))
    }

    @Test("같은 트랙에 order 가 겹치면 거부된다")
    func duplicateOrder() {
        var manifest = healthyManifest()
        manifest.lessons.append(
            PackManifest.LessonEntry(
                stableID: LessonID("py-0002-b"), languages: [.python], title: "둘", order: 1,
                path: "lessons/py-0001-a.md"))
        #expect(error(manifest) == .duplicateOrder(language: .python, order: 1))
    }

    @Test("없는 선수 레슨은 거부된다")
    func unknownPrerequisite() {
        var manifest = healthyManifest()
        manifest.lessons[0].prerequisites = [LessonID("py-0000-x")]
        #expect(
            error(manifest)
                == .unknownPrerequisite(
                    lesson: LessonID("py-0001-a"), prerequisite: LessonID("py-0000-x")))
    }

    @Test("레슨 본문이 lessons/ 밖이면 거부된다")
    func lessonOutsideLessonsDirectory() {
        var manifest = healthyManifest()
        manifest.lessons[0].path = "assets/py-0001-a.md"
        manifest.files[0].path = "assets/py-0001-a.md"
        #expect(
            error(manifest)
                == .lessonPathOutsideLessonsDirectory(
                    lesson: LessonID("py-0001-a"), path: "assets/py-0001-a.md"))
    }

    private func error(_ manifest: PackManifest) -> PackManifestError? {
        do {
            try manifest.validate()
            return nil
        } catch {
            return error
        }
    }
}

@Suite("schemaVersion·minAppVersion 게이트")
struct SchemaVersionGateTests {
    @Test("앱보다 새 스키마는 거부되고 사용자 문구가 붙는다")
    func schemaTooNew() {
        var manifest = healthyManifest()
        manifest.schemaVersion = PackManifest.currentSchemaVersion + 1
        let error = gateError(manifest, app: SemanticVersion(major: 1, minor: 0, patch: 0))
        #expect(
            error
                == .schemaTooNew(
                    packSchema: manifest.schemaVersion,
                    supported: PackManifest.currentSchemaVersion,
                    packID: PackID("sample-pack")))
        #expect(error?.userMessage.contains("앱을 업데이트") == true)
        #expect(error?.userMessage.contains("sample-pack") == true)
    }

    @Test("앱보다 새 minAppVersion 은 거부되고 필요한 버전을 알려준다")
    func appTooOld() {
        var manifest = healthyManifest()
        manifest.minAppVersion = "2.0.0"
        let error = gateError(manifest, app: SemanticVersion(major: 1, minor: 9, patch: 9))
        #expect(
            error
                == .appTooOld(
                    required: SemanticVersion(major: 2, minor: 0, patch: 0),
                    current: SemanticVersion(major: 1, minor: 9, patch: 9),
                    packID: PackID("sample-pack")))
        #expect(error?.userMessage.contains("2.0.0") == true)
    }

    @Test("게이트를 통과하는 조합은 던지지 않는다")
    func compatiblePasses() throws {
        try healthyManifest().checkCompatibility(
            appVersion: SemanticVersion(major: 0, minor: 1, patch: 0))
    }

    @Test("게이트는 크래시하지 않고 에러로만 실패한다 — 깨진 semver 도 마찬가지")
    func brokenVersionDoesNotCrash() {
        var manifest = healthyManifest()
        manifest.minAppVersion = "not-a-version"
        let error = gateError(manifest, app: SemanticVersion(major: 1, minor: 0, patch: 0))
        switch error {
        case .appTooOld: break
        default: Issue.record("깨진 semver 가 게이트를 통과했다")
        }
    }

    private func gateError(_ manifest: PackManifest, app: SemanticVersion)
        -> PackCompatibilityError?
    {
        do {
            try manifest.checkCompatibility(appVersion: app)
            return nil
        } catch {
            return error
        }
    }
}

@Suite("정규 바이트")
struct CanonicalBytesTests {
    @Test("두 번 구운 매니페스트는 바이트가 같다")
    func bakingTwiceIsIdentical() throws {
        let manifest = healthyManifest()
        #expect(try CanonicalJSON.encode(manifest) == CanonicalJSON.encode(manifest))
    }

    @Test("키 순서가 뒤섞인 JSON 도 정규형으로 되돌아온다")
    func scrambledInputNormalizes() throws {
        let canonical = try CanonicalJSON.encode(healthyManifest())
        let scrambled = """
            {"version":"1.0.0","schemaVersion":1,"packID":"sample-pack",
             "displayName":"샘플","minAppVersion":"0.1.0",
             "generatedAt":"2026-09-06T00:00:00Z","languages":["python"],
             "files":[{"sha256":"\(String(repeating: "a", count: 64))","bytes":10,
                       "path":"lessons/py-0001-a.md"}],
             "lessons":[{"title":"첫 레슨","order":1,"path":"lessons/py-0001-a.md",
                         "stableID":"py-0001-a","language":"python",
                         "objectives":[],"prerequisites":[]}]}
            """
        let decoded = try CanonicalJSON.decode(PackManifest.self, from: Data(scrambled.utf8))
        #expect(try CanonicalJSON.encode(decoded) == canonical)
    }

    @Test("정규 바이트는 LF 로 끝나고 키가 사전순이다")
    func canonicalShape() throws {
        let text = try CanonicalJSON.string(healthyManifest())
        #expect(text.hasSuffix("\n"))
        #expect(!text.contains("\r"))
        let topLevelKeys =
            text
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmedWhitespace()
                guard trimmed.hasPrefix("\""), line.hasPrefix("  \"") else { return nil }
                return trimmed.split(separator: "\"").first.map(String.init)
            }
        #expect(topLevelKeys == topLevelKeys.sorted())
    }

    @Test("타임스탬프는 UTC 초 정밀도로만 정규화된다")
    func timestampCanonicalization() {
        let date = Date(timeIntervalSince1970: 1_788_000_123)
        let text = CanonicalJSON.canonicalTimestamp(date)
        #expect(CanonicalJSON.isCanonicalTimestamp(text))
        #expect(text.hasSuffix("Z"))
        #expect(text.count == 20)
        #expect(CanonicalJSON.canonicalTimestamp(date) == text)
    }

    @Test("RawRepresentable 식별자는 문자열 하나로 인코딩된다")
    func identifiersEncodeAsStrings() throws {
        let text = try CanonicalJSON.string(healthyManifest())
        #expect(text.contains("\"packID\" : \"sample-pack\""))
        // 언어가 하나인 레슨은 v1 단수 표기 그대로다({#manifest-languages-plural}).
        #expect(text.contains("\"language\" : \"python\""))
        // 이 테스트의 본론 — 래퍼가 `{"rawValue": "python"}` 로 풀리면 여기서 잡힌다.
        #expect(!text.contains("rawValue"))
    }
}

/// {#manifest-languages-plural} — 알고리즘 레슨은 여러 언어로 풀 수 있어야 하고, 그 사실이
/// 매니페스트에도 적혀 있어야 `lessons(for:)` 가 각 언어 목록에서 그 레슨을 찾는다.
@Suite("매니페스트 — 레슨의 언어 복수")
struct LessonEntryLanguagesTests {
    private func entry(_ json: String) throws -> PackManifest.LessonEntry {
        try JSONDecoder().decode(PackManifest.LessonEntry.self, from: Data(json.utf8))
    }

    @Test("v1 의 단수 표기를 그대로 읽는다 — 리포의 팩 5종이 그렇게 쓰여 있다")
    func singularSpellingStillDecodes() throws {
        let decoded = try entry(
            """
            {"stableID": "a", "language": "rust", "title": "t", "order": 1,
             "path": "lessons/a.md"}
            """)
        #expect(decoded.languages == [.rust])
        #expect(decoded.primaryLanguage == .rust)
    }

    @Test("복수 표기를 선언 순서 그대로 읽는다")
    func pluralSpellingKeepsOrder() throws {
        let decoded = try entry(
            """
            {"stableID": "a", "languages": ["rust", "python"], "title": "t", "order": 1,
             "path": "lessons/a.md"}
            """)
        #expect(decoded.languages == [.rust, .python])
        #expect(decoded.primaryLanguage == .rust)
    }

    @Test("둘 다 없으면 디코딩 실패 — 언어를 모르는 레슨은 열 수 없다")
    func missingBothSpellingsThrows() {
        #expect(throws: (any Error).self) {
            try entry("""
                {"stableID": "a", "title": "t", "order": 1, "path": "lessons/a.md"}
                """)
        }
    }

    /// `packtool sign` 이 **정규 매니페스트 바이트에 서명**한다 — 표기를 바꾸면 기존 팩의
    /// 서명이 전부 무효가 되고 "다시 구우면 바이트가 같다" 는 보장도 깨진다.
    @Test("언어가 하나면 v1 단수 표기로 되돌아 쓴다 — 기존 팩의 바이트를 지킨다")
    func singleLanguageRoundTripsToSingularSpelling() throws {
        let json = """
            {"stableID": "a", "language": "rust", "title": "t", "order": 1,
             "path": "lessons/a.md"}
            """
        let text = String(decoding: try JSONEncoder().encode(try entry(json)), as: UTF8.self)
        #expect(text.contains("\"language\":\"rust\"") || text.contains("\"language\" : \"rust\""))
        #expect(!text.contains("languages"))
    }

    @Test("언어가 여럿이면 복수 표기로 쓴다 — 단수로는 적을 수 없다")
    func multipleLanguagesEncodePlural() throws {
        let json = """
            {"stableID": "a", "languages": ["rust", "python"], "title": "t", "order": 1,
             "path": "lessons/a.md"}
            """
        let text = String(decoding: try JSONEncoder().encode(try entry(json)), as: UTF8.self)
        #expect(text.contains("languages"))
    }

    @Test("여러 언어 레슨은 그 모든 언어의 목록에 잡힌다")
    func multiLanguageLessonAppearsUnderEachLanguage() throws {
        var manifest = healthyManifest()
        manifest.languages = [.python, .rust]
        manifest.lessons[0].languages = [.python, .rust]

        #expect(manifest.lessons(for: .python).map(\.stableID) == [manifest.lessons[0].stableID])
        #expect(manifest.lessons(for: .rust).map(\.stableID) == [manifest.lessons[0].stableID])
    }
}
