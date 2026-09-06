---
schema_version: 1
type: feature
slug: "subprocess-runner-swift-python"
status: done
difficulty: high
created_at: "2026-09-06T17:35:13+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/SubprocessRunner.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/SubprocessProgram.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/SubprocessTermination.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/LauncherStatusChannel.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/OutputBudget.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/ProcessGroupReaper.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/LanguageToolchain.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/LanguageModules.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftProgram.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftDiagnosticParser.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftTestingGrader.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftTestingEventStream.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/PythonProgram.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/PythonUnittestHarness.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/PythonUnittestGrader.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/SubprocessRunnerSupport.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/SubprocessRunnerTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/LanguagePythonTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/LanguageSwiftTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/LanguageSwiftGradingTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/ContractSuiteBackendTests.swift"
    op: create
related: []
tags:
  - "runner"
  - "subprocess"
  - "swift"
  - "python"
  - "contract"
  - "mcp-tool"
---
[x] 서브프로세스 러너와 Swift·Python 언어 어댑터

## 추가 기능

- `SubprocessRunner` — swift-subprocess 1.0.0 의 클로저 폼 `run` 을 `AsyncThrowingStream<RunEvent>` 로 브리지. `learn-launcher` 를 반드시 거치고, 여섯 축 상한을 전부 강제한다(`EnforcedLimits.all`).
- `LauncherStatusChannel` — `PlatformOptions.preSpawnProcessConfigurator` 안에서 `posix_spawn_file_actions_adddup2` 로 status fd 3 을 배선. 테스트 하네스에만 있던 방식을 프로덕션으로 승격했다(원본 하네스 파일은 그대로 둠).
- `OutputBudget` — `.string(limit:)`/`.bytes(limit:)` 대신 `SubprocessOutputSequence.Buffer` 를 직접 세어 자른다. 상한 초과 후에도 파이프를 계속 비워 가짜 타임아웃을 막는다.
- `SubprocessRunOutcome` — `TerminationStatus` + 런처 status 라인 + 메모리 폴러 결과를 합쳐 `finished`/`wallClockExceeded`/`cpuExceeded`/`memoryExceeded`/`fileSizeExceeded`/`cancelled` 로 가른다. `SubprocessError` 는 `RunFailure.backend`(또는 `toolchainMissing`)로만 새어 나간다.
- Swift 어댑터 — `swiftc -diagnostic-style=llvm -no-color-diagnostics -print-diagnostic-groups` 출력을 `Diagnostic` 으로 정규화하고 진단 그룹을 `ruleID` 에 넣는다. 컴파일 실패는 예외가 아니라 `.finished(.failed)` 다.
- `SwiftTestingGrader` — 예열된 SwiftPM 템플릿에 제출·숨은 테스트만 갈아끼워 `swift test --event-stream-output-path <f> --event-stream-version 0` 로 JSON Lines 를 모은다. `--xunit-output` 폴백 포함.
- Python 어댑터 — `python3 -I -B <entry>`. 표준 `unittest` 위에 JSON Lines 리포터를 번들해 통과·실패·에러 3종을 가른다.
- `LanguageToolchain` — 버전 정책 감지 결과를 프로세스 수명 동안 캐시하고, `/usr/bin` 셰이더는 `xcrun --find` 로 해석한 실제 경로로 바꾼다.

## 동작 흐름

`run(request)` → `.phase(.preparing)` → 워크스페이스 생성 → `SubprocessProgram.prepare`(Swift 는 여기서 `.phase(.compiling)` + 진단) → `.phase(.running)` → 런처 스폰. 스폰 직후 status 파이프의 부모 쓰기 끝을 닫고 전용 스레드로 배수한다. 본문에서 stdin 쓰기·stdout 배수·stderr 배수 세 갈래를 한 태스크 그룹으로 동시에 돌리고, 그 옆에 메모리 폴러와 런처 깨우기 감시자를 둔다. 종료 후 status 라인·종료 상태·폴러 결과를 합쳐 사인을 정하고, 어느 경로로 나가든 `defer` 하나가 프로세스 그룹을 회수한다.

**실측으로 잡은 것 셋**

1. `swiftc` 에 JSON 진단이 없어 텍스트를 파싱한다. 사용자 파일 **끝**에 `import Foundation` 을 덧붙이면 줄 번호가 하나도 밀리지 않아 진단 보정이 필요 없다(중복 import 경고도 없음).
2. `--event-stream-output-path` 는 `swift test --help` 에 없지만 실재한다(Swift 6.3.3 / Testing 1902). 폴백 경로는 코드에 남겨 뒀다.
3. 메모리 폴러(`proc_listpids`/`proc_pid_rusage`)가 도는 동안 런처의 `EVFILT_PROC`/`NOTE_EXIT` 가 실행당 3% 안팎으로 도착하지 않아, 30ms 짜리 프로그램이 `--wall` 만큼(30초) 걸린 것으로 관측됐다. 종료 코드는 정확하고 지연만 생긴다. 근본 수정은 `main.c` 의 kevent 대기를 짧은 상한으로 자르는 것이라 이 세션 소관이 아니고, 여기서는 자식이 좀비가 되면 런처에 SIGTERM 을 보내 깨운다.

## 검증

`swift build` 경고 0. `swift test` 407개 전부 초록을 **10회 연속** + 최종 정리 후 5회 더 확인(플레이크 0). 계약 스위트는 Python 13/13, Swift 12/12(fork bomb 픽스처 없음) 통과. 8개 동시 실행 무간섭, fork bomb·손자 프로세스 실행 후 `proc_listpids` 잔존 0. Swift 채점은 예열 후 1회 0.7~0.9초(상한 5초).

## 메모

- 계약 픽스처 두 곳이 서브프로세스 백엔드에서 자기모순이라 테스트 카탈로그에서만 보정했다(`AdjustedContractCatalog`). ① `infinite-loop` 는 `wall 2 / cpu 1` 인데 `.fails(.wallClockExceeded)` 를 기대한다 — 바쁜 루프는 CPU 1초를 1초 만에 태우므로 SIGXCPU 가 먼저 온다. ② Python `file-size-flood` 는 CPython 이 시작 시 `SIGXFSZ` 를 `SIG_IGN` 으로 덮어 `OSError`+종료코드 1 로 끝난다.
- `ContractHarnessTests` 가 이미 InProcess 계약 스위트를 돌리므로 중복 실행을 두지 않았다. 무한 재귀 CTE 두 벌이 동시에 코어를 태우면 같은 타깃의 시간 측정 테스트를 흔든다.