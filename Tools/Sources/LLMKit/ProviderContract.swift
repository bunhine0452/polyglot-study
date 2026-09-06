/// 모든 ``LLMProvider`` 구현이 지켜야 하는 것.
///
/// `RunnerContractTests` 가 백엔드 4종에 대해 하는 일을 공급자에 대해 한다 — 구현마다
/// 테스트를 새로 쓰는 대신, **하나의 계약**을 각 구현에 태운다. 로컬 MLX 백엔드가 붙는
/// 날 그 타깃의 테스트는 이 함수를 한 번 부르는 것으로 시작한다.
///
/// 검사하는 것은 **능력 선언과 실제 동작의 일치**다. 능력을 부풀린 구현은 여기서
/// 걸린다 — 부풀린 능력은 호출자가 없는 기능을 믿고 분기하게 만들고, 그 실패는 한참
/// 뒤에서 나타난다.
public enum ProviderContract {
    /// 계약 위반 하나.
    public struct Violation: Hashable, Sendable, CustomStringConvertible {
        public let rule: String
        public let detail: String

        public init(rule: String, detail: String) {
            self.rule = rule
            self.detail = detail
        }

        public var description: String { "[\(rule)] \(detail)" }
    }

    /// 공급자를 계약에 태운다. 위반 목록을 돌려준다 — 비어 있으면 통과.
    ///
    /// - Parameters:
    ///   - provider: 검사 대상.
    ///   - happyPath: 성공해야 하는 요청. 호출자가 자기 백엔드에 맞게 준다
    ///     (OpenRouter 는 루프백 서버가, 로컬 백엔드는 실제 모델이 답한다).
    public static func check(
        _ provider: some LLMProvider,
        happyPath: CompletionRequest
    ) async -> [Violation] {
        var violations: [Violation] = []

        // 1. 신원에 비밀값이 없어야 한다. 실행 로그가 이 문자열을 그대로 남긴다.
        let identity = provider.identity.description
        if Redactor().redact(identity) != identity {
            violations.append(
                .init(rule: "identity-has-no-secret", detail: "신원 문자열이 키처럼 생긴 토큰을 담고 있습니다.")
            )
        }
        if provider.identity.model.rawValue.isEmpty {
            violations.append(.init(rule: "identity-has-model", detail: "모델 ID 가 비어 있습니다."))
        }

        // 2. 선언하지 않은 응답 형식은 `.unsupported` 로 거절해야 한다. 조용히 다른
        //    형식으로 답하는 것이 가장 나쁜 실패다 — 호출자가 파싱에서야 알게 된다.
        for format in [ResponseFormat.jsonObject, .jsonSchema(name: "contract", schema: ["type": "object"])] {
            guard let required = format.requiredCapability,
                  !provider.capabilities.contains(required)
            else { continue }
            var probe = happyPath
            probe.responseFormat = format
            do {
                _ = try await provider.complete(probe)
                violations.append(
                    .init(
                        rule: "unsupported-format-rejected",
                        detail: "\(required) 를 선언하지 않았는데 \(format) 요청이 성공했습니다."
                    )
                )
            } catch let error as LLMError {
                if case .unsupported = error {} else {
                    violations.append(
                        .init(
                            rule: "unsupported-format-rejected",
                            detail: "\(format) 이 .unsupported 가 아닌 \(error) 로 실패했습니다."
                        )
                    )
                }
            } catch {
                violations.append(
                    .init(rule: "errors-are-llm-errors", detail: "LLMError 가 아닌 \(error) 를 던졌습니다.")
                )
            }
        }

        // 3. 스트리밍을 선언하지 않았으면 `stream` 은 `.unsupported(.streaming)` 로 끝나야
        //    한다. `complete` 를 감싼 가짜 스트림은 계약 위반이다.
        if !provider.capabilities.contains(.streaming) {
            do {
                for try await _ in provider.stream(happyPath) {}
                violations.append(
                    .init(rule: "stream-declares-truth", detail: "스트리밍 미선언인데 stream() 이 값을 냈습니다.")
                )
            } catch LLMError.unsupported(.streaming) {
                // 기대한 결과.
            } catch {
                violations.append(
                    .init(rule: "stream-declares-truth", detail: "stream() 이 \(error) 로 실패했습니다.")
                )
            }
        }

        // 4. 해피패스. 여기서 나오는 값이 실행 로그의 재료다.
        do {
            let response = try await provider.complete(happyPath)
            if response.model.isEmpty {
                violations.append(
                    .init(rule: "response-names-model", detail: "응답이 실제로 답한 모델을 비워 두었습니다.")
                )
            }
            if provider.capabilities.contains(.usageTokens),
               response.usage.inputTokens == nil, response.usage.outputTokens == nil {
                violations.append(
                    .init(rule: "usage-is-reported", detail: "usageTokens 를 선언했는데 usage 가 전부 nil 입니다.")
                )
            }
            if provider.capabilities.contains(.usageCost), response.usage.costUSD == nil {
                violations.append(
                    .init(rule: "cost-is-reported", detail: "usageCost 를 선언했는데 costUSD 가 nil 입니다.")
                )
            }
        } catch {
            violations.append(.init(rule: "happy-path-succeeds", detail: "해피패스가 \(error) 로 실패했습니다."))
        }

        return violations
    }
}
