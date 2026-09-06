import Foundation
import Testing

@testable import LearnScheduling

/// 참조 벡터 비교용. 실패 메시지에 **어느 오라클과 어긋났는지**가 반드시 남아야 한다.
func expectOracle(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = 1e-7,
    oracle: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        abs(actual - expected) <= tolerance,
        "오라클 불일치 [\(oracle)] — 기대 \(expected), 실제 \(actual), 차이 \(abs(actual - expected)) (허용 \(tolerance))",
        sourceLocation: sourceLocation
    )
}

func expectOracle<T: Equatable>(
    _ actual: T,
    _ expected: T,
    oracle: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        actual == expected,
        "오라클 불일치 [\(oracle)] — 기대 \(expected), 실제 \(actual)",
        sourceLocation: sourceLocation
    )
}

/// 업스트림 테스트가 쓰던 UTC 그레고리력.
let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// 체크인된 픽스처 디렉터리.
///
/// `Package.swift` 에 `resources:` 를 선언하면 `Bundle.module` 을 쓸 수 있지만, 이 세션은
/// 매니페스트를 건드리지 않기로 되어 있다(다른 세션이 병렬로 편집 중). `#filePath` 기반
/// 탐색은 SPM 테스트에서 안정적으로 동작하고 번들 설정에 의존하지 않는다.
enum Fixtures {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    static func data(_ name: String) throws -> Data { try Data(contentsOf: url(name)) }

    static func text(_ name: String) throws -> String {
        String(decoding: try data(name), as: UTF8.self)
    }
}

/// 스냅샷 비교용 결정적 JSON 인코더 — 키 정렬 + 고정 들여쓰기.
let snapshotEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    return encoder
}()

/// 픽스처 직렬화용 — 한 줄 JSONL.
let jsonlEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}()
