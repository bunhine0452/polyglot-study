---
schema_version: 1
type: bug
slug: "runnerkit-process-group-race"
status: done
difficulty: high
created_at: "2026-09-07T08:02:38+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/LauncherStatusChannel.swift"
    op: update
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/SubprocessRunner.swift"
    op: update
  - path: "Packages/LearnKit/Tests/RunnerKitTests/LauncherStatusChannelTests.swift"
    op: create
related:
  - ref: "20260907/Features_to_add/0802_feature_sourcekit-lsp-integration.md"
    kind: "blocked_by"
tags:
  - "runnerkit"
  - "concurrency"
  - "process-group"
  - "safety"
  - "mcp-tool"
---
[x] 프로세스 그룹 기록이 취소되는 Task 에 매달려 있었다 — 손자가 남는 구멍

sourcekit-lsp 세션이 전체 스위트를 5회 돌리다 `grandchildIsReaped` 실패를 한 번 잡았고(부하 17.8, 다른 세션이 `lessongen` 을 돌리는 중이었다), 자기 소관 밖이라 **고치지 않고 정확히 보고**했다. 그 판단이 옳았다 — 테스트 잡음이 아니라 실제 구멍이었다.

## 발생 원인

프로세스 그룹은 손자까지 회수하는 **유일한 손잡이**다. `SubprocessRunner` 의 회수 `defer` 와 `onCancel` 킬러가 둘 다 `groupBox` 하나만 본다.

그런데 그 `groupBox` 는 `watcher` Task 안에서만 채워졌다.

```swift
let watcher = Task {
    guard let spawned = await channel.awaitSpawn(within: .seconds(5)) else { return false }
    groupBox.set(spawned.processGroup)          // ← 여기서만
    configuration.processGroupObserver?(...)
    ...
}
...
watcher.cancel()                                 // ← 출력 드레인이 끝나면
```

즉시 끝나는 프로그램에서는 이 취소가 SPAWNED 파싱을 **앞지를 수 있다.** status 드레인은 별도 `Thread` 라 `storage` 가 비동기로 채워지고, 취소된 Task 안의 `Task.sleep(2ms)` 는 즉시 던진다. 그러면 `awaitSpawn` 이 nil 을 돌려주고 `groupBox` 는 영영 비어 있다.

결과는 조용하다. 회수 `defer` 가 때릴 그룹을 모르므로 **손자(`sh -c 'sleep 300' &`)가 그대로 남는다.** 실행은 성공으로 보고되고 아무도 모른다. 부하가 있을 때만 나타나서 더 나쁘다.

## 해결 방법

기록을 **취소될 수 있는 무엇에서도 떼어 낸다.** `LauncherStatusChannel` 이 SPAWNED 를 파싱하는 즉시 콜백을 부르고, 그 호출은 **드레인 스레드**에서 일어난다. 드레인은 취소되지 않으므로 SPAWNED 가 도착하기만 하면 그룹은 반드시 기록된다.

- `onSpawn(_:)` 를 `startDraining()` **전에** 건다. 이미 도착해 있을 수도 있으므로 거는 시점에도 한 번 확인한다.
- `reportSpawnIfNeeded()` 는 정확히 한 번만 부른다. 락 **밖에서** 부른다 — `outcome` 이 다시 락을 잡고, 콜백이 무엇을 할지 우리가 모른다.
- `watcher` 에 남은 일은 메모리 상한 감시뿐이라 이제 취소돼도 안전하다. `memoryMegabytes > 0` 가드를 `awaitSpawn` **앞으로** 옮겨, 상한이 없으면 5초 폴링을 아예 시작하지 않는다.
- 보조로 `awaitSpawn` 이 취소로 빠져나갈 때 마지막으로 한 번 더 스냅샷을 본다 — 값을 알고도 nil 을 돌려주면 호출자가 그룹을 잃는다.

`ProcessGroupBox` 와 테스트의 `ObservedProcessGroups` 는 둘 다 `NSLock` 으로 보호돼 있어 드레인 스레드에서 불러도 안전한 것을 확인했다.

## 검증

`LauncherStatusChannelTests` 4개를 새로 붙여 계약을 고정했다 — **아무도 `awaitSpawn` 을 부르지 않아도** SPAWNED 가 기록되고, 폴러를 미리 취소해도 그룹이 남고, 한 줄이 두 번의 `write` 에 걸쳐 와도 보고는 한 번뿐이고, 드레인이 먼저 시작돼 이미 도착한 뒤에 건 콜백도 놓치지 않는다.

전체 스위트 1051개 5회 반복 통과, 빌드 경고 0.

## 메모

같은 종류의 버그가 이 저장소에서 넷째다 — 런처의 고정 임시 경로, 채점 테스트의 머신 전역 템플릿, Swift 채점 템플릿 공유, 그리고 이번 건. 앞의 셋은 "공유 자원에 동시 접근" 이었는데 이번 것은 결이 다르다. **안전 보장이 취소 가능한 작업 하나에 매달려 있었다.** 회수·정리 같은 보장은 그것을 켠 Task 의 수명보다 오래 살아야 한다.