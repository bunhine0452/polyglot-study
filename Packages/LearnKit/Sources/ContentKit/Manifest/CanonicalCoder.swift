internal import Foundation

/// ``CanonicalJSON`` 의 구현. Foundation 을 `internal import` 로만 쓰기 위해 파일을 갈랐다 —
/// 한 파일 안에서 같은 모듈을 public 과 internal 로 함께 임포트하면 접근 수준이 뭉개진다.
enum CanonicalCoder {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        // `.prettyPrinted` 의 들여쓰기는 Foundation 기본이 2칸이다. 이 조합이 정규형이다.
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        if data.last != 0x0A { data.append(0x0A) }
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        func pad(_ value: Int?, _ width: Int) -> String {
            let text = String(value ?? 0)
            return text.count >= width
                ? text : String(repeating: "0", count: width - text.count) + text
        }
        return "\(pad(parts.year, 4))-\(pad(parts.month, 2))-\(pad(parts.day, 2))T"
            + "\(pad(parts.hour, 2)):\(pad(parts.minute, 2)):\(pad(parts.second, 2))Z"
    }
}
