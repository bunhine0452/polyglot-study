public import Foundation

/// 동시에 지나갈 수 있는 수를 `limit` 개로 묶는 문.
///
/// **액터로 감싸는 것만으로는 상호 배제가 되지 않는다.** 액터 메서드 안에서 `await` 하면
/// 재진입이 허용되므로, 명시적인 획득·반납이 필요하다. 이 저장소는 같은 함정을 네 번
/// 밟았고(예열한 SwiftPM 템플릿·SQL 시드·프로세스 그룹 기록), 그때마다 같은 모양의
/// 세마포어를 새로 적었다. 여기 한 벌만 둔다.
///
/// 대기는 **FIFO** 다. 반납할 때 `active` 를 내렸다 올리면 그 사이에 새 호출이 끼어들어
/// 대기열이 굶는다 — 그래서 대기자에게 자리를 그대로 넘긴다.
/// **액터가 아니라 잠금이다.** 액터로 만들면 `withSlot` 의 본문이 액터 위에서 돌게 되고,
/// 그 순간 본문과 반환값에 `Sendable` 요구가 붙는다 — 문지기는 남의 코드를 자기 격리
/// 안으로 끌어들이면 안 된다. 여기서는 상태만 잠금으로 지키고 본문은 **호출자의 격리에서**
/// 그대로 돈다. 반납이 동기 함수인 것도 그래서다 — `defer` 안에서 `Task { await … }` 로
/// 미루면 안전 보장이 취소 가능한 Task 에 매달린다(이 저장소가 이미 밟은 함정이다).
public final class ConcurrencyGate: @unchecked Sendable {
    /// 동시에 허용되는 수. 1 이면 상호 배제다.
    public let limit: Int

    private let lock = NSLock()
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// 자리를 하나 얻는다. **반드시 ``release()`` 와 짝을 이뤄야 한다** — `defer` 에 건다.
    ///
    /// 값을 돌려주는 본문에는 ``withSlot(isolation:_:)`` 이 아니라 **이 쌍을 직접** 쓴다.
    /// 자세한 근거는 그 메서드의 주석에.
    public func acquire() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if active < limit {
                active += 1
                lock.unlock()
                continuation.resume()
            } else {
                waiting.append(continuation)
                lock.unlock()
            }
        }
    }

    /// 자리를 반납한다. **동기 함수다** — `defer` 에서 `Task { await … }` 로 미루면
    /// 안전 보장이 취소 가능한 Task 에 매달린다.
    public func release() {
        lock.lock()
        if waiting.isEmpty {
            active -= 1
            lock.unlock()
        } else {
            // 대기 중인 다음 호출에게 자리를 그대로 넘긴다 (`active` 는 건드리지 않는다).
            // 내렸다 올리면 그 사이에 새 호출이 끼어들어 대기열이 굶는다.
            let next = waiting.removeFirst()
            lock.unlock()
            next.resume()
        }
    }

    /// 자리를 얻어 `body` 를 돌린다. `body` 가 던지거나 취소돼도 자리는 반드시 반납된다.
    ///
    /// `#isolation` 을 받아 **호출자의 격리를 물려받는다.** 이게 없으면 액터 안에서 부를 때
    /// 클로저가 격리 경계를 넘게 되고, 그 순간 본문에 `Sendable` 요구가 붙는다.
    ///
    /// **값을 돌려주지 않는다(`-> Void`).** 값을 돌려받아야 하는 자리에는
    /// ``acquire()``/``release()`` 를 **호출부에 펼쳐** 쓴다.
    ///
    /// 이건 취향이 아니라 실측이다(2026-09-07, Swift 6.3.3). 액터 격리 함수에서 배열을 담은
    /// 구조체(`SwiftGrading`)를 **한 단계 더 거쳐** 돌려보내면 그 값이 깨진다 —
    /// `GradeResult.hasErrors` 가 `EXC_BAD_ACCESS`(0x10, 배열 버퍼가 쓰레기)로 죽었다.
    /// 이 문지기를 제네릭 래퍼로 감쌌을 때 6/6 재현, 게이트 없이 단순히
    /// `grade` → `performGrade` 로 쪼개기만 해도 2/2 재현, 한 함수로 되돌리면 0/5.
    /// 즉 방아쇠는 문지기가 아니라 **한 단계 더 거치는 것** 자체이고, 이 시그니처는 그
    /// 함정을 타입으로 막아 둔 것이다. 자세한 경위는 ``SwiftTestingGrader/grade(solution:tests:)``.
    public func withSlot(
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> Void
    ) async rethrows {
        await acquire()
        defer { release() }
        try await body()
    }

    /// 지금 문 안에 있는 수. 테스트가 상한을 단언하는 창구다.
    public var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    /// 자리를 기다리는 수.
    public var waitingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waiting.count
    }

}

