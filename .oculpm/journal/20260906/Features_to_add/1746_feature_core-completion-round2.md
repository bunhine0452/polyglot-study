---
schema_version: 1
type: feature
slug: "core-completion-round2"
status: done
difficulty: superhigh
created_at: "2026-09-06T17:46:16+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/learn-launcher/main.c"
    op: update
  - path: "Packages/LearnKit/Sources/LanguageKit/CodeRunner.swift"
    op: update
  - path: "Packages/LearnKit/Sources/LearnCore/Execution"
    op: create
  - path: "Packages/LearnKit/Sources/LearnPersistence/Migrations/M006CardStateScheduling.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Persistence/DueQueue.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnScheduling/CardStateRebuilder.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnScheduling/DueQueueWiring.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Sandbox"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/ToolchainMemoryTests.swift"
    op: correct
  - path: "Packages/LearnKit/Tests/RunnerKitTests/SQLResultDiffTests.swift"
    op: correct
related:
  - ref: "20260906/Features_to_add/1533_feature_parallel-core-implementation.md"
    kind: "followup"
  - ref: "20260906/Refactors/1530_refactor_unify-learncore-domain-types.md"
    kind: "followup"
tags:
  - "parallel"
  - "runner"
  - "sandbox"
  - "fsrs"
  - "orchestration"
  - "flake"
  - "mcp-tool"
---
[x] polyglot-core 완주 — 계약 개정·마이그레이션 006·서브프로세스 러너·샌드박스·재구축 배선

Opus 5 세션 5개를 2라운드로 나눠 돌려 `polyglot-core` 를 **53/55** 까지 끌어올렸다. `swift build` 경고 0, `swift test` **475개 / 57 스위트**, 6회 반복 전부 초록.

## 추가 기능

**1라운드** — `CodeRunner` 계약 개정 8건(`RunEvent.resultSet`, `finished(RunTermination)`, `RunRequest.resources`, `EnforcedLimits`, `fileSizeBytes`/`fileSizeExceeded`, `Equatable`, `unsupported(path:version:minimum:)`)과 마이그레이션 006 + due 큐.

**2라운드** — 서브프로세스 러너와 Swift·Python 어댑터, `sandbox-exec` 격리 프로파일, `card_state` 재구축 배선.

## 동작 흐름

지난 라운드의 실패(공유 도메인 타입을 두 세션이 각자 정의)를 되풀이하지 않기 위해 **계약을 먼저 확정하고 그 위에서 병렬화**했다. `ResultSet` 은 필드까지 명시해 넘겨 각자 정의할 여지를 없앴다. 5개 세션 전부 git 충돌 0 으로 병합됐고, 이번에는 타입 중복도 없었다.

## 붙였을 때만 드러난 결함 세 가지

**재구축이 수렴하지 않았다.** 순수 리플레이의 `derivedFromLogID` 는 *적용된* 마지막 행인데 `.cram` 은 기록만 되고 스케줄에 반영되지 않는다. 그래서 cram 으로 끝난 카드는 `card_state_stale.log_drift` 가 영영 걷히지 않고 무한히 stale 로 남는다 — 골든 40장 중 7장. 스왑 직전에만 진짜 `MAX(id)` 로 워터마크를 덮어 해결했다. 스케줄링의 replay 와 영속화의 stale 뷰가 각각은 옳은데 이었을 때만 깨지는 종류다.

**런처가 자식 종료를 놓쳤다.** `NOTE_EXIT` 은 유실될 수 있다 — 부모가 `proc_listpids`/`proc_pid_rusage` 로 같은 그룹을 폴링하는 동안(메모리 상한 감시) 알림이 도착하지 않는다. 그런데 대기 루프가 `kevent` 를 `remaining` 전체(최대 wall 초)만큼 재워서 `waitpid(WNOHANG)` 가 그동안 한 번도 다시 돌지 않았다. 실행당 3% 안팎, 30ms 짜리가 30초로 관측됐다. `kevent` 타임아웃을 100ms 로 끊었다 — 무제한 분기는 이미 1초로 같은 일을 하고 있었고 유한 분기만 빠져 있었다.

**`/usr/bin/swiftc`·`/usr/bin/python3` 는 xcrun 셰이더다.** 샌드박스 아래서 xcrun 캐시 쓰기가 거부돼 stderr 가 오염되고, 진단 파서가 그 줄을 진단으로 오인할 수 있다. 프로파일을 열어 허용하는 건 탈출구다 — 캐시를 쓸 수 있으면 샌드박스 밖의 나중 `xcrun` 호출을 바꿔치기할 수 있다. `xcrun --find` 로 해석한 실제 경로를 실행하는 것으로 풀었다.

## 실측으로 확정한 것들

- `--event-stream-output-path` 는 `swift test --help` 에 없지만 **실재한다**(Swift 6.3.3 / Testing 1902). 병렬 실행이라 줄 순서가 섞이므로 시간은 `instant.absolute` 차로 재야 한다. 채점 1회 0.7~0.9초.
- SBPL 규칙 경로는 반드시 `realpath(3)`. `/var/folders/...` 를 그대로 넣으면 규칙이 아무것도 매치하지 않아 **워크스페이스 쓰기까지 거부**된다. Foundation 의 `resolvingSymlinksInPath` 는 realpath 가 아니라 `/private` 를 오히려 떼어낸다.
- SBPL 은 마지막 매치가 이긴다 → 민감 경로 `deny` 는 `allow` 뒤에.
- CPython 은 시작 시 `SIGXFSZ` 를 `SIG_IGN` 으로 덮는다 — 파일 크기 상한은 정상 작동하지만 시그널이 아니라 `OSError: Errno 27` 로 끝난다.
- `python3 -I` 는 `-P` 를 포함해 스크립트 디렉터리를 `sys.path` 에 넣지 않는다.

## 검증

`swift test` 475개, 6회 반복 무실패. 런처 수정 효과가 시간에 드러난다 — 전체 스위트 중앙값 **27초 → 21초**, 편차 6.9초 → 5.0초.

플레이크 두 개를 잡았다. 프로세스 그룹 메모리 테스트가 합계와 자기 사용량을 다른 시점에 재고 `total >= own` 을 단언하고 있었는데, 두 샘플 사이에 병렬 테스트가 148KB 를 해제하면 깨진다(4~9회당 1회). 합계 측정을 자기 값 둘로 감싸 하한과 비교하도록 고쳤다. SQLResultDiff 벤치마크의 100ms 예산도 1초로 완화했다 — 유휴 22ms / 부하 만재 111~127ms 라 CI 에서 반드시 깨진다. 이 테스트가 지키는 것은 "상한이 걸려 결과가 유한하다" 이지 절대 속도가 아니다.

## 메모

남은 2개는 표시만 안 된 것이라 이 일지 직후 갱신한다. `LearnPersistenceTests` 가 `CardStateRebuilder` 를 링크하지 못해 E2E 절반이 스텁 스케줄러로 도는 제약이 남아 있다 — 테스트 타깃에 의존성 한 줄이면 합쳐진다.