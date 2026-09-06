---
schema_version: 1
type: refactor
slug: "openrouter-provider-abstraction"
status: done
difficulty: high
created_at: "2026-09-06T19:55:17+09:00"
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
  - path: "Tools/Package.swift"
    op: update
  - path: ".gitignore"
    op: update
related:
  - ref: "20260906/Features_to_add/1847_feature_content-pipeline-foundation.md"
    kind: "followup"
tags:
  - "tools"
  - "openrouter"
  - "llm"
  - "secrets"
  - "mcp-tool"
---
[x] LLM 공급자 추상화와 OpenRouter 구현 — 실왕복 검증 완료

`lessongen` 의 LLM 백엔드를 Anthropic 직결에서 OpenRouter 로 바꾸고, 로컬 모델(MLX)이 나중에 같은 자리에 꽂히도록 공급자를 프로토콜 뒤로 밀었다. Tools **135개**(직전 69), LearnKit 607개 그대로, 빌드 경고 0.

## 동기

사용자가 `OPENROUTER_API_KEY` / `OPENROUTER_MODEL` 로 대체하기로 결정했다. 그리고 로컬 AI 과외 기능이 예정돼 있어, 공급자를 추상화하는 비용이 지금 가장 싸다.

## 변경 요약

`LLMKit`(프로토콜·`APIKey`·DotEnv·ModelSelection·RetryPolicy·ProviderContract)과 `OpenRouterKit`(구현) 두 타깃으로 갈랐다. `LanguageKit`(`CodeRunner`) ↔ `RunnerKit`(백엔드) 배치를 그대로 복제한 것이라 프로토콜 모듈에 공급자 와이어 타입이 0개다. 능력은 OptionSet 으로 런타임 조회하고, 미선언 능력을 요구하면 전선을 타기 전에 `.unsupported` 로 거절한다. 계약 스위트를 OpenRouter 와 FakeProvider 둘이 통과한다.

## 실왕복 검증 (1회)

`lessongen outline --language python --lessons 3` 이 구조화 출력을 **첫 시도에** 스키마대로 받았다.

```
model=z-ai/glm-5.3-flash  upstream=Reka  finish=stop
in=817  out=829 (reasoning 73)  cached=0  cost=$0.000537
```

비밀값 파일은 워크트리 밖 리포 루트에서 상향 탐색으로 찾았고, 로그에는 **출처만** 남고 값은 남지 않는다. 워크트리와 임시 디렉터리 전체를 실제 키 리터럴로 grep 해 0건을 확인했다.

## 실측으로 설계를 바꾼 것

**엔드포인트 룰렛이 가장 컸다.** `z-ai/glm-5.3-flash` 의 서빙 엔드포인트 23곳 중 **6곳(Z.AI 자사 포함)이 `structured_outputs` 를 지원하지 않고**, 9곳은 `seed` 를 지원하지 않는다. OpenRouter 는 미지원 파라미터를 **조용히 버리기 때문에**, 라우팅을 좁히지 않으면 200 응답과 함께 스키마가 아닌 산문이 온다. `provider.require_parameters` 를 구조화 출력·시드 요청에 붙이고, 그 옵션을 끄면 `structuredOutputs` 능력 선언도 함께 빠지도록 묶었다.

- **오류가 HTTP 200 에 실려 온다.** 재시도 판정의 1차 근거를 상태 코드에서 `error.metadata.error_type` 으로 옮겼다.
- `usage: {include:true}` 는 폐기됐고 usage/cost 는 항상 실린다. 죽은 필드가 캐시 접두사를 흔들지 않도록 제거했다.
- 정식 헤더는 `X-OpenRouter-Title` 이다 (`X-Title` 은 별칭).
- 이 모델은 사고가 필수이고 지원 effort 는 `low/high/max` — **medium 이 없다.**
- **CRLF 함정**: Swift 에서 `"\r\n"` 은 Character 하나라 `split(separator: "\n")` 이 CRLF 줄을 뭉친다. `whereSeparator: \.isNewline` 으로 고치고 테스트로 고정했다.

## 설계 근거가 무너진 항목 셋의 재판단

- **`{#lessongen-batch-fanout}`** — OpenRouter 에 Batch 는 있다(24h, 통상 50%). 그런데 이 모델엔 이득이 없다: 표준 엔드포인트에 프로모션 할인이 걸려 $0.075/M 인데 `:batch` 변종은 $0.15/M, 즉 **정가**다. `:batch` 는 `seed` 도 미지원. → **동시성 제한 병렬 요청**으로 교체.
- **`{#lessongen-runlog}`** — temperature·seed 를 둘 다 받으므로 재현을 다시 목표로 삼는다. 다만 **진짜 변수는 시드가 아니라 어느 업스트림이 답했는가**다(fp4/fp8 양자화가 갈린다). `upstreamProvider` 를 응답에서 붙잡고 `generatorModel` 에 요청값이 아니라 **응답이 말한 모델**을 적는다.
- **`{#lessongen-prompt-caching}`** — 이 모델은 자동 캐싱(쓰기 무료, 읽기 0.2배)이라 명시 경계가 불필요하다. 진짜 조건은 **캐시가 업스트림에 붙어 있다**는 것이라, `session_id` 로 라우팅을 고정하지 않으면 접두사를 잘 잡아도 매번 차갑다.

## 단계별 모델 오버라이드

`OPENROUTER_MODEL_{OUTLINE,LESSON,PROSE,REPAIR}`. 나누는 기준은 **자동 검증 게이트의 유무**다 — lesson/repair 는 `packtool` 이 실행으로 검증하고, outline 은 사람이 리뷰하며, **prose 는 아무도 검증하지 않는다.** 값싼 모델이 코드를 틀리면 게이트가 잡지만 개념 설명이 틀리면 그대로 학습자에게 간다. 배선과 로그만 넣고 분리 생성 지점은 주석으로 남겼다.

## 검증

Tools 135개 통과, LearnKit 607개 무변. 저장소 전체를 실키 형태(`sk-or-v1-…`, `sk-ant-api…`)로 스캔해 플레이스홀더 외 0건을 확인했다. `Redactor` 접두사는 `sk-or-`/`sk-ant-`/`sk-proj-` 셋이다. 병합 시 `.gitignore` 충돌 1건(주석 문구 차이)을 해소했다.

## 메모

`{#lessongen-lesson}` 의 "첫 시도에 구조·문법 단계 통과"는 이 모델 등급에서 현실적이다 — 스키마와 파서가 강제하고 구조화 출력이 대부분 보장한다. 그러나 **`{#packtool-execution}` 의 실행 게이트(solution 통과 + starter 실패)를 첫 시도에 통과하는 것은 낙관적**이다. "starter 가 이미 통과하는 무의미한 과제"는 값싼 모델의 전형적 실패라, repair 루프가 선택이 아니라 전제다.

로컬 MLX 가 이 프로토콜에 꽂힐 때 부족할 지점 넷을 보고받았다: `stream()` 이 종이 위에만 있음, 모델 적재 수명주기 부재, `TokenUsage` 에 벽시계·tok/s 자리 없음, `ProviderContract` 의 해피패스가 실제 추론을 요구해 skip 선언 축이 필요함.