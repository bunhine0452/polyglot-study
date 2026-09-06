public import LearnCore

/// `stableID` 불변 규칙을 파일로 물리화한 잠금.
///
/// 규칙을 문서에만 적어두면 지켜지지 않는다. 레슨을 다시 생성하는 도구는 id 를
/// 자유롭게 바꿀 수 있고, 그 순간 `(PackID, LessonID)` 로 매달린 학습 진도가 전부
/// 고아가 된다 — 그리고 아무도 모른다. 그래서 잠금 파일을 리포에 커밋하고,
/// 매니페스트를 구울 때마다 ``check(against:)`` 로 대조한다.
///
/// **추가만 허용한다.** 삭제·개명·재할당 세 가지가 각각 다른 에러다.
public struct StableIDLock: Hashable, Sendable {
    /// 잠금 파일 첫 줄. 포맷이 바뀌면 이 값이 바뀐다.
    public static let formatHeader = "# polyglot stableids v1"

    public struct Entry: Hashable, Sendable, Comparable {
        public var stableID: LessonID
        public var language: LanguageID
        /// 레슨 본문의 팩 상대 경로. **개명 탐지의 유일한 근거**다 — 경로가 같은데
        /// id 가 다르면 그건 새 레슨이 아니라 개명이다.
        public var path: String

        public init(stableID: LessonID, language: LanguageID, path: String) {
            self.stableID = stableID
            self.language = language
            self.path = path
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.stableID.rawValue < rhs.stableID.rawValue
        }

        /// 에러 메시지에 쓰는 사람이 읽는 형태.
        public var descriptor: String { "\(language.rawValue) \(path)" }
    }

    /// stableID 사전순으로 정렬된 항목들.
    public private(set) var entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries.sorted()
    }

    public static let empty = StableIDLock(entries: [])

    // MARK: - 직렬화

    /// 잠금 파일의 정규 바이트. 정렬 + 탭 구분 + LF + 후행 개행.
    ///
    /// JSON 이 아닌 이유는 이 파일이 **사람이 읽는 diff** 이기 때문이다. 레슨 하나가
    /// 추가되면 한 줄이 추가돼야 하고, 그게 리뷰에서 보여야 한다.
    public func canonicalText() -> String {
        var lines = [StableIDLock.formatHeader]
        for entry in entries {
            lines.append("\(entry.stableID.rawValue)\t\(entry.language.rawValue)\t\(entry.path)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parse(_ text: String) throws(StableIDLockError) -> StableIDLock {
        var entries: [Entry] = []
        var seen: Set<String> = []
        var sawHeader = false

        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
        {
            let number = index + 1
            let line = String(rawLine)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                if !sawHeader {
                    guard line == StableIDLock.formatHeader else {
                        throw .unsupportedLockVersion(line)
                    }
                    sawHeader = true
                }
                continue
            }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty }) else {
                throw .malformedLine(number: number, raw: line)
            }
            let id = LessonID(String(fields[0]))
            guard seen.insert(id.rawValue).inserted else {
                throw .duplicateEntry(id, line: number)
            }
            entries.append(
                Entry(
                    stableID: id,
                    language: LanguageID(String(fields[1])),
                    path: String(fields[2])))
        }

        guard sawHeader else { throw .missingHeader }
        return StableIDLock(entries: entries)
    }

    // MARK: - 매니페스트와의 관계

    public static func from(manifest: PackManifest) -> StableIDLock {
        StableIDLock(
            entries: manifest.lessons.map {
                Entry(stableID: $0.stableID, language: $0.language, path: $0.path)
            })
    }

    /// 잠금이 허락하는 변화인가. 추가만 통과한다.
    ///
    /// 위반 3종:
    /// - ``StableIDLockError/removed(_:descriptor:)`` — 잠금에 있던 id 가 사라졌다.
    /// - ``StableIDLockError/renamed(from:to:path:)`` — 같은 파일의 id 가 바뀌었다.
    /// - ``StableIDLockError/reassigned(_:from:to:)`` — 같은 id 가 다른 레슨을 가리킨다.
    public func check(against manifest: PackManifest) throws(StableIDLockError) {
        try check(against: StableIDLock.from(manifest: manifest))
    }

    public func check(against next: StableIDLock) throws(StableIDLockError) {
        let nextByID = Dictionary(next.entries.map { ($0.stableID, $0) }, uniquingKeysWith: { a, _ in a })
        let nextByPath = Dictionary(next.entries.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })

        for locked in entries {
            guard let current = nextByID[locked.stableID] else {
                // id 가 사라졌다. 같은 경로를 다른 id 가 차지했으면 삭제가 아니라 개명이다.
                if let replacement = nextByPath[locked.path],
                    replacement.stableID != locked.stableID
                {
                    throw .renamed(
                        from: locked.stableID, to: replacement.stableID, path: locked.path)
                }
                throw .removed(locked.stableID, descriptor: locked.descriptor)
            }
            if current.path != locked.path || current.language != locked.language {
                throw .reassigned(
                    locked.stableID, from: locked.descriptor, to: current.descriptor)
            }
        }
    }

    /// 검사를 통과한 뒤의 새 잠금. 기존 항목은 그대로 두고 추가분만 얹는다.
    public func adding(_ next: StableIDLock) -> StableIDLock {
        var merged = Dictionary(entries.map { ($0.stableID, $0) }, uniquingKeysWith: { a, _ in a })
        for entry in next.entries where merged[entry.stableID] == nil {
            merged[entry.stableID] = entry
        }
        return StableIDLock(entries: Array(merged.values))
    }

    /// 이번 매니페스트에서 새로 생긴 id.
    public func additions(in next: StableIDLock) -> [Entry] {
        let known = Set(entries.map(\.stableID))
        return next.entries.filter { !known.contains($0.stableID) }.sorted()
    }
}

