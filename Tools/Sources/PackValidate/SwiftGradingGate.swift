/// Swift 채점을 **한 번에 하나씩** 흘려보내는 문.
///
/// `SwiftTestingGrader` 는 예열된 SwiftPM 템플릿 디렉터리 **하나**를 재사용한다 — 첫 채점만
/// 비싸고 이후는 증분 빌드라는 것이 그 설계의 전부다. 그런데 두 채점이 겹치면 한쪽이 다른
/// 쪽의 `Sources/Solution/Solution.swift` 를 덮어쓴다.
///
/// 실측으로 드러난 증상: 한 과제의 solution 채점과 starter 채점을 `async let` 으로 동시에
/// 태웠더니 **solution 채점이 starter 코드를 돌렸고**, 게이트가 "solution 이 테스트를
/// 통과하지 못한다" 고 보고했다. 로그에는 `Another instance of SwiftPM is already running` 이
/// 남아 있었다. 블록들이 레슨을 넘어 동시에 도는 구조라 어느 두 Swift 블록이 겹쳐도 같은 일이
/// 일어난다.
///
/// 채점마다 템플릿을 새로 만들면 매번 콜드 빌드(≈6초)라 228 레슨에서 감당이 안 된다.
/// 여기서 직렬화하는 편이 훨씬 싸다 — 예열된 템플릿은 회당 ≈0.65초다.
///
/// - Note: 액터 메서드 안에서 `await` 하면 재진입이 허용되므로, 액터로 감싸는 것만으로는
///   상호 배제가 되지 않는다. 명시적인 획득·반납이 필요하다.
actor SwiftGradingGate {
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// 문을 지나는 동안 다른 호출을 막는다. `body` 가 던져도 반드시 반납된다.
    func exclusive<T>(_ body: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await body()
    }

    private func acquire() async {
        guard busy else {
            busy = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            busy = false
        } else {
            // 대기 중인 다음 호출에게 소유권을 그대로 넘긴다 — busy 를 내렸다 올리면
            // 그 사이에 새 호출이 끼어들어 대기열이 굶는다.
            waiting.removeFirst().resume()
        }
    }
}
