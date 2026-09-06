---
schema_version: 1
type: feature
slug: "tools-package-and-lessongen-client"
status: done
difficulty: high
created_at: "2026-09-06T18:26:47+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Package.swift"
    op: create
  - path: "Tools/Package.resolved"
    op: create
  - path: "Tools/Sources/AnthropicKit/APIKey.swift"
    op: create
  - path: "Tools/Sources/AnthropicKit/Redaction.swift"
    op: create
  - path: "Tools/Sources/AnthropicKit/AnthropicClient.swift"
    op: create
  - path: "Tools/Sources/AnthropicKit/RequestBuilder.swift"
    op: create
  - path: "Tools/Sources/AnthropicKit/ResponseParser.swift"
    op: create
  - path: "Tools/Sources/AnthropicKit/RetryPolicy.swift"
    op: create
  - path: "Tools/Sources/LessonGenKit/OutlineGenerator.swift"
    op: create
  - path: "Tools/Sources/LessonGenKit/OutlineAssembler.swift"
    op: create
  - path: "Tools/Sources/LessonGenKit/OutlineValidator.swift"
    op: create
  - path: "Tools/Sources/lessongen/OutlineCommand.swift"
    op: create
  - path: "Tools/Sources/packtool/main.swift"
    op: create
  - path: "Tools/Tests/AnthropicKitTests/APIKeyHandlingTests.swift"
    op: create
  - path: "Tools/Tests/AnthropicKitTests/LoopbackRoundTripTests.swift"
    op: create
  - path: "Tools/Tests/TestSupport/LoopbackHTTPServer.swift"
    op: create
related: []
tags:
  - "tools"
  - "lessongen"
  - "anthropic"
  - "spm"
  - "api-key"
  - "mcp-tool"
---
[x] Tools 패키지 신설과 lessongen 의 Anthropic HTTP 클라이언트

## 추가 기능

앱과 분리된 최상위 SPM 패키지 `Tools` 를 세우고 `Packages/LearnKit` 을 path 의존으로 붙였다. 분리하는 이유는 하나다 — `swift-argument-parser` 가 앱 산출물에 링크되지 않게 하기 위해서다. 의존 방향은 Tools → LearnKit 단방향이고 LearnKit 은 한 줄도 건드리지 않았다.

- `{#tools-package}` — 실행 파일 둘. `lessongen` 은 ArgumentParser 를 쓰고, `packtool` 은 사용법만 출력하는 스텁이라 의존성이 비어 있다 (실구현은 `{#packtool-*}` 로 다른 작업). ArgumentParser 는 최신 안정 1.8.2 로 핀하고 `Package.resolved` 를 커밋했다.
- `{#lessongen-http-client}` — Swift 공식 SDK 가 없어 `URLSession` 으로 `/v1/messages` 를 직접 친다. 429·529·5xx·전송 오류에 지수 백오프, `retry-after` 우선. Batch 엔드포인트와 `cache_control` 자리를 미리 남겼다.
- `{#api-key-handling}` — 키는 `ANTHROPIC_API_KEY` 하나에서만 읽는다.
- `{#lessongen-outline}` — 구조화 출력 1회로 트랙 개요를 뽑아 `tracks/<lang>.outline.json` 으로 쓴다.

## 동작 흐름

`lessongen outline --language python` → 환경변수에서 키 읽기(없으면 네트워크 전에 안내하고 종료) → 고정 시스템 프롬프트 + 트랙별 사용자 메시지 조립 → `output_config.format` 에 JSON Schema 를 실어 1회 호출 → 초안(`OutlineDraft`)을 받아 **Swift 가** `stableID`·순번·선수 관계를 조립(`OutlineAssembler`) → 구조 검증(`OutlineValidator`) → 파일 쓰기에서 멈춤. 자동 커밋하지 않는다.

설계에서 갈린 지점 넷.

1. **모델에게 산출물 형태를 시키지 않는다.** 모델은 슬러그·제목·목표 같은 데이터만 내놓고 `stableID` 조립은 코드가 한다 — `{#lessongen-lesson}` 의 "마크다운을 시키지 않는다" 와 같은 규율이다.
2. **stableID 에 순번을 넣지 않는다.** 넣으면 레슨 하나를 중간에 끼울 때마다 뒤쪽 ID 가 전부 개명되고 진도가 고아가 된다. 순서는 `ordinal` 로 따로 뒀다.
3. **`.convertToSnakeCase` 를 쓰지 않는다.** 동적 키까지 변환돼 JSON Schema 의 `additionalProperties` 가 `additional_properties` 로 망가진다. 와이어 키는 전부 손으로 적고 회귀 테스트로 못 박았다.
4. **모델 선택.** Opus 5 는 `temperature`·`top_p` 가 400 이라 시드로 생성물을 재현할 수 없다. `{#lessongen-runlog}` 이 재현성을 감사 로그로 대체해야 하는 근거가 여기 있다. `budget_tokens` 도 400 이라 사고 깊이는 `output_config.effort` 로만 조절한다.

키 취급은 타입 차원에서 막았다. `APIKey` 는 `Codable` 을 일부러 채택하지 않아 설정 파일에 실릴 수 없고, `description` 이 자리표시자를 돌려주며, 클라이언트가 어떤 로그 sink 를 받든 `RedactingLog` 로 감싸 들고 있어 우회 경로가 없다. 알고 있는 키의 정확한 일치뿐 아니라 `sk-ant-` 로 시작하는 모르는 토큰까지 함께 가린다.

## 검증

`swift build --package-path Tools` 경고 0 (클린 빌드), `swift test --package-path Tools` 69개 통과. 그중 3개는 로컬 루프백 HTTP 서버를 띄워 `URLSession` 으로 실제 소켓 왕복을 태운 것이다 — 헤더 4종이 전선에 그대로 실리고 진짜 429 → 529 → 200 이 재시도 루프를 움직이는 것까지 확인했다. 키 유출은 가짜 키를 주입해 실행 로그 전수를 훑는 방식으로 0건을 못 박았다(로그가 비어서 0건인 것이 아님을 먼저 확인한다). `Packages/LearnKit` 476개 테스트 그대로 통과.

**실제 Anthropic 엔드포인트 왕복은 하지 못했다** — 이 환경에 `ANTHROPIC_API_KEY` 가 없고 `ant` CLI 도 없다. 키를 가진 사람이 `lessongen outline --language python --verbose` 로 한 번 태워 봐야 `{#lessongen-http-client}` 의 "왕복 1회 성공" 이 실제로 닫힌다.

## 메모

`nm` 으로 확인한 링크 결과 — `packtool` 의 ArgumentParser 심볼 0건, `lessongen` 15856건. LearnKit 의존 그래프에도 argument-parser 가 없다. 이 경계는 `PackagingTests` 가 지킨다.