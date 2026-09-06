---
schema_version: 1
type: feature
slug: "lessongen-lesson-and-repair-loop"
status: done
difficulty: high
created_at: "2026-09-07T06:16:10+09:00"
session_id: "20260907-001"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/LessonGenKit/Lesson"
    op: create
  - path: "Tools/Sources/LessonGenKit/Repair"
    op: create
  - path: "Tools/Sources/LessonGenKit/RunLog"
    op: create
  - path: "Tools/Sources/LessonGenKit/Fanout/BoundedFanout.swift"
    op: create
  - path: "Tools/Sources/lessongen/LessonCommand.swift"
    op: create
  - path: "Tools/Sources/lessongen/RepairCommand.swift"
    op: create
  - path: "Tools/Tests/LessonGenKitTests"
    op: update
related:
  - ref: "20260906/Refactors/1955_refactor_openrouter-provider-abstraction.md"
    kind: "followup"
tags:
  - "lessongen"
  - "llm"
  - "openrouter"
  - "content-pack"
  - "parallel"
  - "backfill"
  - "mcp-tool"
---
[x] lessongen 레슨 생성과 수리 루프 — 마크다운은 모델이 아니라 코드가 쓴다

지난 세션 커밋(`487ba80`)의 소급 기록. 이 커밋으로 **생성 → 검증 → 수리 → 통과 루프가 처음으로 닫혔다.**

## 추가 기능

레슨을 JSON 으로 받아 **Swift 코드가** 디렉티브 마크다운으로 직렬화한다. 모델에게 마크다운을 시키지 않는 이유는 둘이다 — 문법이 바뀌어도 프롬프트가 아니라 코드 수정으로 끝나고, swift-markdown 의 인자 문자셋 제약(콜론·괄호·따옴표 불가)을 코드가 지킬 수 있다. 경로 인자는 `stableID` 에서 유도하므로 **모델이 한 글자도 만들지 않는다.**

- `LessonSerializer.serializeChecked` 가 구운 결과를 곧바로 `LessonParser` 에 태우고, `PackWriter.verify` 가 쓴 팩을 `ContentPack` 으로 다시 연다 — packtool 의 구조·문법 단계와 **같은 코드**다. 디스크에 놓인 레슨은 이미 그 두 단계를 지난 것이다.
- 팬아웃은 동시성 제한 병렬 요청(`BoundedFanout`). 현 모델의 `:batch` 변종이 프로모션가의 2배이고 seed 를 받지 않아 Batch 엔드포인트를 쓰지 않는다.
- `repair` 는 `PackValidationReport` 를 읽어 실패 레슨만 재생성한다. `Failure.evidence` 를 요약 없이 프롬프트에 싣고 `Failure.Kind` 로 지시를 가른다 — `starterAlreadyPasses` 는 "과제를 어렵게" 가 아니라 **"starter 에서 정답을 걷어 내라"** 이고, 테스트·solution 은 건드리지 못하게 막는다.
- 3회 실패 시 격리: 레슨과 사이드카를 팩에서 지우고 명단과 함께 non-zero 종료. 시도 장부는 실행을 넘어 이어진다.
- 실행별 디렉터리에 요청·응답·usage·업스트림·generation id 를 남기고 `--max-usd` 를 넘으면 새 요청을 시작하지 않는다.

## 동작 흐름

시스템 프롬프트는 **세 언어 하네스 계약을 전부 담은 고정 접두사**다. 언어마다 다른 시스템 프롬프트를 쓰면 트랙이 바뀔 때마다 캐시가 차가워지고 접두사가 짧아져 아낄 것도 줄어든다. 수리도 같은 접두사 뒤에 지시문을 덧붙인다.

실측 둘이 코드에 반영됐다. **구조화 출력을 걸어도 스키마를 만족한 객체 뒤에 중괄호가 하나 더 붙어 오는 응답이 있다** — 균형 잡힌 첫 객체만 도려낸다(`JSONExtraction`). 그리고 **`session_id` 를 보내도 업스트림이 NextBit·Wafer·Reka 로 갈려 캐시가 매번 차가웠다.** 이건 못 고쳤고, 대신 실행 로그 결산이 "프롬프트 캐시 적중 없음" 과 갈린 업스트림 목록을 직접 찍는다 — `{#lessongen-prompt-caching}` 은 이 사유로 막힘 처리한다.

## 검증

`swift test --package-path Tools` 267 테스트 통과. 실왕복 7회 $0.0121 로 레슨 생성·수리가 실제 모델에서 돌았고, 산출된 `Content/packs/polyglot-mvp` 가 `packtool validate` 를 실패 0건으로 통과한다.