/// 프로세스를 띄우는 동시 실행의 상한.
///
/// 상한이 필요한 이유는 실측으로 드러났다 — CI 에서 `RunnerKit` 스위트를 병렬로 돌리자
/// 수십 개가 동시에 `zsh -lic`·`sandbox-exec`·`swiftc` 를 띄우면서 25분 상한을 넘겼고,
/// 직렬로는 8분 47초에 통과했다(2026-09-07). `RLIMIT_NPROC` 이 프로세스 트리가 아니라
/// **실 uid 전체**를 센다는 것과 맞물리는 자리다. 테스트는 `--no-parallel` 로 막았지만
/// 그건 테스트에만 걸린 조치라, 앱도 같은 길로 갈 수 있다.
public enum ExecutionLimits {
    /// 기본 상한. `packtool` 의 `ValidationOptions.defaultConcurrency` 와 **같은 식**이다 —
    /// 검증기와 앱이 같은 부하를 만들어야 한쪽에서 잰 시간이 다른 쪽에서 의미를 갖는다.
    public static var defaultSpawnLimit: Int {
        max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
    }

    /// 프로세스 실행 전역 상한. `SubprocessRunner` 와 `SwiftTestingGrader` 가 이 문을 지난다.
    public static let spawns = ConcurrencyGate(limit: defaultSpawnLimit)

    /// 예열된 SwiftPM 템플릿 디렉터리 하나에 대한 상호 배제(상한 1).
    ///
    /// `SwiftTestingGrader` 는 템플릿 **하나**를 재사용한다 — 첫 채점만 비싸고 이후는
    /// 증분 빌드라는 것이 그 설계의 전부다. 그런데 두 채점이 겹치면 한쪽이 다른 쪽의
    /// `Sources/Solution/Solution.swift` 를 덮어쓴다. 실측 증상: solution 채점이 starter
    /// 코드를 돌렸고 로그에 `Another instance of SwiftPM is already running` 이 남았다.
    ///
    /// **호출자가 아니라 공유 자원 옆에 둔다.** 문을 부르는 쪽에 두면 새 호출자가 생길
    /// 때마다 같은 실수를 다시 할 수 있다 — 앱이 `EditorModel.defaultGrade` 에서
    /// `SwiftTestingGrader()` 를 매번 새로 만드는데, 인스턴스가 달라도 템플릿 경로는
    /// 같아서 액터 경계로는 아무것도 막지 못한다.
    public static func swiftTemplateGate(for directory: URL) -> ConcurrencyGate {
        SwiftTemplateGates.shared.gate(for: directory.standardizedFileURL.path)
    }
}

/// 템플릿 디렉터리 경로별 문지기 등록소. 같은 경로에는 **언제나 같은 문**을 돌려준다 —
/// 매번 새 문을 만들면 상호 배제가 성립하지 않는다.
final class SwiftTemplateGates: @unchecked Sendable {
    static let shared = SwiftTemplateGates()

    private let lock = NSLock()
    private var gates: [String: ConcurrencyGate] = [:]

    func gate(for path: String) -> ConcurrencyGate {
        lock.lock()
        defer { lock.unlock() }
        if let existing = gates[path] { return existing }
        let gate = ConcurrencyGate(limit: 1)
        gates[path] = gate
        return gate
    }
}
