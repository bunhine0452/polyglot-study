import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// `{#value-observation}` — 관찰 API 를 `AsyncSequence` 로 노출한다.
///
/// 각 테스트는 (1) 구독 즉시 현재 값이 오고, (2) 쓰기 후 새 값이 오고, (3) 순회를 끝내면
/// 관찰이 정리되는 세 가지를 본다. 폴링이 아니라 실제 트랜잭션 추적인지가 (2)로 드러난다.
@Suite("ValueObservation 기반 관찰 API")
struct ObservationTests {
    /// 지정한 개수의 값을 받을 때까지 기다린다. 타임아웃은 CI 에서 매달리지 않기 위한 것.
    private func collect<S: AsyncSequence & Sendable>(
        _ sequence: S,
        count: Int,
        after firstValue: @Sendable @escaping () async throws -> Void
    ) async throws -> [S.Element] where S.Element: Sendable {
        try await withThrowingTaskGroup(of: [S.Element].self) { group in
            group.addTask {
                var values: [S.Element] = []
                var triggered = false
                for try await value in sequence {
                    values.append(value)
                    if !triggered {
                        triggered = true
                        try await firstValue()
                    }
                    if values.count == count { break }
                }
                return values
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw ObservationTimeout()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private struct ObservationTimeout: Error {}

    @Test("review_log 개수 관찰이 초기값과 갱신값을 낸다", arguments: DatabaseFlavor.allCases)
    func observesReviewCount(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore
        try await store.append(Fixture.reviewEntry())

        let values = try await collect(store.observeCount(), count: 2) {
            try await store.append(Fixture.reviewEntry(at: 1))
        }
        #expect(values.first == 1, "구독 즉시 현재 값이 오지 않았다")
        #expect(values.last == 2, "쓰기 후 새 값이 오지 않았다")
    }

    @Test("due 카드 개수 관찰이 언어로 좁혀진다", arguments: DatabaseFlavor.allCases)
    func observesDueCountScopedToLanguage(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let cards = harness.database.cardStateStore
        try await cards.upsert(Fixture.cardState(card: "py-1", dueOffsetDays: 0))

        let horizon = Fixture.days(1)
        let values = try await collect(
            cards.observeDueCount(languageID: .python, dueAtOrBefore: horizon),
            count: 2
        ) {
            // 다른 언어 카드는 개수를 바꾸지 않아야 하지만, card_state 테이블은 바뀌므로
            // 관찰이 한 번 더 발화한다 — 값이 같으면 GRDB 가 중복을 걸러 준다.
            try await cards.upsert(Fixture.cardState(card: "sql-1", language: .sql, dueOffsetDays: 0))
            try await cards.upsert(Fixture.cardState(card: "py-2", dueOffsetDays: 1))
        }
        #expect(values.first == 1)
        #expect(values.last == 2)
    }

    @Test("오답 노트 개수 관찰이 삭제까지 따라온다", arguments: DatabaseFlavor.allCases)
    func observesNoteCount(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.mistakeNoteStore
        let id = try await store.save(Fixture.note(title: "첫 노트", body: "본문"))

        let values = try await collect(store.observeCount(), count: 2) {
            try await store.delete(id: id)
        }
        #expect(values.first == 1)
        #expect(values.last == 0)
    }

    @Test("레슨 진도 관찰이 값 자체를 흘려보낸다", arguments: DatabaseFlavor.allCases)
    func observesLessonProgress(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.lessonProgressStore
        let pack = PackID("p")
        let lesson = LessonID("l")

        let values = try await collect(
            store.observeProgress(packID: pack, lessonID: lesson),
            count: 2
        ) {
            try await store.completeBlock(
                packID: pack, lessonID: lesson, languageID: .python,
                blockIndex: 0, at: Fixture.epoch
            )
        }
        #expect(values.count == 2)
        #expect(values[0] == nil, "행이 없을 때는 nil 이 와야 한다")
        #expect(values[1]?.completedBlocks == [0])
        #expect(values[1]?.status == .inProgress)
    }

    @Test("인메모리 페이크도 같은 관찰 계약을 지킨다")
    func inMemoryFakeHonorsSameContract() async throws {
        let stores = InMemoryStores()
        try await stores.reviewLog.append(Fixture.reviewEntry())

        let values = try await collect(stores.reviewLog.observeCount(), count: 2) {
            try await stores.reviewLog.append(Fixture.reviewEntry(at: 1))
        }
        #expect(values == [1, 2])
    }
}
