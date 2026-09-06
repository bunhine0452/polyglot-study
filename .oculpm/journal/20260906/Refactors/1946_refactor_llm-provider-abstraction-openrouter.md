---
schema_version: 1
type: refactor
slug: "llm-provider-abstraction-openrouter"
status: done
difficulty: high
created_at: "2026-09-06T19:46:53+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/LLMKit"
    op: create
  - path: "Tools/Sources/OpenRouterKit"
    op: create
  - path: "Tools/Sources/AnthropicKit"
    op: delete
  - path: "Tools/Sources/LessonGenKit/OutlineGenerator.swift"
    op: update
  - path: "Tools/Sources/lessongen/OutlineCommand.swift"
    op: update
  - path: "Tools/Sources/lessongen/LessonGen.swift"
    op: update
  - path: "Tools/Package.swift"
    op: update
  - path: "Tools/Tests/LLMKitTests"
    op: create
  - path: "Tools/Tests/OpenRouterKitTests"
    op: create
  - path: "Tools/Tests/TestSupport/Fixtures.swift"
    op: update
  - path: "Tools/Tests/TestSupport/StubTransport.swift"
    op: update
  - path: ".gitignore"
    op: update
related:
  - ref: "20260906/Features_to_add/1847_feature_content-pipeline-foundation.md"
    kind: "followup"
  - ref: "20260906/Features_to_add/1826_feature_tools-package-and-lessongen-client.md"
    kind: "followup"
tags:
  - "llm"
  - "openrouter"
  - "provider-abstraction"
  - "dotenv"
  - "structured-outputs"
  - "prompt-caching"
  - "mcp-tool"
---
[x] LLM 공급자 추상화와 OpenRouter 구현

Anthropic 직결이던 `AnthropicKit` 을 공급자 중립 `LLMKit`(프로토콜·키·재시도·로그 마스킹·계약 스위트)과 `OpenRouterKit`(OpenAI 호환 chat/completions) 둘로 갈랐다. **실왕복 1회 성공** — `{#lessongen-http-client}` 가 실제로 닫혔다. Tools 69 → 135 테스트, LearnKit 607 그대로, 양쪽 경고 0.

## 동기

사용자가 `OPENROUTER_API_KEY`/`OPENROUTER_MODEL` 로 대체하기로 결정했고, 로컬 AI 과외(MLX + RAG)가 나중에 같은 자리에 꽂힌다. 공급자를 프로토콜 뒤로 미는 가장 싼 시점이 지금이었다.

## 변경 요약

**`LLMKit`** — `LLMProvider` 프로토콜. `CodeRunner` 배치를 그대로 따랐다: 런타임에 물어보는 `capabilities: ProviderCapabilities`(OptionSet), 공급자 중립 오류 `LLMError`(재시도 판정 포함), 모든 구현이 통과해야 하는 `ProviderContract`. 프로토콜 모듈에는 **어떤 공급자의 와이어 타입도 없다** — `LanguageKit`(CodeRunner) / `RunnerKit`(백엔드) 관계와 같다.

능력은 **이 구현이 실제로 하는 것**이지 모델의 이론적 상한이 아니다. `streaming` 이 빠진 것은 OpenRouter 가 SSE 를 못 해서가 아니라 우리가 안 하기 때문이고, 미선언 공급자의 `stream()` 은 `complete` 를 감싼 가짜 스트림이 아니라 `.unsupported(.streaming)` 로 끝난다. 계약이 그걸 검사한다.

**`OpenRouterKit`** — `POST https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer`, `HTTP-Referer` + `X-OpenRouter-Title`. 조립(`OpenRouterRequestBuilder`)과 해석(`OpenRouterResponseParser`)은 순수 함수, 왕복·재시도만 공급자가 갖는다. 재시도 루프를 프로토콜이 아니라 구현에 둔 것은 의도다 — 로컬 백엔드에 HTTP 백오프는 무의미하다.

**단계별 모델 오버라이드** — `GenerationStage` 넷(outline/lesson/prose/repair)과 `OPENROUTER_MODEL_<STAGE>`. 나누는 기준은 도메인이 아니라 **자동 게이트의 유무**다: lesson·repair 는 `packtool` 이 실행해 검증하므로 값싼 모델이 틀려도 게이트가 잡고 repair 가 수렴한다. outline 은 사람이 리뷰한다. 반면 **prose(개념 설명 산문)에는 어떤 자동 게이트도 없다** — 컴파일되는 코드 옆의 틀린 한국어 설명은 전 단계를 통과해 학습자에게 그대로 간다. 분리 생성 자체는 `{#lessongen-lesson}` 의 일이라 배선과 로그만 넣었다.

**`.env` 로딩** — 외부 의존성 없이 직접 판다. 우선순위는 **프로세스 환경변수 > `.env`**. cwd 에서 위로 올라가며 찾고 `--env-file` 로 짚을 수 있다. Swift 에서 `"\r\n"` 이 **문자 하나**라 `split(separator: "\n")` 이 CRLF 파일을 한 줄로 뭉치는 함정을 밟았다 — `whereSeparator: \.isNewline` 으로 고쳤고 테스트가 지킨다.

## 웹 검색·모델 API 조회로 설계를 바꾼 사실 다섯

