public import Foundation
public import LLMKit

/// 공급자와 실행 로그를 묶은 호출 창구.
///
/// ``LLMProvider`` 를 감싸는 데코레이터로 만들지 않은 이유가 있다. 로그가 남겨야 하는
/// 것은 "어떤 요청이 나갔나" 가 아니라 **어느 단계가 어느 레슨을 몇 번째로 시도했나**
/// 이고, 그 셋은 요청 본문에 없다. 프로토콜에 컨텍스트 파라미터를 끼워 넣으면 로컬
/// MLX 백엔드까지 실행 로그의 개념을 물려받는다 — 그건 이 도구만의 사정이다.
public struct MeteredClient: Sendable {
    private let provider: any LLMProvider
    private let log: RunLog
    private let clock: @Sendable () -> Date

    public init(
        provider: any LLMProvider,
        log: RunLog,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.log = log
        self.clock = clock
    }

    public var capabilities: ProviderCapabilities { provider.capabilities }
    public var identity: ProviderIdentity { provider.identity }

    /// 예산을 확인하고, 부르고, 결과를 적는다.
    ///
    /// 실패도 적는다 — 실패한 호출은 돈이 나가지 않지만 시간과 재시도 예산을 쓰고,
    /// 나중에 "왜 이 레슨만 세 번 돌았나" 를 되짚는 유일한 흔적이다.
    public func complete(
        _ request: CompletionRequest,
        stage: GenerationStage,
        subject: String,
        attempt: Int
    ) async throws -> CompletionResponse {
        try await log.ensureBudget()
        let startedAt = clock()
        let started = ContinuousClock.now
        do {
            let response = try await provider.complete(request)
            try await log.record(
                stage: stage,
                subject: subject,
                attempt: attempt,
                requestedModel: identity.model,
                request: request,
                response: response,
                startedAt: startedAt,
                duration: ContinuousClock.now - started)
            return response
        } catch {
            try? await log.recordFailure(
                stage: stage,
                subject: subject,
                attempt: attempt,
                requestedModel: identity.model,
                request: request,
                error: String(describing: error),
                startedAt: startedAt,
                duration: ContinuousClock.now - started)
            throw error
        }
    }
}
