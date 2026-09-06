/// semver 2.0.0 의 부분집합. `major.minor.patch` 와 선택적 프리릴리스만 받는다.
///
/// 빌드 메타데이터(`+sha`)를 뺀 이유는 비교에 참여하지 않는 필드가 정규 바이트에
/// 들어오면 "같은 버전인데 매니페스트 바이트가 다른" 상태가 생기기 때문이다.
public struct SemanticVersion: Hashable, Sendable, Comparable, Codable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// `-` 뒤의 점으로 나뉜 식별자들. 릴리스 버전은 빈 배열.
    public let prerelease: [String]

    public init(major: Int, minor: Int, patch: Int, prerelease: [String] = []) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public init(parsing raw: String) throws(SemanticVersionError) {
        var core = Substring(raw)
        var prerelease: [String] = []

        if let dash = core.firstIndex(of: "-") {
            let tail = core[core.index(after: dash)...]
            core = core[core.startIndex..<dash]
            if tail.isEmpty { throw SemanticVersionError.emptyPrerelease(raw) }
            for piece in tail.split(separator: ".", omittingEmptySubsequences: false) {
                if piece.isEmpty { throw SemanticVersionError.emptyPrerelease(raw) }
                let allowed = piece.allSatisfy {
                    $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
                }
                if !allowed { throw SemanticVersionError.malformed(raw) }
                prerelease.append(String(piece))
            }
        }

        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw SemanticVersionError.wrongComponentCount(raw, parts.count) }

        var numbers: [Int] = []
        for part in parts {
            guard let value = SemanticVersion.parseNumeric(part) else {
                throw SemanticVersionError.malformed(raw)
            }
            numbers.append(value)
        }

        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2], prerelease: prerelease)
    }

    /// 선행 0 을 거부한다. `01.0.0` 을 받아주면 같은 버전을 두 문자열로 쓸 수 있게 되고
    /// 정규 바이트 규칙이 깨진다.
    private static func parseNumeric(_ text: Substring) -> Int? {
        if text.isEmpty { return nil }
        if text.count > 1 && text.first == "0" { return nil }
        if !text.allSatisfy({ $0.isASCII && $0.isNumber }) { return nil }
        return Int(text)
    }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = try SemanticVersion(parsing: raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // 프리릴리스는 같은 코어의 릴리스보다 항상 앞선다.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true): return false
        case (true, false): return false
        case (false, true): return true
        case (false, false): break
        }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) {
            if left == right { continue }
            let leftNumeric = Int(left)
            let rightNumeric = Int(right)
            switch (leftNumeric, rightNumeric) {
            case (let l?, let r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return left < right
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

public enum SemanticVersionError: Error, Hashable, Sendable, CustomStringConvertible {
    case wrongComponentCount(String, Int)
    case malformed(String)
    case emptyPrerelease(String)

    public var description: String {
        switch self {
        case .wrongComponentCount(let raw, let count):
            "semver 는 major.minor.patch 세 조각이어야 한다 (\(count)개): \(raw)"
        case .malformed(let raw):
            "semver 형식이 아니다 (선행 0 과 비숫자 금지): \(raw)"
        case .emptyPrerelease(let raw):
            "빈 프리릴리스 식별자: \(raw)"
        }
    }
}
