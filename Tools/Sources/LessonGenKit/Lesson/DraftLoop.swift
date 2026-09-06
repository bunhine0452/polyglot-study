import LLMKit

/// "물어보고 → 직렬화하고 → 거부당하면 사유를 붙여 다시 물어보는" 루프.
///
/// 생성과 수리가 같은 루프를 쓴다. 다른 것은 프롬프트뿐이므로 루프를 두 벌 두면 한쪽만
/// 고쳐지는 날이 온다.
///
/// 네트워크 재시도(429·5xx)는 여기 없다 — 공급자 안에서 이미 끝난다. 여기서 다루는
/// 것은 **같은 요청을 다시 걸어도 같은 결과가 오는** 실패, 즉 문법 위반뿐이다.
enum DraftLoop {
    static func run(
        client: MeteredClient,
        stage: GenerationStage,
        subject: String,
        retries: Int,
        makeRequest: (_ followUps: [(assistant: String, user: String)]) -> CompletionRequest,
        assemble: (LessonContentDraft, CompletionResponse) throws -> GeneratedLesson
    ) async throws -> GeneratedLesson {
        var followUps: [(assistant: String, user: String)] = []
        var lastError: LessonSerializationError?

        for attempt in 1...(max(0, retries) + 1) {
            let completion = try await client.complete(
                makeRequest(followUps), stage: stage, subject: subject, attempt: attempt)
            do {
                return try assemble(try LessonGenerator.decodeDraft(from: completion), completion)
            } catch let error as LessonSerializationError {
                lastError = error
                followUps.append(
                    (assistant: completion.text, user: LessonPrompt.serializationRetry(error)))
            } catch let error as LessonGenerationError {
                // 스키마를 못 맞춘 것은 다시 물어볼 가치가 있다. 잘렸거나 비어 있는 것은
                // 같은 요청을 다시 걸어도 같으므로 그대로 올려 보낸다.
                guard case .undecodableDraft(let detail) = error else { throw error }
                lastError = .unparsableOutput(detail)
                followUps.append(
                    (assistant: completion.text, user: LessonPrompt.schemaRetry(detail)))
            }
        }
        throw LessonGenerationError.serializationFailed(
            attempts: max(0, retries) + 1,
            last: lastError ?? .unparsableOutput("알 수 없는 실패"))
    }
}
