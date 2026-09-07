---
schema_version: 1
type: refactor
slug: "concurrent-spawn-limit"
status: done
difficulty: high
created_at: "2026-09-07T17:17:36+09:00"
session_id: "20260907-004"
agent:
  id: "claude-code"
  session: "cedda3a8-2bf7-45b2-a0ee-3cd061225de6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/RunnerKit/Concurrency/ConcurrencyGate.swift"
    op: create
  - path: "Packages/LearnKit/Sources/RunnerKit/Subprocess/SubprocessRunner.swift"
    op: update
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftTestingGrader.swift"
    op: update
  - path: "Tools/Sources/PackValidate/SwiftGradingGate.swift"
    op: delete
  - path: "Tools/Sources/PackValidate/BlockGate.swift"
    op: update
  - path: "Packages/LearnKit/Tests/RunnerKitTests/ConcurrencyGateTests.swift"
    op: create
related:
  - ref: "20260907/Errors/1622_error_ci-hang-serial-runnerkit.md"
    kind: "followup"
  - ref: "20260907/Bugs/0616_bug_swift-grading-mutual-exclusion.md"
    kind: "followup"
tags:
  - "release-wiring"
  - "concurrency"
  - "runnerkit"
  - "mcp-tool"
---
[x] 동시 실행 상한을 코드에 세우고 문지기를 한 벌로 모았다

`{#concurrent-spawn-limit}`.

## 동기

CI 에서 RunnerKit 스위트가 병렬로는 25분 상한을 넘겼고 직렬로는 8분 47초에 통과했다.
그 조치(`--no-parallel`)는 **테스트에만** 걸린 것이라 앱에는 아무 상한도 없었다.

그리고 앱을 배선하면서 더 구체적인 구멍이 드러났다. `SwiftTestingGrader` 의
`defaultTemplateDirectory` 는 **고정 경로**(`$TMPDIR/learnkit-swift-template`)인데
`EditorModel.defaultGrade` 는 채점할 때마다 `SwiftTestingGrader()` 를 새로 만든다.
인스턴스가 달라도 템플릿은 하나이므로 액터 경계로는 아무것도 막지 못한다 — 두 채점이
겹치면 한쪽이 다른 쪽의 `Sources/Solution/Solution.swift` 를 덮어쓴다. `packtool` 은
`SwiftGradingGate` 로 호출자 쪽에서 막고 있었지만, 그건 **그 호출자만** 지킨다.

같은 모양의 FIFO 세마포어가 이미 세 곳에 각자 적혀 있었다(`SwiftGradingGate`,
`CompilerLoadGate`, 그때그때).

## 변경 요약

- **`RunnerKit.ConcurrencyGate`** — 문지기 한 벌. 상한 `limit`, FIFO 대기, `withSlot`.
- **`ExecutionLimits.spawns`** — 프로세스 실행 전역 상한. 기본값은 `packtool` 의
  `ValidationOptions.defaultConcurrency` 와 **같은 식**(`max(2, 코어/2)`)이다. 검증기와
  앱이 같은 부하를 만들어야 한쪽에서 잰 시간이 다른 쪽에서 의미를 갖는다.
  `SubprocessRunner` 가 준비(컴파일)와 실행을 **한 자리 안에서** 지난다 — 둘을 따로
  세면 컴파일 N개 + 실행 N개가 동시에 도는 순간이 생긴다.
- **`ExecutionLimits.swiftTemplateGate`** — 템플릿 디렉터리별 상호 배제(상한 1).
  호출자가 아니라 **공유 자원 옆에** 뒀다. `Tools` 의 `SwiftGradingGate` 는 그래서 지웠다.
- 획득 순서는 언제나 **템플릿 → 스폰**. 반대로 잡는 곳이 없으므로 교착이 생길 수 없다.

## 판단 — 액터가 아니라 잠금인 이유

처음엔 이 저장소의 다른 문지기들처럼 액터로 썼고, 컴파일이 거부했다:
`sending value of non-Sendable type '() async throws -> T'`. 액터 메서드가 본문을 돌리면
본문과 반환값이 격리 경계를 넘게 되고, 그 순간 남의 코드에 `Sendable` 요구가 붙는다.
문지기는 남의 코드를 자기 격리 안으로 끌어들이면 안 된다.

그래서 상태만 `NSLock` 으로 지키고, `withSlot` 은
`isolation: isolated (any Actor)? = #isolation` 으로 **호출자의 격리를 물려받는다.**
반납이 동기 함수인 것도 같은 계산이다 — 액터면 반납이 `await` 라 `defer` 안에서
`Task { await release() }` 로 미뤄야 하고, 그건 안전 보장을 취소 가능한 Task 에
매다는 것이다(이 저장소가 이미 밟은 함정이다).

곁가지로 `NSLock.lock()`/`unlock()` 은 **async 컨텍스트에서 직접 부를 수 없다**는 것도
확인했다 — 읽기는 동기 프로퍼티로 빼야 한다.

## 밟은 함정

FIFO 를 단언하는 테스트를 처음에 `gate.withSlot { ... 안에서 다시 withSlot 을 기다림 }`
으로 썼다가 **교착**시켰다(상한 1짜리 문에서 자기 자신을 기다린다). 문을 잡은 쪽을 별도
`Task` 로 띄우고 걸쇠로 붙잡는 형태로 고쳤다.

## 검증

`RunnerKitTests` **273건 전부 통과**(`--no-parallel`, 69.8초 — 템플릿이 예열된 상태).
새 테스트 7건이 상한을 고정한다: 상한 1·2·4 에서 최고 동시 수가 상한을 넘지 않고
(1보다 크면 실제로 겹치는 것까지), 본문이 던져도 반납되고, 대기가 FIFO 로 풀리고,
기본 스폰 상한이 `packtool` 의 식과 같고, `SubprocessRunner` 가 기본으로 전역 문을 쓰고,
같은 템플릿 경로는 언제나 같은 문을 받는다. `Tools` 307건 통과(중복 게이트 테스트 2건이
사라져 309 → 307).