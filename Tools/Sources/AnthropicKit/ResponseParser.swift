public import Foundation

/// 응답 해석. **순수 함수다** — 상태 코드·헤더·바이트만 받으므로 키 없이 전량 검증된다.
public enum ResponseParser {
    public static func parse(
        status: Int,
        headers: [String: String],
        data: Data
    ) -> Result<MessagesResponse, AnthropicError> {
        guard status != 200 else {
            do {
                return .success(try JSONDecoder().decode(MessagesResponse.self, from: data))
            } catch {
                return .failure(.malformedResponse("\(error) / 본문 앞부분: \(preview(data))"))
            }
        }
        return .failure(error(status: status, headers: headers, data: data))
    }

    /// 비-200 응답을 타입 있는 오류로 옮긴다.
    public static func error(status: Int, headers: [String: String], data: Data) -> AnthropicError {
        guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
            return .unexpectedStatus(status: status, body: preview(data))
        }
        switch status {
        case 400: return .invalidRequest(body)
        case 401: return .authentication(body)
        case 403: return .permission(body)
        case 404: return .notFound(body)
        case 413: return .requestTooLarge(body)
        case 429: return .rateLimited(body, retryAfter: retryAfter(from: headers))
        case 529: return .overloaded(body)
        case 500...599: return .server(status: status, body)
        default: return .unexpectedStatus(status: status, body: body.summary)
        }
    }

    /// `retry-after` 는 초 단위 숫자다. HTTP-date 형태는 이 API 에서 오지 않으므로
    /// 해석되지 않으면 그냥 무시하고 지수 백오프로 넘어간다.
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
