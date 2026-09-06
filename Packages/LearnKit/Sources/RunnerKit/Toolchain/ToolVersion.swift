/// 점으로 끊긴 숫자 버전. 도구마다 표기가 제각각이라 앞쪽 숫자열만 취한다.
///
/// `1.98.0 (88d9e12ae 2026-08-18)` → `[1, 98, 0]`,
/// `3.51.1 2025-11-28 ...` → `[3, 51, 1]`, `21.0.1+12-LTS` → `[21, 0, 1]`.
public struct ToolVersion: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let components: [Int]
    /// 파싱에 쓴 원문 조각. 사용자에게 보여줄 때는 이쪽을 쓴다.
    public let raw: String

    public init?(_ raw: String) {
        var components: [Int] = []
        var current = ""
        for character in raw {
            if character.isNumber {
                current.append(character)
            } else if character == "." && !current.isEmpty {
                guard let value = Int(current) else { break }
                components.append(value)
                current = ""
            } else {
                break
            }
        }
        if !current.isEmpty, let value = Int(current) {
            components.append(value)
        }
        guard !components.isEmpty else { return nil }
        self.components = components
        self.raw = raw
    }

    public init(components: [Int]) {
        self.components = components
        self.raw = components.map(String.init).joined(separator: ".")
    }

    public var description: String { raw }

    public static func < (lhs: ToolVersion, rhs: ToolVersion) -> Bool {
        let width = max(lhs.components.count, rhs.components.count)
        for index in 0..<width {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: ToolVersion, rhs: ToolVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        var normalized = components
        while let last = normalized.last, last == 0, normalized.count > 1 {
            normalized.removeLast()
        }
        hasher.combine(normalized)
    }
}
