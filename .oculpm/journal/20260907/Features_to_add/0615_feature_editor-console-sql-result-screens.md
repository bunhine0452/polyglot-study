---
schema_version: 1
type: feature
slug: "editor-console-sql-result-screens"
status: done
difficulty: high
created_at: "2026-09-07T06:15:40+09:00"
session_id: "20260907-001"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/Features/EditorFeature"
    op: create
  - path: "Packages/LearnKit/Tests/EditorFeatureTests"
    op: create
  - path: "Packages/LearnKit/Package.swift"
    op: update
related:
  - ref: "20260906/Features_to_add/2101_feature_first-running-app.md"
    kind: "followup"
tags:
  - "ui"
  - "swiftui"
  - "editor"
  - "sql"
  - "parallel"
  - "backfill"
  - "mcp-tool"
---
[x] 에디터·콘솔과 SQL 결과 diff 화면 — 목 데이터 없이 실제 러너로

지난 세션 커밋(`8efc80d`)의 소급 기록. `design/Editor.dc.html` 과 `design/ResultSQL.dc.html` 두 아트보드를 구현했다. 이걸로 디자인 7종 중 5종이 화면이 됐다.

## 추가 기능

- **EditorFeature** — `EditorModel(@Observable)` 이 `LessonModel` 과 같은 `runFactory`/`graderFactory` 주입 계약을 따르되, **기본 경로가 실제 `SwiftLanguageModule`·`InProcessRunner`·`SwiftTestingGrader`·`SQLResultSetGrader` 를 탄다.** 목 데이터가 없다.
- **콘솔 화면** — 48px 헤더, 56px 과제 바, 좌우 2단. 우측 520px 고정 패널에 출력·테스트 탭, 상태 행, stderr 원문, 테스트 결과.
- **인라인 진단 행** — 거터 6px 사각 + 코드 아래 한국어 설명 + 위치·도구·개수 라벨. 진단이 붙은 행만 배경이 바뀐다.
- **SQL 결과 diff** — 내 결과와 예상 결과 2단 표, 누락 행은 실패 틴트 배경에 6px 적색 사각.

## 동작 흐름

뷰 없이 테스트하기 위해 두 계산을 **순수 함수로 뽑았다** — `EditorDiagnosticPresentation` 은 `Diagnostic` 배열을 행별 표시로 접고, `SQLDiffPresentation` 은 두 결과셋을 나란한 행 쌍으로 맞춘다. 행 수가 다르면 짧은 쪽에 누락 플레이스홀더를 채워 **두 표의 높이를 같게 만든다** — 그래야 하단 결과셋 비교 캡션의 y 좌표가 실행 결과와 무관하게 고정된다.

빨강 예산은 뷰 레벨이 아니라 **grep 테스트로** 고정했다. 콘솔 화면 소스에서 `Palette.fail` 이 정확히 1곳(종료 코드 배지)임을 단언하고, SQL 화면(`Internal/SQL/`)은 diff 표시에 적색 사각이 구조적으로 필요하므로 그 예산 밖으로 명시적으로 뺐다. 규칙을 주석이 아니라 실행되는 단언으로 두면 다음 세션이 모르고 깨뜨릴 수 없다.

## 검증

`swift test --package-path Packages/LearnKit` 912 테스트 통과, 빌드 경고 0. `SwiftEditorIntegrationTests`·`SQLEditorIntegrationTests` 가 목이 아닌 실제 러너·채점기로 왕복한다. 빨강 예산은 `RedBudgetTests` 가 소스를 직접 훑어 단언한다.