public enum StableIDLockError: Error, Hashable, Sendable, CustomStringConvertible {
    /// 잠금에 있던 레슨이 매니페스트에서 사라졌다.
    case removed(LessonID, descriptor: String)
    /// 같은 레슨 파일의 stableID 가 바뀌었다.
    case renamed(from: LessonID, to: LessonID, path: String)
    /// 같은 stableID 가 다른 파일·언어를 가리킨다 (id 재사용).
    case reassigned(LessonID, from: String, to: String)

    case missingHeader
    case unsupportedLockVersion(String)
    case malformedLine(number: Int, raw: String)
    case duplicateEntry(LessonID, line: Int)

    public var description: String {
        switch self {
        case .removed(let id, let descriptor):
            """
            stableID 삭제는 허용되지 않는다: \(id.rawValue) (\(descriptor))
            학습 진도가 이 id 로 매달려 있다. 레슨을 없애려면 팩에서 빼지 말고 \
            manifest 에 남긴 채 lessons 목록에서 감춰라.
            """
        case .renamed(let from, let to, let path):
            """
            stableID 개명은 허용되지 않는다: \(from.rawValue) → \(to.rawValue) (\(path))
            같은 파일의 id 를 바꾸면 그 레슨의 진도·복습 카드가 전부 고아가 된다. \
            원래 id \(from.rawValue) 를 되돌려라.
            """
        case .reassigned(let id, let from, let to):
            """
            stableID 재사용은 허용되지 않는다: \(id.rawValue) 가 \(from) 에서 \(to) 로 옮겨갔다
            같은 id 가 다른 레슨을 가리키면 기존 진도가 엉뚱한 레슨에 붙는다. \
            새 레슨에는 새 id 를 줘라.
            """
        case .missingHeader:
            "잠금 파일에 `\(StableIDLock.formatHeader)` 헤더가 없다"
        case .unsupportedLockVersion(let raw):
            "지원하지 않는 잠금 파일 버전이다: \(raw)"
        case .malformedLine(let number, let raw):
            "잠금 파일 \(number)행이 `stableID\\tlanguage\\tpath` 세 필드가 아니다: \(raw)"
        case .duplicateEntry(let id, let line):
            "잠금 파일 \(line)행에 \(id.rawValue) 가 중복으로 있다"
        }
    }
}
