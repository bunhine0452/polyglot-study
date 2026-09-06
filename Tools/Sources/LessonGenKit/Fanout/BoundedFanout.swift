/// 동시성을 제한한 팬아웃.
///
/// ## Batch 를 쓰지 않는 이유 (`{#lessongen-batch-fanout}`)
///
/// OpenRouter 에 배치 엔드포인트(`/api/beta/batches`)가 있고 보통 50% 싸다. **현 모델에는
/// 해당하지 않는다** — 실측: `z-ai/glm-5.3-flash` 의 표준 엔드포인트에 프로모션 할인이
/// 걸려 있어 $0.075/M 인데, `:batch` 변종은 정가 $0.15/M 이라 **두 배 비싸다**. 게다가
/// 배치는 `seed` 를 받지 않아 재현 기록이 한 칸 빈다. 그래서 24시간을 기다리는 대신
/// 동시성을 제한해 그냥 병렬로 친다.
///
/// 제한을 두는 이유는 레이트 리밋이다. 무제한으로 던지면 429 가 쏟아지고, 공급자의
/// 지수 백오프가 그걸 받아 내느라 전체가 오히려 느려진다.
public enum BoundedFanout {
    /// 결과 하나. 입력 순서를 그대로 지킨다.
    public struct Outcome<Value: Sendable>: Sendable {
        public let index: Int
        public let result: Result<Value, any Error>

        public init(index: Int, result: Result<Value, any Error>) {
            self.index = index
            self.result = result
        }

        public var value: Value? { try? result.get() }
        public var error: (any Error)? {
            if case .failure(let error) = result { return error }
            return nil
        }
    }

    /// - Parameters:
    ///   - limit: 동시에 떠 있을 최대 작업 수. 1 이면 순차.
    ///   - shouldStop: 이 오류를 만나면 **새 작업을 더 띄우지 않는다**. 비용 가드가
    ///     이걸 쓴다 — 예산을 넘긴 뒤에도 남은 레슨을 전부 던지면 정지선이 정지선이 아니다.
    ///     이미 떠 있는 작업은 끝까지 간다. 도중에 취소하면 이미 나간 요청의 비용은
    ///     그대로 나가면서 결과만 버리게 되기 때문이다.
    public static func run<Input: Sendable, Value: Sendable>(
        _ inputs: [Input],
        limit: Int,
        shouldStop: @escaping @Sendable (any Error) -> Bool = { _ in false },
        operation: @escaping @Sendable (Int, Input) async throws -> Value
    ) async -> [Outcome<Value>] {
        guard !inputs.isEmpty else { return [] }
        let width = max(1, min(limit, inputs.count))

        return await withTaskGroup(of: Outcome<Value>.self) { group in
            var next = 0
            var collected: [Outcome<Value>] = []
            collected.reserveCapacity(inputs.count)
            var stopped = false

            func addTask(_ index: Int) {
                let input = inputs[index]
                group.addTask {
                    do {
                        return Outcome(index: index, result: .success(try await operation(index, input)))
                    } catch {
                        return Outcome(index: index, result: .failure(error))
                    }
                }
            }

            while next < width {
                addTask(next)
                next += 1
            }

            while let outcome = await group.next() {
                collected.append(outcome)
                if let error = outcome.error, shouldStop(error) { stopped = true }
                guard !stopped, next < inputs.count else { continue }
                addTask(next)
                next += 1
            }

            // 띄우지 못한 나머지는 결과가 없다. 호출자가 "안 돌았다" 를 볼 수 있어야
            // 하므로 침묵하지 않고 취소 결과로 채운다.
            let done = Set(collected.map(\.index))
            for index in inputs.indices where !done.contains(index) {
                collected.append(Outcome(index: index, result: .failure(FanoutStopped())))
            }
            return collected.sorted { $0.index < $1.index }
        }
    }
}

/// 앞선 실패 때문에 아예 시작하지 못한 작업.
public struct FanoutStopped: Error, Hashable, Sendable, CustomStringConvertible {
    public init() {}
    public var description: String { "앞선 중단 때문에 시작하지 않았습니다." }
}
