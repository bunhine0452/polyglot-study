---
schema_version: 1
type: refactor
slug: "unify-learncore-domain-types"
status: done
difficulty: high
created_at: "2026-09-06T15:30:10+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/LearnCore/Review/CardStateSnapshot.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Review/ReviewLogEntry.swift"
    op: rename
  - path: "Packages/LearnKit/Sources/LearnCore/Review/ReviewRating.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Review/EpochMillis.swift"
    op: rename
  - path: "Packages/LearnKit/Sources/LearnCore/Review/CardSchedulingState.swift"
    op: rename
  - path: "Packages/LearnKit/Sources/LearnCore/Review/SchedulerParameterSet.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnPersistence/Rows/DomainColumns.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnPersistence/Rows/ReviewRows.swift"
    op: update
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: "Packages/LearnKit/Tests/LearnSchedulingTests/Fixtures/golden-review-log.jsonl"
    op: update
related: []
tags:
  - "learncore"
  - "learnpersistence"
  - "learnscheduling"
  - "merge-conflict"
  - "domain-model"
  - "mcp-tool"
---
[x] LearnCore 도메인 타입 두 벌을 한 벌로 통합 (Review/ 신설)

## 동기

병렬 4세션 병합 후 `LearnCore` 안에 같은 개념이 두 벌 생겨 `swift build` 가
`ReviewLogEntry.swift.o` multiple producers 로 실패했다. basename 충돌은 증상이고,
진짜 문제는 `Persistence/` 와 `Scheduling/` 이 같은 개념을 각자 정의한 것.

## 변경 요약

- 공유 도메인 타입을 새 디렉터리 `Sources/LearnCore/Review/` 로 이동 —
  `EpochMillis` / `ReviewRating` / `CardPhase` / `ReviewLogSource` /
  `ReviewLogEntry` / `SchedulerParameterSet` / `CardSchedulingState` /
  `CardStateSnapshot`. `Persistence/` 에는 저장 고유의 것만, `Scheduling/` 에는
  스케줄러 고유의 것만 남겼다 (다음 병렬 작업의 재충돌 방지).
- 시각을 `EpochMillis`(struct) 로 통일, `typealias EpochMilliseconds = Int64` 제거.
- 학습 단계는 `CardPhase`(Int 0–3) 하나. DB 컬럼은 TEXT 유지 — 정수↔TEXT 변환은
  새 파일 `LearnPersistence/Rows/DomainColumns.swift` 가 전담. 골든 스키마 불변.
- `ReviewLogSource` 는 review/cram/manual/imported 합집합. 출시된 CHECK
  리터럴(`'scheduled'`·`'import'`) 스펠링도 같은 매핑 계층이 흡수.
- `CardStateSnapshot` 이 `CardSchedulingState` 를 합성하도록 정리 (필드 중복 제거).
- `Package.swift` 경고 2건 제거, 스케줄링 픽스처 로딩을 `Bundle.module` 로 전환.
- `GradeResult.Presenter` 에 `CaseIterable` 추가.
- `RunFailure.cpuExceeded` 를 다루지 않던 스위치 2곳 보강 (병합 시 누락분).

## 드러난 설계 불일치

1. `card_state` 에 `elapsed_days`·`learning_step_index` 컬럼이 없어 스케줄링 상태의
   두 필드가 저장에서 유실된다. 캐시에서 되살린 상태로 다음 리뷰를 스케줄하면
   학습 스텝이 되감긴다 → 회귀 테스트로 못박음.
2. 로그 출처 스펠링이 두 세션에서 달랐다 (`scheduled`/`import` vs `review`/`imported`).
3. `review_duration_ms` 가 한쪽은 `Int?`, 한쪽은 `Int`. 컬럼이 NOT NULL 이라 `Int` 승.
4. `EpochMillis` 에 `DatabaseValueConvertible` 을 붙이는 계획은 **불가능**했다 —
   public 타입의 준수는 public 이고 SE-0409 가 `public import GRDB` 를 요구하는데
   그건 `{#grdb-pin}` 금지 사항. 명시적 `.sqlValue` 변환으로 대체.

## 검증

`swift build` 경고 0, `swift test` 316개 전부 통과. 통합 전 `@Test` 선언 315개 →
315개 + 신규 회귀 1개로 유실 없음. 골든 스키마 바이트 비교·append-only 트리거·
FSRS 참조 벡터·FuzzSeal·replay 100회 결정성·런처 실측 전부 그대로 초록.
골든 `card-state.json` 은 재생성 후에도 바이트 동일 — 스케줄링 동작 무변경 확인.