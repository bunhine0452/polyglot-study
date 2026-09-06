---
schema_version: 1
type: feature
slug: "parallel-core-implementation"
status: done
difficulty: superhigh
created_at: "2026-09-06T15:33:31+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: "Packages/LearnKit/Package.resolved"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Review"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Persistence"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Scheduling"
    op: create
  - path: "Packages/LearnKit/Sources/LearnPersistence"
    op: create
  - path: "Packages/LearnKit/Sources/LearnScheduling"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit"
    op: create
  - path: "Packages/LearnKit/Sources/learn-launcher/main.c"
    op: update
  - path: "Packages/LearnKit/Sources/LanguageKit/CodeRunner.swift"
    op: update
  - path: "Packages/LearnKit/Tests"
    op: create
  - path: ".gitignore"
    op: update
related:
  - ref: "20260906/Chores/1417_chore_promote-research-to-planner.md"
    kind: "followup"
  - ref: "20260906/Features_to_add/1319_feature_learnkit-core-scaffold.md"
    kind: "followup"
tags:
  - "parallel"
  - "swift"
  - "grdb"
  - "fsrs"
  - "runner"
  - "orchestration"
  - "mcp-tool"
---
[x] Opus 5 병렬 세션 4개로 코어 4계층 구현 — 영속화·스케줄링·런처·SQL 러너

플랜 `polyglot-core` 의 4개 페이즈를 Opus 5 서브에이전트 4개에 나눠 병렬로 구현하고 병합했다. 최종 `swift build` 경고 0, `swift test` **316개 / 37 스위트 전부 통과**.

## 추가 기능

- **LearnPersistence** — GRDB 7.11.1, 마이그레이션 001~005(`review_log`·`card_state`·`submission`/`diagnostic`·`mistake_note`+FTS5·`lesson_progress`), 리포지토리 5종 + 인메모리 페이크.
- **LearnScheduling** — FSRS-6 벤더링(커밋 `4fbaf20`, 11파일 2,092줄), `ReviewScheduler` 프로토콜, 순수 `replay`, 참조 벡터 테스트.
- **learn-launcher + RunnerKit/Toolchain** — C 런처(`fork` → 자식이 `setsid` → `setrlimit` → `execv`, 부모는 `killpg`), 로그인 PATH 수확, 툴체인 전수 열거 감지, 메모리 폴러.
- **RunnerKit/InProcess·Contract·Workspace** — SQLite 인프로세스 러너, 결과셋 비교 채점, diff, 백엔드 중립 계약 하네스.

## 동작 흐름

병렬 실행의 실패 지점 두 개를 착수 전에 제거했다. 여러 세션이 같은 `.build` 를 물면 SwiftPM 락이 충돌하고 `Package.swift` 는 모두가 고치고 싶어 하는 파일이라, **타깃 선언과 의존성을 먼저 확정해 커밋한 뒤 각 세션을 독립 git 워크트리로** 띄웠다. 파일 소유권도 디렉터리 단위로 미리 잘랐고, `LanguageKit/CodeRunner.swift` 수정 권한과 플레이스홀더 삭제 권한은 세션당 하나씩만 배정했다.

결과적으로 **4개 브랜치가 git 충돌 0 으로 병합**됐다.

## 파티셔닝이 놓친 것

디렉터리를 갈라도 **같은 도메인 개념을 두 세션이 각자 정의**하는 것은 막지 못했다. 영속화와 스케줄링이 `ReviewLogEntry`·`ReviewRating` 을 각각 만들었고, 이름만 다른 의미 중복(`EpochMilliseconds`↔`EpochMillis`, `LearningState`↔`CardPhase`, `ReviewSource`↔`ReviewLogSource`)도 나왔다. git 은 서로 다른 경로의 새 파일이라 깨끗이 병합했지만 SwiftPM 이 basename 충돌로 빌드를 깼다.

**공유 도메인 타입은 파티셔닝 전에 부모가 정의해 넘겼어야 한다.** 다음 병렬 라운드에서 같은 일이 반복되지 않도록 공유 타입을 `Sources/LearnCore/Review/` 로 분리했다.

## 각 세션이 실측으로 잡은 것

- `fts5_version()` 은 SQLite 에 없다 (플랜 문구 오류). FTS5 가 등록하는 스칼라 함수는 `fts5_source_id()` 뿐이고, trigram 가용성은 `temp.` 가상 테이블을 실제로 만들어 확인해야 한다.
- `RLIMIT_NPROC` 은 프로세스 트리가 아니라 **실 uid 전체**를 센다. 절대값 16 을 걸면 데스크톱(457 프로세스)에서 `swiftc` 의 clang/ld 스폰부터 실패한다 → "현재 uid 수 + N" 으로 변경.
- `proc_listpids(..., NULL, 0)` 은 필터를 무시하고 시스템 전체 수를 돌려준다. 이걸 그대로 쓴 첫 구현이 fork bomb 을 338회 통과시켰다.
- `setsid` 를 런처가 부르면 `killpg` 가 런처 자신을 죽여 TIMEOUT 보고 주체가 사라진다 → 자식이 부르도록 반전.
- `sqlite3_hard_heap_limit64` 는 macOS SDK 헤더에 선언이 없다(dylib 심볼은 존재) → `dlsym` + `@convention(c)`.
- `sqlite3_error_offset()` 은 `no such table` 에 -1 을 준다 → 위치 없는 진단 경로 필수.
- 퍼즈를 켜면 벤더 시드가 `timeIntervalSince1970` 을 문자열로 찍어 서브밀리초가 잘리고, 실제로 다른 `scheduledDays` 가 나온다.

## 통합에서 드러난 진짜 설계 결함

`card_state` 가 알고리즘 상태를 전부 담지 못한다. `CardSchedulingState` 의 `elapsedDays` 와 `learningStepIndex` 에 대응하는 컬럼이 마이그레이션 002 에 없다 — 두 세션이 서로를 못 봐서 아무도 못 알아챘다. 저장 후 재로드한 상태로 `apply` 를 부르면 학습 단계 카드의 스텝 인덱스가 0 으로 되감긴다. 유실을 회귀 테스트로 못박아 뒀고, **"캐시가 아니라 `review_log` 리플레이가 정본"이 이제 취향이 아니라 필수**가 됐다. 마이그레이션 006 으로 두 컬럼을 추가할지는 별도 판단이 필요하다.

## 검증

`swift build` 경고 0, `swift test` 316개 통과(6.37초). 봉인 테스트 전부 생존 확인 — append-only 트리거, 골든 스키마 바이트 비교, GRDB 정책 grep(`public import GRDB` 0건 등), FSRS 참조 벡터, `FuzzSeal`, replay 100회 결정성, SQL 원본 DB 다이제스트 불변, 런처 실측(SIGXCPU·TIMEOUT·fork bomb·손자 프로세스·fd 3 위조 차단).

## 메모

`EpochMillis` 에 `DatabaseValueConvertible` 을 붙이려던 계획은 불가능했다. public 타입의 준수는 public 이 되고 SE-0409 가 `public import GRDB` 를 요구하는데, 그게 바로 정책 테스트가 0건을 강제하는 것이다. 명시적 `.sqlValue` / `init(sqlValue:)` 변환으로 처리했다.