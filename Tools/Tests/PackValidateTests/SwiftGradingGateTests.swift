import Testing
import Foundation
@testable import PackValidate

@Suite("Swift 채점 상호 배제")
struct SwiftGradingGateTests {
    /// 문 안쪽이 겹치지 않는다는 것만 본다 — 실제 채점을 태우지 않고도 이 계약은 검증된다.
    ///
    /// 이 테스트가 있는 이유: 원래 한 과제의 solution·starter 채점을 `async let` 으로 동시에
    /// 태웠고, 둘이 같은 SwiftPM 템플릿을 공유해 **solution 채점이 starter 코드를 돌렸다.**
    /// 게이트는 "solution 이 테스트를 통과하지 못한다" 고 보고했지만 solution 에는 멀쩡한
    /// 구현이 들어 있었다. 겹침 자체를 막는 것이 유일한 해결이었다.
    @Test("문 안쪽은 절대 겹치지 않는다")
    func neverOverlaps() async {
        let gate = SwiftGradingGate()
        let tracker = OverlapTracker()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    await gate.exclusive {
                        await tracker.enter()
                        // 실제 채점처럼 안쪽에서 await 한다 — 액터 재진입이 일어나는 지점이다.
                        try? await Task.sleep(for: .milliseconds(2))
                        await tracker.leave()
                    }
                }
            }
        }

        #expect(await tracker.maximumConcurrent == 1, "동시 진입 최대치가 1이 아니다")
        #expect(await tracker.completed == 12)
    }

    @Test("안쪽이 던져도 문은 반납된다")
    func releasesOnThrow() async {
        struct Boom: Error {}
        let gate = SwiftGradingGate()

        await #expect(throws: Boom.self) {
            try await gate.exclusive { throw Boom() }
        }
        // 반납되지 않았다면 여기서 영영 멈춘다.
        let value = await gate.exclusive { 42 }
        #expect(value == 42)
    }
}

private actor OverlapTracker {
    private var current = 0
    private(set) var maximumConcurrent = 0
    private(set) var completed = 0

    func enter() {
        current += 1
        maximumConcurrent = max(maximumConcurrent, current)
    }

    func leave() {
        current -= 1
        completed += 1
    }
}
