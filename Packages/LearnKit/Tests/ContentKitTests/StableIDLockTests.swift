import Foundation
import LearnCore
import Testing

@testable import ContentKit

private func entry(_ id: String, _ language: LanguageID, _ path: String) -> StableIDLock.Entry {
    StableIDLock.Entry(stableID: LessonID(id), language: language, path: path)
}

@Suite("stableids.lock — 추가만 허용")
struct StableIDLockTests {
    private let base = StableIDLock(entries: [
        entry("py-0001-a", .python, "lessons/py-0001-a.md"),
        entry("py-0002-b", .python, "lessons/py-0002-b.md"),
    ])

    @Test("위반 1 — 삭제")
    func removalRejected() {
        let next = StableIDLock(entries: [entry("py-0001-a", .python, "lessons/py-0001-a.md")])
        let error = violation(base, next)
        #expect(error == .removed(LessonID("py-0002-b"), descriptor: "python lessons/py-0002-b.md"))
        #expect(error?.description.contains("stableID 삭제는 허용되지 않는다") == true)
        #expect(error?.description.contains("py-0002-b") == true)
    }

    @Test("위반 2 — 개명 (같은 파일, 다른 id)")
    func renameRejected() {
        let next = StableIDLock(entries: [
            entry("py-0001-a", .python, "lessons/py-0001-a.md"),
            entry("py-0002-renamed", .python, "lessons/py-0002-b.md"),
        ])
        let error = violation(base, next)
        #expect(
            error
                == .renamed(
                    from: LessonID("py-0002-b"), to: LessonID("py-0002-renamed"),
                    path: "lessons/py-0002-b.md"))
        #expect(error?.description.contains("stableID 개명은 허용되지 않는다") == true)
    }

    @Test("위반 3 — 재할당 (같은 id, 다른 레슨)")
    func reassignmentRejected() {
        let next = StableIDLock(entries: [
            entry("py-0001-a", .python, "lessons/py-0001-a.md"),
            entry("py-0002-b", .python, "lessons/py-0009-other.md"),
        ])
        let error = violation(base, next)
        #expect(
            error
                == .reassigned(
                    LessonID("py-0002-b"), from: "python lessons/py-0002-b.md",
                    to: "python lessons/py-0009-other.md"))
        #expect(error?.description.contains("stableID 재사용은 허용되지 않는다") == true)
    }

    @Test("세 위반은 서로 다른 메시지다")
    func threeViolationsAreDistinct() {
        let removed = violation(
            base, StableIDLock(entries: [entry("py-0001-a", .python, "lessons/py-0001-a.md")]))
        let renamed = violation(
            base,
            StableIDLock(entries: [
                entry("py-0001-a", .python, "lessons/py-0001-a.md"),
                entry("py-0002-c", .python, "lessons/py-0002-b.md"),
            ]))
        let reassigned = violation(
            base,
            StableIDLock(entries: [
                entry("py-0001-a", .python, "lessons/py-0001-a.md"),
                entry("py-0002-b", .python, "lessons/py-0003-x.md"),
            ]))
        let messages = [removed, renamed, reassigned].compactMap { $0?.description }
        #expect(messages.count == 3)
        #expect(Set(messages).count == 3)
    }

    @Test("언어만 바뀌어도 재할당으로 잡힌다")
    func languageChangeIsReassignment() {
        let next = StableIDLock(entries: [
            entry("py-0001-a", .python, "lessons/py-0001-a.md"),
            entry("py-0002-b", .swift, "lessons/py-0002-b.md"),
        ])
        switch violation(base, next) {
        case .reassigned: break
        default: Issue.record("언어 변경이 통과했다")
        }
    }

    @Test("추가는 통과한다")
    func additionAllowed() throws {
        let next = StableIDLock(entries: [
            entry("py-0001-a", .python, "lessons/py-0001-a.md"),
            entry("py-0002-b", .python, "lessons/py-0002-b.md"),
            entry("py-0003-c", .python, "lessons/py-0003-c.md"),
        ])
        try base.check(against: next)
        #expect(base.additions(in: next).map(\.stableID.rawValue) == ["py-0003-c"])
        #expect(base.adding(next).entries.count == 3)
    }

    // MARK: - 직렬화

    @Test("정규 텍스트는 정렬되고 LF 로 끝난다")
    func canonicalText() {
        let unsorted = StableIDLock(entries: [
            entry("z-last", .swift, "lessons/z.md"),
            entry("a-first", .python, "lessons/a.md"),
        ])
        let text = unsorted.canonicalText()
        #expect(text.hasPrefix(StableIDLock.formatHeader + "\n"))
        #expect(text.hasSuffix("\n"))
        let lines = text.split(separator: "\n").dropFirst().map(String.init)
        #expect(lines == ["a-first\tpython\tlessons/a.md", "z-last\tswift\tlessons/z.md"])
    }

    @Test("정규 텍스트는 왕복해도 같다")
    func roundTrips() throws {
        let text = base.canonicalText()
        #expect(try StableIDLock.parse(text).canonicalText() == text)
    }

    @Test("헤더가 없으면 거부된다")
    func headerRequired() {
        #expect(throws: StableIDLockError.missingHeader) {
            try StableIDLock.parse("py-0001-a\tpython\tlessons/a.md\n")
        }
    }

    @Test("필드가 셋이 아니면 거부된다")
    func malformedLine() {
        #expect(throws: StableIDLockError.malformedLine(number: 2, raw: "py-0001-a\tpython")) {
            try StableIDLock.parse(StableIDLock.formatHeader + "\npy-0001-a\tpython\n")
        }
    }

    @Test("같은 id 가 두 줄이면 거부된다")
    func duplicateEntry() {
        let text = """
            \(StableIDLock.formatHeader)
            py-0001-a\tpython\tlessons/a.md
            py-0001-a\tpython\tlessons/b.md
            """
        #expect(throws: StableIDLockError.duplicateEntry(LessonID("py-0001-a"), line: 3)) {
            try StableIDLock.parse(text)
        }
    }

    @Test("모르는 버전 헤더는 거부된다")
    func unsupportedVersion() {
        #expect(throws: StableIDLockError.unsupportedLockVersion("# polyglot stableids v2")) {
            try StableIDLock.parse("# polyglot stableids v2\n")
        }
    }

    private func violation(_ lock: StableIDLock, _ next: StableIDLock) -> StableIDLockError? {
        do {
            try lock.check(against: next)
            return nil
        } catch {
            return error
        }
    }
}

