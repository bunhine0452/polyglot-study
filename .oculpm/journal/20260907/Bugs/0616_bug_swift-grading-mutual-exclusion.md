---
schema_version: 1
type: bug
slug: "swift-grading-mutual-exclusion"
status: done
difficulty: high
created_at: "2026-09-07T06:16:33+09:00"
session_id: "20260907-001"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/PackValidate/SwiftGradingGate.swift"
    op: create
  - path: "Tools/Sources/PackValidate/BlockGate.swift"
    op: update
  - path: "Tools/Tests/PackValidateTests/SwiftGradingGateTests.swift"
    op: create
  - path: "Content/packs/polyglot-mvp/tests/swift-0001-safe-divide.swift"
    op: correct
  - path: "Content/packs/polyglot-mvp/expected/sql-0001-aggregate-run.txt"
    op: correct
  - path: "Content/packs/polyglot-mvp/manifest.json"
    op: update
related:
  - ref: "20260907/Features_to_add/0615_feature_packtool-validation-gate.md"
    kind: "blocked_by"
tags:
  - "packtool"
  - "concurrency"
  - "swiftpm"
  - "shared-resource"
  - "backfill"
  - "mcp-tool"
---
[x] Swift 채점 상호 배제 — 동시 실행이 서로의 소스를 덮어쓰던 결함

지난 세션 커밋(`bc9a39d`)의 소급 기록.

## 발생 원인

packtool 이 샘플 팩을 떨어뜨렸는데 **판정과 증거가 어긋났다.** "solution 이 숨은 테스트를 통과하지 못한다" 고 보고했지만 증거의 stdout 에는 `Fatal error: 여기를 구현해라` — **starter 의 내용**이 찍혀 있었다. solution 파일에는 멀쩡한 구현이 들어 있다.

원인은 공유 자원이다. `SwiftTestingGrader` 는 예열된 SwiftPM 템플릿 **하나**를 재사용하는데, 한 과제의 solution·starter 채점이 `async let` 으로 동시에 돌면서 한쪽이 다른 쪽의 `Sources/Solution/Solution.swift` 를 덮어썼다. 로그에 `Another instance of SwiftPM is already running` 이 남아 있었다. 게다가 블록들이 레슨을 넘어 동시에 도는 구조라 **어느 두 Swift 블록이 겹쳐도** 같은 일이 난다.

이걸로 같은 종류의 버그가 셋째다 — 런처의 고정 임시 경로, 채점 테스트의 머신 전역 템플릿, 그리고 이번 건. 전부 "예열·재사용을 위해 공유한 자원에 동시 접근" 이다.

## 해결 방법

`SwiftGradingGate` 로 **Swift 채점만** 상호 배제한다. Python·SQL 은 템플릿을 공유하지 않으므로 병렬을 유지한다. 액터로 감싸는 것만으로는 부족하다 — 액터 메서드 안에서 `await` 하면 재진입이 허용되므로 **명시적 획득·반납**이 필요하다.

채점마다 템플릿을 새로 만드는 안은 버렸다. 매번 콜드 빌드가 약 6초라 228 레슨에서 감당이 안 되고, 예열 템플릿은 회당 약 0.65초다.

**게이트가 잡은 콘텐츠 결함 둘도 함께 고쳤다.** `tests/swift-0001-safe-divide.swift` 에 `@testable import Solution` 이 없어 빌드가 실패했고(`SwiftTestingGrader` 가 두 타깃으로 굽는다), `expected/sql-0001-aggregate-run.txt` 가 sqlite3 CLI 형식이었다 — 앱의 `InProcessRunner` 는 헤더 행 + `" | "` 를 낸다. **앱이 절대 내지 않을 바이트를 가르치고 있었다.** 매니페스트 해시도 재생성했다.

## 검증

`swift run --package-path Tools packtool validate Content/packs/polyglot-mvp` 가 레슨 3개·실패 0건으로 종료 코드 0(재확인함). `swift test --package-path Tools` 267 테스트 통과 — `SwiftGradingGateTests` 가 동시 획득이 직렬화되는 것을 단언한다. LearnKit 912 테스트 무변.