internal import Foundation
internal import LearnCore

/// JSON 배열 컬럼(`completed_blocks`, `scheduler_parameters.weights`) 인코딩.
///
/// `JSONEncoder` 는 배열 원소 순서를 보존하고 공백을 넣지 않으므로 같은 입력이 항상 같은 바이트를 낸다.
/// 그 결정성이 필요하다 — 진도 행을 비교할 때 `"[0,1]"` 과 `"[0, 1]"` 이 다르면 안 된다.
enum JSONArray {
    static func encode(_ values: [Int]) throws -> String {
        try encodeCodable(values)
    }

    static func encode(_ values: [Double]) throws -> String {
        try encodeCodable(values)
    }

    static func decodeInts(_ json: String) throws -> [Int] {
        try decodeCodable(json, as: [Int].self)
    }

    static func decodeDoubles(_ json: String) throws -> [Double] {
        try decodeCodable(json, as: [Double].self)
    }

    private static func encodeCodable(_ value: some Encodable) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw StoreError.storage(message: "JSON 인코딩 결과가 UTF-8 이 아니다")
        }
        return text
    }

    private static func decodeCodable<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw StoreError.storage(message: "JSON 컬럼이 UTF-8 이 아니다")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw StoreError.storage(message: "JSON 컬럼 디코딩 실패: \(json)")
        }
    }
}
