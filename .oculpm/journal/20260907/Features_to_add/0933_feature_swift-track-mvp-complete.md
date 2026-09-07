---
schema_version: 1
type: feature
slug: "swift-track-mvp-complete"
status: done
difficulty: medium
created_at: "2026-09-07T09:33:25+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Content/packs/polyglot-swift"
    op: create
  - path: "tracks/swift.outline.json"
    op: create
  - path: "tracks/swift.notes.txt"
    op: create
  - path: "README.md"
    op: update
related:
  - ref: "20260907/Features_to_add/0914_feature_github-repo-and-sql-track.md"
    kind: "followup"
tags:
  - "content"
  - "swift-track"
  - "lessongen"
  - "packtool"
  - "mcp-tool"
---
[x] Swift 트랙 12편 — MVP 세 트랙이 모두 찼다

## 추가 기능

변수·타입 추론에서 시작해 옵셔널 바인딩과 구조체를 거쳐 클로저·`map`·`filter` 까지 12편. 선수 관계가 완전한 DAG 를 이룬다. 이로써 MVP 세 트랙(Python·SQL·Swift) **36편**이 전부 4단계 게이트를 통과한다.

## 동작 흐름

**첫 시도에 12/12 가 나왔다.** 파이썬과 SQL 은 각각 한 편씩 실패했는데 Swift 는 생성 단계 실패가 0이었다. 차이는 앞의 두 트랙에서 배운 함정을 `--notes` 로 미리 실은 것이다.

- 채점기가 SwiftPM 패키지를 굽는다 — solution·starter 는 `Sources/Solution/Solution.swift` 가 되므로 **최상위 실행 코드가 아니라 선언만** 담아야 하고, tests 는 반드시 `import Testing` + `@testable import Solution` 로 시작해야 한다. 후자가 빠져 빌드가 깨진 것을 지난주에 실제로 밟았다.
- starter 는 **반드시 테스트를 실패시켜야 한다** — `fatalError` 로 비워 둔다.
- `print` 가 옵셔널을 `Optional(3)` 로, `Double` 을 `3.0` 으로 찍는다.
- **딕셔너리와 Set 은 순서가 보장되지 않는다** — `sorted(by:)` 로 고정한 뒤 출력해야 expected 사이드카를 적을 수 있다.

세 트랙을 굽고 나서 보이는 것: **모델의 실패는 언어 지식이 아니라 하네스 계약에서 나온다.** 프롬프트에 계약을 정확히 적을수록 첫 시도 성공률이 올라간다.

## 검증

`packtool validate` 4단계 — 처음 4건(3편) 실패, `repair` 가 전부 고침, 재검증 **12편 실패 0건**.

잡힌 것: 빈칸 정답이 실행 안 됨, solution 이 숨은 테스트를 통과 못 함 2건, 예제 출력 불일치.

Swift 채점은 `SwiftGradingGate` 로 직렬화되는데 **전체 검증이 25초**였다 — 예열된 SwiftPM 템플릿 덕에 우려보다 훨씬 빨랐다. "Swift 는 오래 걸릴 것" 이라는 내 예상이 과했다.

비용 $0.042(생성 $0.030 + 수리 $0.012). 캐시 적중 21.8%, 업스트림 고정 지켜짐.

## 메모

세 트랙 누적 비용은 약 $0.19 다. 레슨당 약 $0.005(수리 포함). 남은 7개 트랙을 같은 규모로 채우면 $0.5 안팎이고, 병목은 비용이 아니라 **개요를 사람이 읽고 확인하는 단계**다.