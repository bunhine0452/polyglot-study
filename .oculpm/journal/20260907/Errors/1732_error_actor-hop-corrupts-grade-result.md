---
schema_version: 1
type: error
slug: "actor-hop-corrupts-grade-result"
status: done
difficulty: superhigh
created_at: "2026-09-07T17:32:56+09:00"
session_id: "20260907-004"
agent:
  id: "claude-code"
  session: "cedda3a8-2bf7-45b2-a0ee-3cd061225de6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/RunnerKit/Languages/SwiftTestingGrader.swift"
    op: correct
  - path: "Packages/LearnKit/Sources/RunnerKit/Concurrency/ConcurrencyGate.swift"
    op: correct
related:
  - ref: "20260907/Refactors/1717_refactor_concurrent-spawn-limit.md"
    kind: "blocked_by"
tags:
  - "concurrency"
  - "swift-6.3"
  - "runnerkit"
  - "miscompile"
  - "mcp-tool"
---
[x] 액터 격리 함수를 한 단계 더 거치자 SwiftGrading 이 깨졌다 — 게이트는 방아쇠가 아니었다

`{#concurrent-spawn-limit}` 을 넣고 전체 스위트 5회를 돌리다 1회차에서 잡았다.
**한 번 통과가 증거가 아니라는 규칙이 값을 한 자리다** — 단발 실행은 세 번 다 초록이었다.

## 발생 원인

증상은 테스트 호스트의 `SIGSEGV` 였다.

```
EXC_BAD_ACCESS (SIGSEGV), KERN_INVALID_ADDRESS at 0x0000000000000010
  _ArrayBuffer.count.getter
  Sequence.contains(where:)
  GradeResult.hasErrors.getter
  closure #5 in SwiftEditorSubmitIntegrationTests.realSubmitFailsOnBuildError()
```

`#expect(result.hasErrors)` 에서 `diagnostics` 배열의 버퍼 포인터가 쓰레기였다.
바로 앞줄의 `#expect(!result.passed)` 는 통과했으니 구조체 전체가 아니라 **배열만** 깨졌다.

내가 넣은 문지기가 원인이라고 보고 좁혀 들어갔다. 이분법으로 하나씩 껐다.

| 형태 | 결과 |
|---|---|
| 게이트를 제네릭 래퍼 `withTemplate<T>(_ body:)` 로 감쌈 | **6/6 크래시** |
| 래퍼를 `acquire()`/`release()` 쌍으로 바꿈 (여전히 `performGrade` 로 분할) | **4/4 크래시** |
| `SubprocessRunner` 게이트만 제거 | 크래시 |
| `SwiftTestingGrader` 게이트만 제거 (분할은 유지) | 크래시 |
| 게이트 대신 `await Task.yield()` 한 줄 (분할 유지) | **2/2 크래시** |
| **게이트도 없고 `await` 도 없이, 분할만** (`grade` → `performGrade` 단순 전달) | **2/2 크래시** |
| 게이트를 `grade()` 본문 안에 펼치고 **한 함수로 유지** | **0/5 크래시** |
| 게이트 도입 직전 커밋(`504062a`) | 0/3 크래시 |

즉 **문지기는 방아쇠가 아니었다.** 방아쇠는 액터(`SwiftTestingGrader`) 격리 함수에서
배열을 담은 구조체(`SwiftGrading` → `GradeResult.diagnostics`)를 **한 단계 더 거쳐**
돌려보내는 것 자체다. Swift 6.3.3 / Xcode 26.6 에서 결정적으로 재현된다.

이 저장소가 밟은 같은 계열의 다섯째다. 앞의 넷은 "예열·재사용을 위해 공유한 자원에 동시
접근" 셋과 `@Sendable` 클로저를 `@MainActor` 격리 `init` 의 기본 인자로 둘 때의
`freed pointer was not the last allocation` 이었다.

## 해결 방법

`grade(solution:tests:)` 와 `warmUp()` 을 **쪼개지 않고**, 게이트 획득·반납을 그 함수
본문 맨 위에 펼쳐 둔다. 값이 어떤 함수 경계도 더 넘지 않는다.

```swift
public func grade(...) async throws -> SwiftGrading {
    let template = ExecutionLimits.swiftTemplateGate(for: configuration.templateDirectory)
    await template.acquire()
    defer { template.release() }
    await ExecutionLimits.spawns.acquire()
    defer { ExecutionLimits.spawns.release() }
    try materializeTemplate()   // ← 원래 본문 그대로, 분할 없음
    …
}
```

그리고 이 함정을 **타입으로 막았다** — `ConcurrencyGate.withSlot` 의 반환을 `Void` 로
못박았다. 값을 돌려받아야 하는 자리는 `acquire()`/`release()` 를 호출부에 펼쳐 쓸 수밖에
없다. 두 함수의 doc 주석에 재현 표와 "쪼개지 마라" 를 남겼다.

## 검증

`EditorFeatureTests` 81건 **5회 연속 통과**(고친 뒤). 고치기 전에는 같은 필터로 6/6 크래시.
크래시 리포트(`~/Library/Logs/DiagnosticReports/swiftpm-testing-helper-*.ips`)의 스택으로
원인 프레임을 특정했다 — 로그의 `✘` 만 봤으면 "채점이 실패했다" 로 잘못 읽었을 것이다
(실제로 첫 징후는 `passed → false` 였고, 그건 호스트가 죽으면서 생긴 부수 현상이었다).

## 메모

이 세션에서 `swift test ... 2>&1 | tail -1` 로 5회 반복 결과를 요약하려다 두 번 데었다.
첫째, zsh 는 따옴표 없는 변수를 단어 분할하지 않아 `swift test $args` 가 통째로 한 인자가
됐고 5라운드가 전부 **아무 테스트도 안 돌린 채** 종료 코드 0을 냈다. 둘째, 호스트가
죽으면 마지막 줄이 요약이 아니라 `started` 줄이다. 요약은 `grep 'Test run with'` 로
집고 종료 코드를 따로 봐야 한다.