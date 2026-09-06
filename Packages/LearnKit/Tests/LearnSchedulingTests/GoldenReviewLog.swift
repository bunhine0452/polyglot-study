import Foundation

import LearnCore
@testable import LearnScheduling

/// 체크인된 200건 골든 로그를 만드는 생성기. `{#card-state-rebuild}`
///
/// 픽스처는 저장소에 커밋돼 있고 평소에는 **읽기만** 한다. 이 생성기는 두 가지 용도다.
/// - 픽스처가 손으로 편집되지 않았음을 증명한다(재생성 결과가 바이트 일치해야 한다).
/// - 스케줄러를 의도적으로 바꿨을 때 픽스처를 갱신한다.
///
/// 갱신은 명시적으로만:
/// ```
/// LEARNKIT_REGENERATE_GOLDEN=1 swift test --filter Golden
/// ```
enum GoldenReviewLog {
    static let logFileName = "golden-review-log.jsonl"
    static let stateFileName = "golden-card-state.json"

    /// 2026-01-05 09:00:00 UTC.
    static let base = EpochMillis(1_767_603_600_000)
    static let cardCount = 40
    static let reviewsPerCard = 5

    /// xorshift64*. 시드 고정 — 같은 픽스처가 어느 기계에서도 재현된다.
    /// `SystemRandomNumberGenerator` 나 `Hasher` 는 쓸 수 없다(프로세스마다 다르다).
    struct SeededRandom {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 0x2545_F491_4F6C_DD1D
        }

        mutating func next(upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }

        mutating func shuffled<T>(_ items: [T]) -> [T] {
            var items = items
            guard items.count > 1 else { return items }
            for index in stride(from: items.count - 1, to: 0, by: -1) {
                items.swapAt(index, next(upperBound: index + 1))
            }
            return items
        }
    }

    /// 실제 스케줄러를 돌려 만든 현실적인 이력.
    ///
    /// 리뷰 시각은 카드의 `dueAt` 에 결정적 지터를 얹어 정한다 — 사람이 정확히 due 시각에
    /// 풀지는 않으니까. 13번째마다 `.cram` 을 끼워 "기록되지만 스케줄을 바꾸지 않는" 경로도
    /// 로그에 실린다.
    static func generate() throws -> [ReviewLogEntry] {
        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(base))
        var random = SeededRandom(seed: 0x5EED_1DEA_C0FF_EE01)
        var generated: [ReviewLogEntry] = []

        // rating 분포: good 위주에 hard/easy/again 을 섞는다.
        let ratingPool: [ReviewRating] = [
            .good, .good, .good, .good, .good, .good,
            .hard, .hard, .easy, .easy, .again, .again,
        ]

        var cramCounter = 0
        for index in 0..<cardCount {
            let cardID = CardID(String(format: "card-%02d", index))
            var state = scheduler.initialState(for: cardID, createdAt: base)
            var now = base.adding(minutes: index * 17)

            for _ in 0..<reviewsPerCard {
                let rating = ratingPool[random.next(upperBound: ratingPool.count)]
                cramCounter += 1
                let source: ReviewLogSource = cramCounter % 13 == 0 ? .cram : .review

                let outcome = try scheduler.apply(
                    rating,
                    to: state,
                    at: now,
                    reviewDurationMS: 1_500 + random.next(upperBound: 9_000),
                    source: source
                )
                generated.append(outcome.logEntry)
                state = outcome.state

                // 다음 리뷰는 due 시각 + 0~179분 지터. cram 이었다면 due 는 그대로다.
                now = state.dueAt.adding(minutes: random.next(upperBound: 180))
            }
        }

        // DB 삽입 순서 = 시간 순서. 그 순서대로 logID 1...N 을 붙인다.
        let timeOrdered = generated
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.reviewedAt != rhs.element.reviewedAt {
                    return lhs.element.reviewedAt < rhs.element.reviewedAt
                }
                if lhs.element.cardID.rawValue != rhs.element.cardID.rawValue {
                    return lhs.element.cardID.rawValue < rhs.element.cardID.rawValue
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        var withIDs: [ReviewLogEntry] = []
        withIDs.reserveCapacity(timeOrdered.count)
        for (offset, entry) in timeOrdered.enumerated() {
            var entry = entry
            entry.logID = Int64(offset + 1)
            withIDs.append(entry)
        }

        // 파일에는 일부러 뒤섞어 저장한다 — 리플레이가 스스로 정렬하지 않으면 즉시 깨진다.
        var shuffleRandom = SeededRandom(seed: 0xB0A7_5EED_1234_5678)
        return shuffleRandom.shuffled(withIDs)
    }

    // MARK: - 직렬화

    static func encodeJSONL(_ entries: [ReviewLogEntry]) throws -> Data {
        var out = Data()
        for entry in entries {
            out.append(try jsonlEncoder.encode(entry))
            out.append(0x0a)
        }
        return out
    }

    static func decodeJSONL(_ data: Data) throws -> [ReviewLogEntry] {
        let decoder = JSONDecoder()
        return try String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { try decoder.decode(ReviewLogEntry.self, from: Data($0.utf8)) }
    }

    static func loadEntries() throws -> [ReviewLogEntry] {
        try decodeJSONL(try Fixtures.data(logFileName))
    }

    static var shouldRegenerate: Bool {
        ProcessInfo.processInfo.environment["LEARNKIT_REGENERATE_GOLDEN"] != nil
    }

    /// 픽스처 두 개를 디스크에 쓴다. 회귀 테스트에서 호출하지 않는다.
    static func regenerate() throws {
        let entries = try generate()
        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(base))
        let rebuild = try scheduler.rebuild(entries)

        try FileManager.default.createDirectory(at: Fixtures.directory, withIntermediateDirectories: true)
        try encodeJSONL(entries).write(to: Fixtures.url(logFileName))
        var stateData = try snapshotEncoder.encode(rebuild)
        stateData.append(0x0a)
        try stateData.write(to: Fixtures.url(stateFileName))
    }
}
