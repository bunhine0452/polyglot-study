/// 클라이언트가 던지는 모든 오류.
///
/// 상태 코드를 그대로 들고 다니지 않고 **재시도 가능 여부로 갈라 둔다** — 재시도 루프가
/// 상태 코드 표를 다시 읽지 않아도 되게.
public indirect enum AnthropicError: Error, Sendable, Hashable {
    /// 400 — 요청이 잘못됐다.
    case invalidRequest(APIErrorBody)
    /// 401 — 키가 없거나 틀렸다.
    case authentication(APIErrorBody)
    /// 403 — 키에 권한이 없다.
    case permission(APIErrorBody)
    /// 404 — 엔드포인트나 모델 ID 가 없다.
    case notFound(APIErrorBody)
    /// 413 — 요청이 너무 크다.
    case requestTooLarge(APIErrorBody)
    /// 429 — 레이트 리밋. `retry-after` 가 있으면 그 값을 우선한다.
    case rateLimited(APIErrorBody, retryAfter: Duration?)
    /// 529 — 서버 과부하.
    case overloaded(APIErrorBody)
    /// 그 밖의 5xx.
    case server(status: Int, APIErrorBody)
    /// 오류 본문조차 해석하지 못한 응답.
    case unexpectedStatus(status: Int, body: String)
    /// 200 인데 본문이 기대한 모양이 아니다.
    case malformedResponse(String)
    /// 전송 계층 실패. `URLError` 등을 문자열로 눌러 담아 `Sendable`·`Hashable` 을 지킨다.
    case transport(String)
    /// HTTP 200 이지만 `stop_reason` 이 `refusal` 이었다.
    case refused(category: String?, explanation: String?)
    /// 재시도를 다 쓰고도 실패했다.
    case retriesExhausted(attempts: Int, last: AnthropicError)

    /// 다시 걸어 볼 가치가 있는가.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .overloaded, .server, .transport:
            true
        case .invalidRequest, .authentication, .permission, .notFound, .requestTooLarge,
             .unexpectedStatus, .malformedResponse, .refused, .retriesExhausted:
            false
        }
    }

    /// 서버가 알려 준 대기 시간. 없으면 지수 백오프를 쓴다.
    public var retryAfter: Duration? {
        if case .rateLimited(_, let retryAfter) = self { return retryAfter }
        return nil
    }
}

extension AnthropicError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidRequest(let body): "400 잘못된 요청 — \(body.summary)"
        case .authentication(let body): "401 인증 실패 — \(body.summary)"
        case .permission(let body): "403 권한 없음 — \(body.summary)"
        case .notFound(let body): "404 없음 — \(body.summary)"
        case .requestTooLarge(let body): "413 요청이 너무 큼 — \(body.summary)"
        case .rateLimited(let body, let retryAfter):
            "429 레이트 리밋 — \(body.summary)\(retryAfter.map { " (retry-after \($0))" } ?? "")"
        case .overloaded(let body): "529 과부하 — \(body.summary)"
        case .server(let status, let body): "\(status) 서버 오류 — \(body.summary)"
        case .unexpectedStatus(let status, let body): "예상 못 한 상태 \(status) — \(body)"
        case .malformedResponse(let detail): "응답 해석 실패 — \(detail)"
        case .transport(let detail): "전송 실패 — \(detail)"
        case .refused(let category, let explanation):
            "모델이 요청을 거절했습니다 (\(category ?? "분류 없음")) — \(explanation ?? "설명 없음")"
        case .retriesExhausted(let attempts, let last):
            "재시도 \(attempts)회를 모두 소진했습니다. 마지막 오류: \(last)"
        }
    }
}

extension APIErrorBody {
    var summary: String {
        let request = requestID.map { " [request_id: \($0)]" } ?? ""
        return "\(type): \(message)\(request)"
    }
}
