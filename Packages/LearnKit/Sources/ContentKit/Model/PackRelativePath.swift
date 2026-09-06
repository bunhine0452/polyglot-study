/// 팩 루트 기준 상대 경로. **검증을 통과한 것만 존재한다.**
///
/// 팩은 신뢰할 수 없는 입력이다(생성기가 만들고 네트워크로 배포된다). 경로를 문자열로
/// 들고 다니면 `..` 탈출과 절대경로가 설치 시점까지 살아남고, 그때는 이미 스테이징
/// 디렉터리 밖에 파일이 하나 떨어진 뒤다. 그래서 경로는 **매니페스트 검증 단계에서**
/// 이 타입으로 좁히고, 설치기는 좁혀진 것만 받는다.
public struct PackRelativePath: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    /// 정규화된 POSIX 상대 경로. 선행 `./` 없음, 중복 슬래시 없음, 후행 슬래시 없음.
    public let rawValue: String

    private init(unchecked: String) { self.rawValue = unchecked }

    public init(validating raw: String) throws(PackPathError) {
        self.rawValue = try PackRelativePath.normalize(raw)
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = try PackRelativePath(validating: raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// `/` 로 자른 경로 조각. 항상 1개 이상이고 빈 조각은 없다.
    public var segments: [String] { rawValue.split(separator: "/").map(String.init) }

    /// 최상위 디렉터리 이름. 조각이 하나뿐이면(루트 파일) nil.
    public var topLevelDirectory: String? {
        let parts = segments
        return parts.count > 1 ? parts[0] : nil
    }

    public var lastComponent: String { segments.last ?? rawValue }

    /// 확장자를 뺀 파일 이름.
    public var stem: String {
        let name = lastComponent
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[name.startIndex..<dot])
    }

    // MARK: - 검증

    /// 경로 조각에 허용되는 문자. 공백과 유니코드를 일부러 뺐다 — 팩은 기계가 만들고
    /// 여러 파일시스템·아카이브 포맷을 통과하므로 이식성 없는 이름을 애초에 못 만들게 한다.
    private static func isAllowed(_ character: Character) -> Bool {
        character.isASCII
            && (character.isLetter || character.isNumber || character == "." || character == "-"
                || character == "_")
    }

    private static func normalize(_ raw: String) throws(PackPathError) -> String {
        if raw.isEmpty { throw PackPathError.empty }
        if raw.contains("\\") { throw PackPathError.backslash(raw) }
        if raw.hasPrefix("/") { throw PackPathError.absolute(raw) }
        // `~` 확장은 셸이 하는 일이지만, 매니페스트 값을 그대로 셸에 넘기는 도구가
        // 나중에 붙을 수 있으므로 여기서 미리 막는다.
        if raw.hasPrefix("~") { throw PackPathError.absolute(raw) }
        if raw.contains("\0") { throw PackPathError.illegalCharacter(raw, "\0") }

        var normalized: [String] = []
        for piece in raw.split(separator: "/", omittingEmptySubsequences: true) {
            let segment = String(piece)
            if segment == "." { continue }
            if segment == ".." { throw PackPathError.parentEscape(raw) }
            if segment.hasPrefix(".") { throw PackPathError.hiddenSegment(raw, segment) }
            if let bad = segment.first(where: { !isAllowed($0) }) {
                throw PackPathError.illegalCharacter(raw, bad)
            }
            normalized.append(segment)
        }
        if normalized.isEmpty { throw PackPathError.empty }
        return normalized.joined(separator: "/")
    }

    /// 검증 없이 만든다. **이미 검증된 값에만** 쓴다 (정규화 결과의 재조립 등).
    static func trusted(_ raw: String) -> PackRelativePath { PackRelativePath(unchecked: raw) }
}

public enum PackPathError: Error, Hashable, Sendable, CustomStringConvertible {
    case empty
    /// `/foo` 또는 `~/foo`.
    case absolute(String)
    /// 조각 하나가 `..` 다. 정규화로 없애지 않는다 — 없애면 "탈출을 시도했다"는
    /// 사실 자체가 사라져서 로그에 남길 것이 없어진다.
    case parentEscape(String)
    /// 윈도우 구분자. 값에 그대로 남으면 파일 이름의 일부가 되어 조용히 다른 파일을 만든다.
    case backslash(String)
    /// `.git` `.DS_Store` 같은 숨김 조각.
    case hiddenSegment(String, String)
    case illegalCharacter(String, Character)

    public var description: String {
        switch self {
        case .empty:
            "빈 경로"
        case .absolute(let raw):
            "절대경로는 쓸 수 없다: \(raw)"
        case .parentEscape(let raw):
            "상위 디렉터리 탈출(`..`)은 쓸 수 없다: \(raw)"
        case .backslash(let raw):
            "역슬래시는 쓸 수 없다: \(raw)"
        case .hiddenSegment(let raw, let segment):
            "숨김 경로 조각 `\(segment)` 는 쓸 수 없다: \(raw)"
        case .illegalCharacter(let raw, let character):
            "경로에 쓸 수 없는 문자 `\(character)`: \(raw)"
        }
    }
}
