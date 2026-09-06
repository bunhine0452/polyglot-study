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

/// 체크인된 픽스처.
///
/// **읽기는 `Bundle.module`** 로 한다 — `Package.swift` 가 `resources: [.copy("Fixtures")]`
/// 로 선언하므로 번들 안에 `Fixtures/` 가 그대로 복사된다. 선언 없이 `#filePath` 로 읽으면
/// SPM 이 "unhandled file" 경고를 낸다.
///
/// **쓰기는 소스 트리**로 한다. 번들은 빌드 산출물이라 거기 쓰면 `git diff` 에 아무것도
/// 안 나오고 픽스처 갱신이 조용히 증발한다. 갱신은 `GoldenReviewLog.regenerate()` 하나뿐이다.
enum Fixtures {
    static var directory: URL {
        guard let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            fatalError("번들에 Fixtures/ 가 없다 — Package.swift 의 resources 선언을 확인해라")
        }
        return url
    }

    /// 재생성 전용 — 체크인된 원본이 있는 곳.
    static var sourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    static func sourceURL(_ name: String) -> URL { sourceDirectory.appendingPathComponent(name) }

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
