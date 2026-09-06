---
schema_version: 1
type: feature
slug: "openrouter-upstream-pin"
status: done
difficulty: medium
created_at: "2026-09-07T06:56:08+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/OpenRouterKit/UpstreamPin.swift"
    op: create
  - path: "Tools/Sources/OpenRouterKit/OpenRouterWireRequest.swift"
    op: update
  - path: "Tools/Sources/OpenRouterKit/OpenRouterRequestBuilder.swift"
    op: update
  - path: "Tools/Sources/OpenRouterKit/OpenRouterProvider.swift"
    op: update
  - path: "Tools/Sources/lessongen/GenerationOptions.swift"
    op: update
  - path: "Tools/Sources/LessonGenKit/RunLog/RunRecords.swift"
    op: update
  - path: "Tools/Sources/LessonGenKit/RunLog/RunLog.swift"
    op: update
  - path: "Tools/Tests/OpenRouterKitTests/OpenRouterRequestBuilderTests.swift"
    op: update
  - path: "Tools/Tests/LessonGenKitTests/RunLogTests.swift"
    op: update
related:
  - ref: "20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md"
    kind: "followup"
tags:
  - "lessongen"
  - "openrouter"
  - "prompt-caching"
  - "routing"
  - "mcp-tool"
---
[x] 업스트림 고정 — session_id 는 힌트였고 캐시에는 제약이 필요했다

막혀 있던 `{#lessongen-prompt-caching}` 을 다음 수로 옮긴다. **항목 자체는 아직 막힘이다** — 완료 기준은 실왕복 측정으로만 닫힌다.

## 추가 기능

`--provider <이름>`(반복 가능, 우선순위 순)과 `--allow-provider-fallback`. `provider.order` + `provider.allow_fallbacks` 로 나간다.

`only`(허용 목록)를 쓰지 않은 이유는 표현력이다 — `allow_fallbacks: false` 면 `only` 와 같은 하드 제약이 되고 `true` 면 "이쪽을 먼저, 없으면 아무 데나"가 된다. `only` 로는 뒤쪽을 표현할 수 없다.

## 동작 흐름

지난 실행에서 같은 `session_id` 로 7회를 보냈는데 업스트림이 NextBit·Wafer·Reka 로 갈렸고 `cached_tokens` 가 매번 0 이었다. 프롬프트 캐시는 **업스트림에 붙어 있으므로**, 고정 시스템 프롬프트를 아무리 잘 잡아도 라우터가 매번 다른 곳을 고르면 캐시는 차갑다. `session_id` 는 라우터에게 주는 **힌트**였고, 필요한 것은 **제약**이었다.

**`allow_fallbacks` 기본값을 `false` 로 둔 것은 의도다.** 고정을 요청해 놓고 조용히 다른 업스트림으로 새면 캐시는 차가운데 요청은 성공해서 *고정이 실패한 줄 아무도 모른다.* 차라리 실패하는 편이 낫다. 같은 이유로 실행 로그 결산이 "고정 지켜짐"과 "**고정이 새었다** — 실제로 답한 곳에 X 가 섞였다"를 갈라 찍는다. 새어 나간 실행의 캐시 수치는 아무것도 증명하지 못한다.

라우팅 블록 방출 조건도 고쳤다. 예전에는 "요구한 파라미터가 있을 때만"이었는데(값싼 업스트림을 이유 없이 버리지 않으려고), 고정은 캐시가 목적이라 파라미터와 무관하게 언제나 의미가 있다. 두 조건을 OR 로 바꾸고, 좁힐 파라미터가 없으면 `require_parameters` 는 켜지 않은 채 `order` 만 내보낸다.

이름을 추측해 적으면 `allow_fallbacks` 가 꺼진 채 요청이 통째로 실패한다. `run.json` 의 `upstreamProviders` 가 실제로 답한 이름을 들고 있으니 **한 번 돌려 보고 그 이름을 고정하는 것이 순서**다.

## 검증

Tools 300 → 309 테스트, 빌드 경고 0. LearnKit 무변.

`--dry-run` 으로 실제 요청 본문을 찍어 확인했다 (크레딧 0):

- 고정 없이 → `{"require_parameters": true}` (기존 동작 그대로)
- `--provider NextBit --provider Wafer` → `{"allow_fallbacks": false, "order": ["NextBit","Wafer"], "require_parameters": true}`
- `+ --allow-provider-fallback` → `{"allow_fallbacks": true, ...}`
- `--allow-provider-fallback` 만 주면 사용법 오류로 거부

## 메모

닫으려면 실왕복 2회 이상이 필요하다 — 한 번 돌려 `upstreamProviders` 를 읽고, 그 이름으로 고정해 다시 돌려 `cached_tokens` 가 0 이 아닌지 본다. 크레딧이 나가므로 사용자 승인 전까지 멈춘다.