1. **엔드포인트 룰렛.** `z-ai/glm-5.3-flash` 를 서빙하는 엔드포인트가 23곳인데 `structured_outputs` 를 지원하는 곳은 17곳뿐이고, **Z.AI 자사 엔드포인트가 미지원**이다. `seed` 는 14곳만 지원한다. OpenRouter 는 미지원 파라미터를 **조용히 버리므로**, 좁히지 않으면 200 과 함께 산문이 돌아온다 — 스키마 위반이 아니라 JSON 이 아예 아닌 응답이라 파싱 실패로만 드러난다. 그래서 `provider: {require_parameters: true}` 를 구조화 출력·시드 요청에 붙이고, **그 플래그를 끄면 `structuredOutputs` 능력 선언도 함께 빠지게** 묶었다.
2. **`usage: {include: true}` 는 폐기됐다.** 아무 효과가 없고 사용량·비용은 항상 실린다. 죽은 필드를 보내면 캐시 접두사 바이트만 흔들어서 뺐다.
3. **HTTP 200 에 오류가 실려 온다.** 업스트림이 요청을 받아들인 뒤의 실패는 전부 200 본문 안이다. 상태 코드 대신 `error.metadata.error_type` 을 1차 분류 근거로 쓴다 (`rate_limit_exceeded`·`provider_overloaded`·`provider_unavailable`·`timeout`·`server` 만 재시도). 모르는 값은 상태 코드 경로로 넘긴다.
4. **`X-Title` 은 옛 이름**이고 정식 이름은 `X-OpenRouter-Title` 이다.
5. **이 모델은 사고가 필수**(`reasoning.mandatory: true`, 기본 effort `max`)이고 지원 effort 는 low/high/max — **medium 이 없다**. 그래서 중립 `ReasoningEffort` 에 `none`·`max` 를 더하고 값 검증은 하지 않는다(모델마다 다르고, 좁히면 모델이 늘 때마다 고쳐야 한다).

## 검증

`swift build --package-path Tools` 경고 0, `swift test --package-path Tools` **135개 통과**(직전 69개 — 공급자 계약·`.env`·모델 선택·error_type 분류가 늘었다). `Packages/LearnKit` **607개 그대로**.

**실왕복 1회 성공** — `lessongen outline --language python --lessons 3 --max-tokens 8000 --verbose`. 모델 `z-ai/glm-5.3-flash`, 실제 서빙 업스트림 `Reka`, `finish=stop`, in 817 / out 829(reasoning 73) / cached 0, 비용 $0.000537. 구조화 출력이 첫 시도에 스키마를 만족했고 조립·검증까지 통과해 3레슨 개요가 나왔다. 루프백 서버 왕복 4건(헤더 전송, 429→503→200 백오프, 200 안의 오류, 연결 거부)은 그대로 유지했다 — 크레딧을 쓰지 않는 반복 검증은 계속 그쪽이다.

키 유출 검사: 워크트리와 임시 디렉터리 전체를 실제 키 리터럴로 grep 해 **0건**. `Redactor` 접두사를 `sk-or-`/`sk-ant-`/`sk-proj-` 로 넓혔고 `.env` 는 커밋되지 않는다(예시 파일만 커밋).

## 메모

`{#lessongen-batch-fanout}` 의 전제였던 "Batch 50% 할인" 은 OpenRouter 에도 있다 — `POST /api/beta/batches`, 24h 창, 통상 표준 단가의 50%, `:batch` 모델 변종. 그런데 **우리 모델에는 이득이 없다**: `z-ai/glm-5.3-flash` 표준 엔드포인트에 현재 `discount: 0.5` 프로모션이 걸려 $0.075/M 인데 `:batch` 변종은 $0.15/M — 정가 그대로다. `:batch` 변종은 `seed` 도 지원하지 않는다. 유료 모델에는 문서화된 RPS·동시성 상한이 없다(무료 변종만 20 RPM). 결론: **동시성 제한 병렬 요청**으로 간다.

`{#lessongen-runlog}` 의 "재현 불가" 전제는 무너졌다 — 이 모델은 `temperature`·`seed` 를 받는다. 다만 재현의 진짜 변수는 시드가 아니라 **어느 업스트림이 답했는가**다(양자화가 fp4/fp8 로 갈린다). 그래서 응답의 `provider` 를 붙잡아 `CompletionResponse.upstreamProvider` 로 남기고, `generatorModel` 에도 요청값이 아니라 **응답이 말한 모델**을 적는다.

`{#lessongen-prompt-caching}` 은 공급자별로 갈린다. 이 모델은 **자동 캐싱**이고 캐시 쓰기 웃돈이 없으며 읽기가 입력 단가의 0.2배다 — `cache_control` 을 붙일 필요가 없다(Anthropic 계열만 명시 경계가 필요해서 `PromptCachingMode` 로 둘 다 표현할 수 있게 뒀다). 대신 캐시가 **업스트림에 붙어 있어서** 라우터가 매번 다른 곳을 고르면 접두사를 아무리 잘 잡아도 차갑다. `session_id`(캐시 친화 라우팅 키) 를 요청에 실을 수 있게 했으나 CLI 는 아직 넘기지 않는다.