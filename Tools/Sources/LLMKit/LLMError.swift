/// 공급자가 던지는 모든 오류.
///
/// **공급자 중립이다.** HTTP 상태 코드도 OpenRouter 의 오류 코드도 여기 그대로 들어오지
/// 않는다 — 각 공급자가 자기 와이어 오류를 이 표로 옮기고, 그 매핑이 곧 "이 공급자는
/// 무엇을 재시도 가능하다고 보는가" 의 선언이다. 호출자(재시도 루프·CLI·실행 로그)는
/// 공급자별 상태 코드 표를 다시 읽지 않는다.
///
/// 로컬 백엔드(MLX)가 꽂힐 때를 위해 HTTP 냄새가 나는 케이스는 최소로 뒀다. 모델 적재
/// 실패·컨텍스트 초과처럼 로컬에도 있는 실패는 ``unsupported``·``invalidRequest``·
/// ``provider`` 로 표현된다.
public indirect enum LLMError: Error, Sendable, Hashable {
    /// 요청 자체가 잘못됐다. 다시 걸어도 같다.
    case invalidRequest(ProviderErrorDetail)
    /// 키가 없거나 틀렸다.
    case authentication(ProviderErrorDetail)
    /// 키에 권한이 없다 — 또는 모더레이션이 요청을 막았다.
    case permission(ProviderErrorDetail)
    /// 모델 ID 나 엔드포인트가 없다.
    case notFound(ProviderErrorDetail)
    /// 잔액·크레딧이 모자라다. 다시 걸어도 같으므로 재시도하지 않는다.
    case insufficientCredits(ProviderErrorDetail)
    /// 요청이 너무 크다 (컨텍스트 초과 포함).
    case requestTooLarge(ProviderErrorDetail)
    /// 레이트 리밋. 서버가 알려 준 대기 시간이 있으면 실어 나른다.
    case rateLimited(ProviderErrorDetail, retryAfter: Duration?)
    /// 업스트림이 과부하·일시 장애다.
    case overloaded(ProviderErrorDetail)
    /// 그 밖의 서버측 실패.
    case server(ProviderErrorDetail)
    /// 오류 본문조차 해석하지 못한 응답.
    case undecodableError(status: Int?, body: String)
    /// 성공 응답인데 본문이 기대한 모양이 아니다.
    case malformedResponse(String)
    /// 전송 계층 실패. `URLError` 등을 문자열로 눌러 담아 `Sendable`·`Hashable` 을 지킨다.
    case transport(String)
    /// 모델이 요청을 거절했다. 성공 응답 안에 실려 오므로 상태 코드로는 안 잡힌다.
    case refused(reason: String?)
    /// 이 공급자가 지원하지 않는 기능을 요구했다.
    ///
    /// ``LLMProvider/capabilities`` 로 미리 물어보면 여기까지 오지 않는다. 그래도 두는
    /// 이유는 능력 선언과 실제 동작이 어긋날 때 **조용히 다른 일을 하지 않게** 하려는 것.
    case unsupported(ProviderCapabilities)
    /// 위 어디에도 안 맞는 공급자 고유 실패. 로컬 백엔드의 모델 적재 실패 같은 것.
    case provider(String)
    /// 재시도를 다 쓰고도 실패했다.
    case retriesExhausted(attempts: Int, last: LLMError)

    /// 다시 걸어 볼 가치가 있는가.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .overloaded, .server, .transport:
            true
        case .invalidRequest, .authentication, .permission, .notFound, .insufficientCredits,
             .requestTooLarge, .undecodableError, .malformedResponse, .refused, .unsupported,
             .provider, .retriesExhausted:
            false
        }
    }

    /// 서버가 알려 준 대기 시간. 없으면 지수 백오프를 쓴다.
    public var retryAfter: Duration? {
        if case .rateLimited(_, let retryAfter) = self { return retryAfter }
        return nil
    }
}

/// 공급자가 준 오류 설명.
///
/// OpenRouter 는 `{"error":{"code":…,"message":…,"metadata":{…}}}` 를, 로컬 백엔드는
/// 아무 코드도 없이 문장 하나를 준다. 둘 다 담기게 코드는 선택이다.
public struct ProviderErrorDetail: Sendable, Hashable {
    /// 공급자가 붙인 코드. HTTP 상태일 수도, 문자열 코드일 수도, 없을 수도 있다.
    public let code: String?
    public let message: String
    /// 요청을 되짚을 식별자. 실행 로그가 이걸 남긴다.
    public let requestID: String?
    /// 실제로 응답을 만든 업스트림. OpenRouter 는 같은 모델도 여러 공급자가 서빙한다.
    public let upstreamProvider: String?

    public init(
        code: String? = nil,
        message: String,
        requestID: String? = nil,
        upstreamProvider: String? = nil
    ) {
        self.code = code
        self.message = message
        self.requestID = requestID
        self.upstreamProvider = upstreamProvider
    }

    public var summary: String {
        var parts = ""
        if let code { parts += "\(code): " }
        parts += message
        if let upstreamProvider { parts += " [provider: \(upstreamProvider)]" }
        if let requestID { parts += " [request_id: \(requestID)]" }
        return parts
    }
}

extension LLMError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidRequest(let detail): "잘못된 요청 — \(detail.summary)"
        case .authentication(let detail): "인증 실패 — \(detail.summary)"
        case .permission(let detail): "권한 없음 — \(detail.summary)"
        case .notFound(let detail): "없는 모델·엔드포인트 — \(detail.summary)"
        case .insufficientCredits(let detail): "크레딧 부족 — \(detail.summary)"
        case .requestTooLarge(let detail): "요청이 너무 큼 — \(detail.summary)"
        case .rateLimited(let detail, let retryAfter):
            "레이트 리밋 — \(detail.summary)\(retryAfter.map { " (retry-after \($0))" } ?? "")"
        case .overloaded(let detail): "업스트림 과부하 — \(detail.summary)"
        case .server(let detail): "서버 오류 — \(detail.summary)"
        case .undecodableError(let status, let body):
            "해석 못 한 오류 응답\(status.map { " (상태 \($0))" } ?? "") — \(body)"
        case .malformedResponse(let detail): "응답 해석 실패 — \(detail)"
        case .transport(let detail): "전송 실패 — \(detail)"
        case .refused(let reason):
            "모델이 요청을 거절했습니다 — \(reason ?? "설명 없음")"
        case .unsupported(let capability):
            "이 공급자가 지원하지 않는 기능입니다: \(capability)"
        case .provider(let detail): "공급자 오류 — \(detail)"
        case .retriesExhausted(let attempts, let last):
            "재시도 \(attempts)회를 모두 소진했습니다. 마지막 오류: \(last)"
        }
    }
}
