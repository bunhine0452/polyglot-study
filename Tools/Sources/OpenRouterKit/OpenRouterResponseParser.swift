public import Foundation
public import LLMKit

/// 응답 해석. **순수 함수다** — 상태 코드·헤더·바이트만 받으므로 키 없이 전량 검증된다.
///
/// 여기가 "OpenRouter 의 오류를 우리 오류로 옮기는" 유일한 곳이다. 재시도 판정은 이
/// 매핑에서 파생되고, 재시도 루프는 상태 코드 표를 다시 읽지 않는다.
public enum OpenRouterResponseParser {
    public static func parse(
        status: Int,
        headers: [String: String],
        data: Data
    ) -> Result<CompletionResponse, LLMError> {
        guard status == 200 else {
            return .failure(error(status: status, headers: headers, data: data))
        }

        let decoded: ChatCompletionsResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        } catch {
            return .failure(.malformedResponse("\(error) / 본문 앞부분: \(preview(data))"))
        }

        // **200 이어도 오류가 실려 올 수 있다.** 상태 코드만 보고 성공으로 넘기면
        // 아래에서 "content 가 없다" 는 엉뚱한 메시지로 실패한다.
        if let wireError = decoded.error ?? decoded.choices?.first?.error {
            return .failure(map(wireError, status: nil, headers: headers))
        }

        guard let choice = decoded.choices?.first else {
            return .failure(.malformedResponse("choices 가 비어 있습니다 / 본문 앞부분: \(preview(data))"))
        }
        if let refusal = choice.message?.refusal, !refusal.isEmpty {
            return .failure(.refused(reason: refusal))
        }

        let finishReason = choice.finishReason.map { FinishReason($0) }
        // 콘텐츠 필터로 끝난 것은 "빈 응답" 이 아니라 거절이다. 구별하지 않으면
        // 재시도 루프가 의미 없이 같은 요청을 다시 건다.
        if finishReason == .contentFilter {
            return .failure(.refused(reason: choice.nativeFinishReason ?? "content_filter"))
        }

