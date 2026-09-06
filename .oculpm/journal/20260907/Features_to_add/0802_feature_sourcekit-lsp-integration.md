---
schema_version: 1
type: feature
slug: "sourcekit-lsp-integration"
status: done
difficulty: superhigh
created_at: "2026-09-07T08:02:04+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (병렬 워크트리 세션)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/LSPKit"
    op: create
  - path: "Packages/LearnKit/Tests/LSPKitTests"
    op: create
  - path: "Packages/LearnKit/Sources/Features/EditorFeature/Internal/Completion"
    op: create
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: "docs/lsp.md"
    op: create
related:
  - ref: "20260907/Features_to_add/0615_feature_editor-console-sql-result-screens.md"
    kind: "followup"
tags:
  - "lsp"
  - "sourcekit"
  - "editor"
  - "swift"
  - "parallel"
  - "mcp-tool"
---
[x] sourcekit-lsp 연동 — 완성과 진단을 Swift 트랙에

병렬 워크트리 세션(Opus)이 구현하고 부모 세션이 병합·재검증했다. 이번 라운드에서 가장 큰 조각이다 — 테스트 135개가 늘었다.

## 추가 기능

새 타깃 `LSPKit` — `Content-Length` 프레이밍, JSON-RPC 2.0, 요청 상관·취소·알림 라우팅, LSP↔`LearnCore.Diagnostic` 매핑. **프로세스 없이 도는 순수 계층과 실제 서버를 띄우는 계층이 갈려 있고**, 계약을 고정하는 것은 전자다.

`EditorFeature` 쪽은 CESE 의 `codeSuggestionTriggerCharacters` 와 `CodeSuggestionDelegate` 에 물린다. 진단은 **새 뷰를 만들지 않았다** — 기존 `EditorDiagnosticPresentation.rows(groups:)` 가 그대로 `InlineDiagnosticRowView` 를 먹인다. 다른 것은 라벨뿐이다(`4행 9열 · sourcekit-lsp · 1개`, 한 줄에 둘 다 오면 `· sourcekit-lsp/swiftc · 2개`).

## 실측

- `initialize` 응답 **38~50ms**, `triggerCharacters: [".", "("]`
- **디스크에 없는 URI 로도 완전히 동작한다** — 유령 경로에 `didOpen` 해도 진단과 완성 후보 200개가 왔다. 그래서 학습자 코드는 디스크에 닿지 않고 빈 임시 디렉터리만 `rootUri` 로 준다.
- 첫 `publishDiagnostics` 는 `didOpen` 뒤 1.2~1.4초, `didChange` 뒤 약 1.07초
- 완성: 첫 요청 88ms, 워밍 후 27~30ms(중앙값 28)
- 취소 → `{"code": -32800, "message": "request cancelled by client"}`
- 진단에 `code` 가 없어 `ruleID` 는 nil — 출처는 행 라벨이 진다
- `label` 은 사람이 읽는 시그니처이고 실제로 삽입할 문자열은 `textEdit.newText` 다

## 내 지시가 틀렸던 것

**200ms 기준에 단서가 필요하다.** 워밍 후에는 28ms 로 여유롭게 통과하지만, 문서를 연 직후 **첫** 완성은 서버의 빌드 설정 해석과 겹쳐 270ms 가 나왔다. 정직한 진술은 "한 번 분석된 뒤에는 200ms" 다.

세션이 자기 주장도 하나 반증했다. "버전 증가와 큐잉 사이에 `await` 가 없다"고 문서에 적었는데 `notify` 가 액터 격리라 모든 호출이 중단점이었다 — `didChange` v3 가 v2 를 앞지를 수 있고 스스로 낫지 않는다. `nonisolated` 전송과 MainActor 편집 시퀀스로 고치고 회귀 테스트 4개를 붙였다.

## 검증

`swift test --package-path Packages/LearnKit` **1047개**(912 → +135) 통과, 빌드 경고 0. 부모가 병합 후 다시 돌린 결과도 같다. 새 테스트 중 11개가 실제 `sourcekit-lsp` 를 띄우고 나머지는 프로세스 없이 돈다.

"취소 시 요청이 실제로 취소됨"은 시간이 아니라 **구조로** 증명했다 — 같은 id 로 `$/cancelRequest` 가 실제로 나가고, 호출자는 값이 아니라 `CancellationError` 를 받고, 늦게 온 응답은 버려지며 세션은 계속 쓸 수 있다.

## 메모

세션이 `RunnerKit` 의 잠재 레이스를 하나 보고했고(자기 소관 밖이라 고치지 않음), 부모가 이어서 고쳤다 — 별도 일지 [[runnerkit-process-group-race]].