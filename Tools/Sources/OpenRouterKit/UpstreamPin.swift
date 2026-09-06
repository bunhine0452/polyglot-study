internal import Foundation

/// 요청을 특정 업스트림에 고정한다.
///
/// ## 왜 필요한가 — 실측
///
/// OpenRouter 의 모델 ID 하나 뒤에는 여러 업스트림이 서 있고, 라우터가 매 요청마다
/// 고른다. 프롬프트 캐시는 **그 업스트림에 붙어 있다.** `session_id` 는 "같은 곳으로
/// 보내 달라" 는 힌트일 뿐이라, `z-ai/glm-5.3-flash` 로 같은 `session_id` 를 달아 7회를
/// 보냈을 때 NextBit·Wafer·Reka 셋으로 갈렸고 `cached_tokens` 가 매번 0 이었다.
/// 고정 시스템 프롬프트를 아무리 잘 잡아도 캐시가 차가웠다는 뜻이다
/// (`{#lessongen-prompt-caching}`).
///
/// 그래서 힌트가 아니라 제약이 필요하다. 이 값이 `provider.order` 와
/// `provider.allow_fallbacks` 로 나간다.
///
/// ## 고를 이름을 어디서 얻는가
///
/// 실행 로그(`run.json`)의 `upstreamProviders` 가 **실제로 답한** 업스트림 이름을
/// 들고 있다. 한 번 돌려 보고 그 이름을 고정하는 것이 순서다 — 이름을 추측해 적으면
/// ``allowFallbacks`` 가 꺼진 채로 요청이 통째로 실패한다.
public struct UpstreamPin: Sendable, Hashable {
    /// 업스트림 이름, 우선순위 순. 비어 있으면 고정이 아니다.
    public let providers: [String]
    /// `false` 면 ``providers`` 밖으로 나가지 않는다.
    ///
    /// 기본이 `false` 인 것은 의도다. 고정을 요청해 놓고 조용히 다른 업스트림으로 새면
    /// 캐시는 차가운데 요청은 성공해서, **아무도 고정이 실패한 줄 모른다.** 차라리
    /// 실패하는 편이 낫다.
    public let allowFallbacks: Bool

    /// 이름이 하나도 없으면 `nil` — "고정 없음" 을 옵셔널로 표현해 호출부의 분기를 없앤다.
    public init?(providers: [String], allowFallbacks: Bool = false) {
        let cleaned = providers
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        self.providers = cleaned
        self.allowFallbacks = allowFallbacks
    }

    /// 실제로 답한 업스트림이 고정 목록 안에 있는가. 실행 로그가 이걸로 "고정이
    /// 먹혔는가" 를 판정한다.
    public func honored(by upstream: String) -> Bool {
        providers.contains(upstream)
    }

    /// 사람이 읽는 한 줄.
    public var logLine: String {
        providers.joined(separator: " → ") + (allowFallbacks ? " (폴백 허용)" : " (폴백 금지)")
    }
}