        return .success(
            CompletionResponse(
                id: decoded.id ?? "",
                model: decoded.model ?? "",
                upstreamProvider: decoded.provider,
                text: choice.message?.content ?? "",
                reasoning: choice.message?.reasoning,
                finishReason: finishReason,
                usage: usage(from: decoded.usage)
            )
        )
    }

    static func usage(from wire: WireUsage?) -> TokenUsage {
        guard let wire else { return .unknown }
        return TokenUsage(
            inputTokens: wire.promptTokens,
            outputTokens: wire.completionTokens,
            reasoningTokens: wire.completionTokensDetails?.reasoningTokens,
            cachedInputTokens: wire.promptTokensDetails?.cachedTokens,
            cacheWriteTokens: wire.promptTokensDetails?.cacheWriteTokens,
            costUSD: wire.cost
        )
    }

    /// 비-200 응답을 타입 있는 오류로 옮긴다.
    public static func error(status: Int, headers: [String: String], data: Data) -> LLMError {
        guard let envelope = try? JSONDecoder().decode(WireErrorEnvelope.self, from: data) else {
            return .undecodableError(status: status, body: preview(data))
        }
        return map(envelope.error, status: status, headers: headers, requestID: envelope.requestID)
    }

    static func map(
        _ wireError: WireError,
        status: Int?,
        headers: [String: String],
        requestID: String? = nil
    ) -> LLMError {
        let detail = ProviderErrorDetail(
            // 사람이 읽을 때 유용한 것은 숫자가 아니라 분류 이름이다.
            code: wireError.metadata?.errorType ?? wireError.code,
            message: wireError.message,
            requestID: requestID ?? headers["x-generation-id"] ?? headers["x-request-id"],
            upstreamProvider: wireError.metadata?.providerName
        )

        // **분류는 `metadata.error_type` 이 먼저다.** OpenRouter 는 업스트림이 요청을
        // 받아들인 뒤의 실패를 HTTP 200 에 실어 보내므로, 상태 코드만 보면 재시도해야
        // 할 것을 성공으로 착각한다. `error_type` 은 그 경우에도 살아 있는 값이다.
        if let errorType = wireError.metadata?.errorType,
           let mapped = mapErrorType(errorType, detail: detail, headers: headers) {
            return mapped
        }

        // 상태 코드가 없으면(200 본문 오류) 봉투의 `code` 를 상태로 읽어 본다.
        let effective = status ?? wireError.code.flatMap(Int.init)

        switch effective {
        case 400: return .invalidRequest(detail)
        case 401: return .authentication(detail)
        case 402: return .insufficientCredits(detail)
        // 403 은 모더레이션이다 — 다시 걸어도 같은 프롬프트는 같은 판정을 받는다.
        case 403: return .permission(detail)
        case 404: return .notFound(detail)
        // 408 은 업스트림이 응답을 못 만든 것 — 다시 걸 가치가 있다.
        case 408: return .overloaded(detail)
        case 413: return .requestTooLarge(detail)
        case 429: return .rateLimited(detail, retryAfter: retryAfter(from: headers))
        // 502 는 업스트림 실패, 503 은 조건을 만족하는 업스트림이 없음. 둘 다 라우팅이
        // 다음 시도에 다른 업스트림을 고를 수 있으므로 재시도한다.
        case 502, 503: return .overloaded(detail)
        case .some(let code) where (500...599).contains(code): return .server(detail)
        case .some(let code): return .undecodableError(status: code, body: detail.summary)
        case nil: return .server(detail)
        }
    }

    /// 문서화된 `error_type` 어휘를 우리 오류로 옮긴다.
    ///
    /// 모르는 값이면 `nil` 을 돌려 상태 코드 경로로 넘긴다 — 새 분류가 생겨도 조용히
    /// 엉뚱한 케이스로 가지 않게.
    static func mapErrorType(
        _ errorType: String,
        detail: ProviderErrorDetail,
        headers: [String: String]
    ) -> LLMError? {
        switch errorType {
        case "rate_limit_exceeded":
            return .rateLimited(detail, retryAfter: retryAfter(from: headers))
        case "provider_overloaded", "provider_unavailable", "timeout":
            return .overloaded(detail)
        case "server", "unmapped":
            return .server(detail)
        case "authentication":
            return .authentication(detail)
        case "payment_required":
            return .insufficientCredits(detail)
        case "permission_denied", "content_policy_violation":
            return .permission(detail)
        case "refusal", "invalid_prompt":
            return .refused(reason: detail.message)
        case "not_found":
            return .notFound(detail)
        case "context_length_exceeded", "max_tokens_exceeded", "token_limit_exceeded",
             "payload_too_large", "string_too_long":
            return .requestTooLarge(detail)
        case "invalid_request", "precondition_failed", "unprocessable":
            return .invalidRequest(detail)
        default:
            return nil
        }
    }

    /// `retry-after` 는 초 단위 숫자다. HTTP-date 형태는 해석되지 않으면 그냥 무시하고
    /// 지수 백오프로 넘어간다.
    public static func retryAfter(from headers: [String: String]) -> Duration? {
        guard let raw = headers.first(where: { $0.key.lowercased() == "retry-after" })?.value,
              let seconds = Double(raw.trimmingCharacters(in: .whitespaces)),
              seconds >= 0
        else { return nil }
        return .seconds(seconds)
    }

    /// 오류 메시지에 실을 본문 앞부분. 통째로 실으면 로그가 터진다.
    private static func preview(_ data: Data, limit: Int = 512) -> String {
        let text = String(decoding: data.prefix(limit), as: UTF8.self)
        return data.count > limit ? text + "…(\(data.count) bytes)" : text
    }
}