@Suite("semver 부분집합")
struct SemanticVersionTests {
    @Test("정상 파싱", arguments: ["0.0.0", "1.2.3", "10.20.30", "1.0.0-beta.1"])
    func parses(_ raw: String) throws {
        #expect(try SemanticVersion(parsing: raw).description == raw)
    }

    @Test("거부", arguments: ["1.0", "1.0.0.0", "01.0.0", "1.0.0-", "v1.0.0", "1.0.x", ""])
    func rejects(_ raw: String) {
        #expect(throws: SemanticVersionError.self) { try SemanticVersion(parsing: raw) }
    }

    @Test("프리릴리스는 같은 코어의 릴리스보다 앞선다")
    func prereleaseOrdering() throws {
        let beta = try SemanticVersion(parsing: "1.0.0-beta.1")
        let release = try SemanticVersion(parsing: "1.0.0")
        #expect(beta < release)
        #expect(try beta < SemanticVersion(parsing: "1.0.0-beta.2"))
        #expect(try SemanticVersion(parsing: "1.0.0-alpha") < beta)
    }

    @Test("코어 비교")
    func coreOrdering() throws {
        #expect(try SemanticVersion(parsing: "1.9.9") < SemanticVersion(parsing: "2.0.0"))
        #expect(try SemanticVersion(parsing: "1.2.3") < SemanticVersion(parsing: "1.3.0"))
    }
}

@Suite("팩 상대 경로")
struct PackRelativePathTests {
    @Test("정규화", arguments: [
        ("lessons/a.md", "lessons/a.md"),
        ("./lessons/a.md", "lessons/a.md"),
        ("lessons//a.md", "lessons/a.md"),
        ("lessons/a.md/", "lessons/a.md"),
    ])
    func normalizes(_ input: String, _ expected: String) throws {
        #expect(try PackRelativePath(validating: input).rawValue == expected)
    }

    @Test("거부", arguments: [
        ("", PackPathError.empty),
        ("/etc/passwd", PackPathError.absolute("/etc/passwd")),
        ("~/secrets", PackPathError.absolute("~/secrets")),
        ("../escape.md", PackPathError.parentEscape("../escape.md")),
        ("lessons/../../escape.md", PackPathError.parentEscape("lessons/../../escape.md")),
        ("lessons\\a.md", PackPathError.backslash("lessons\\a.md")),
        ("lessons/.hidden", PackPathError.hiddenSegment("lessons/.hidden", ".hidden")),
        ("lessons/a b.md", PackPathError.illegalCharacter("lessons/a b.md", " ")),
    ])
    func rejects(_ input: String, _ expected: PackPathError) {
        #expect(throws: expected) { try PackRelativePath(validating: input) }
    }

    @Test("최상위 디렉터리와 파일 이름")
    func components() throws {
        let path = try PackRelativePath(validating: "starters/py-0001-a.py")
        #expect(path.topLevelDirectory == "starters")
        #expect(path.lastComponent == "py-0001-a.py")
        #expect(path.stem == "py-0001-a")
    }

    @Test("루트 파일에는 최상위 디렉터리가 없다")
    func rootFile() throws {
        #expect(try PackRelativePath(validating: "stableids.lock").topLevelDirectory == nil)
    }

    @Test("레이아웃 6종 디렉터리와 루트 잠금 파일만 등록 가능하다")
    func registerable() throws {
        for directory in PackLayout.contentDirectories {
            #expect(PackLayout.isRegisterable(try PackRelativePath(validating: "\(directory)/x")))
        }
        #expect(PackLayout.isRegisterable(try PackRelativePath(validating: "stableids.lock")))
        #expect(!PackLayout.isRegisterable(try PackRelativePath(validating: "scripts/x.sh")))
        #expect(!PackLayout.isRegisterable(try PackRelativePath(validating: "README.md")))
    }
}
