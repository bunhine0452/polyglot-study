---
schema_version: 1
type: feature
slug: "packtool-validation-gate"
status: done
difficulty: high
created_at: "2026-09-07T06:15:18+09:00"
session_id: "20260907-001"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/PackReport/PackValidationReport.swift"
    op: create
  - path: "Tools/Sources/PackValidate"
    op: create
  - path: "Tools/Sources/packtool/ValidateCommand.swift"
    op: update
  - path: "Tools/Tests/PackValidateTests"
    op: create
  - path: "Tools/Package.swift"
    op: update
related:
  - ref: "20260906/Features_to_add/1847_feature_content-pipeline-foundation.md"
    kind: "followup"
tags:
  - "packtool"
  - "content-pack"
  - "validation"
  - "parallel"
  - "backfill"
  - "mcp-tool"
---
[x] packtool 팩 검증 게이트 — 구조·문법·의미·실행 4단계

지난 세션에서 커밋(`b2964e6`, `50cf189`)됐으나 일지가 비어 있어 소급 기록한다. 스텁이던 `packtool validate` 가 실제 게이트가 됐다.

## 추가 기능

**PackReport 타깃 — 두 실행 파일의 유일한 접점.** packtool 이 쓰고 lessongen repair 가 읽는다. 구현 전에 계약부터 못박은 이유는, 생성기가 검증기의 내부를 알면 검증기의 약점을 우회하기 때문이다. `Failure.Kind` 를 "어느 코드가 던졌는가" 가 아니라 **"모델이 무엇을 고쳐야 하는가"** 로 나눈다 — repair 가 이걸로 프롬프트를 고른다. `Failure.evidence` 에는 러너 원문을 요약 없이 싣는다. `stagesRun` 으로 실행 게이트가 실제로 돌았는지 남긴다 — 툴체인이 없어 건너뛴 통과를 통과로 읽으면 안 된다. `canonicalJSON` 은 키 정렬·들여쓰기 고정(CI 가 diff 로 비교).

**PackValidate 타깃 — 로직 전부.** packtool 은 얇은 CLI 다. 게이트 자신이 검증되지 않으면 아무것도 보장하지 못하므로 단계마다 단위 테스트가 붙는 자리를 만들었다.

- **구조**: 매니페스트 디코딩·잠금 위반·디스크와 **양방향** 대조(첫 실패에서 멈추지 않고 전부 모은다)·참조 파일 존재. 툴체인 없는 머신에서 그대로 돈다.
- **문법·의미**: `LessonParseError` 를 (단계, 종류)로 분류하고, 파싱을 통과한 값에는 퀴즈·빈칸 정합성을 **독립적으로 다시** 단언한다. 전부 `line:column` 을 들고 나간다.
- **실행**: 예제·빈칸·과제를 실제 `CodeRunner` 에 태운다. 예제는 expected 사이드카와 바이트 대조(BOM·CRLF·후행 개행 셋만 정규화, **줄 끝 공백은 접지 않는다**), 과제는 solution 통과와 **starter 실패**를 둘 다 확인한다.
- **리포트 3형식**: text / json(canonicalJSON 그대로) / JUnit XML. 돌지 않은 단계는 JUnit 에 skipped 로 남는다.

## 동작 흐름

툴체인이 없으면 **스킵이 아니라 실패가 기본**이다. `--allow-missing-toolchain` 을 명시할 때만 건너뛰고 `stagesRun` 에서 execution 을 뺀다.

실측 두 개가 코드에 박혔다. **`SDKROOT` 이 비어 있으면 swiftc 가 표준 라이브러리를 못 찾아 멀쩡한 Swift 레슨이 전부 컴파일 실패로 뒤집힌다** — 실행 게이트 앞에서 `xcrun` 으로 채운다. 그리고 SwiftPM 템플릿 경로를 팩 경로 해시로 갈라 병렬 워크트리의 `.build` 락 경합을 없앴다.

## 검증

`swift test --package-path Tools` 267 테스트 통과(이 작업 전 139 → 게이트 도입 188 → 이후 누적 267), 빌드 경고 0. 정상 팩 1개(python+sql)와 **그것을 한 곳씩 깨뜨린 10종** 픽스처가 서로 다른 메시지로 실패하는 것이 테스트로 고정돼 있다. `swift run --package-path Tools packtool validate Content/packs/polyglot-mvp` 가 레슨 3개·실패 0건으로 종료 코드 0.