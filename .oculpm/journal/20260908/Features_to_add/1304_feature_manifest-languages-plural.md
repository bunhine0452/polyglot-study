---
schema_version: 1
type: feature
slug: "manifest-languages-plural"
status: done
difficulty: medium
created_at: "2026-09-08T13:04:08+09:00"
session_id: "20260908-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackManifest.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackManifestValidation.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/StableIDLock.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Install/ContentPack.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Install/PackLibrary.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/LessonParser.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/LessonParseError.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonContent.swift"
    op: update
  - path: "Tools/Sources/LessonGenKit/Lesson/PackWriter.swift"
    op: update
  - path: "Tools/Sources/PackValidate/SyntaxStage.swift"
    op: update
  - path: "Packages/LearnKit/Tests/ContentKitTests/PackManifestTests.swift"
    op: update
related:
  - ref: "20260908/Features_to_add/1245_feature_lesson-language-variants.md"
    kind: "followup"
tags:
  - "contentkit"
  - "manifest"
  - "schema"
  - "algorithms"
  - "mcp-tool"
---
[x] 매니페스트 언어 복수화 — 복수는 단수의 확장이지 대체가 아니다

`{#manifest-languages-plural}`. 본문이 여러 언어를 담을 수 있게 됐으니 매니페스트도 그
사실을 적을 수 있어야 한다 — 안 그러면 `lessons(for:)` 가 각 언어 목록에서 그 레슨을 찾지
못한다.

## 추가 기능

`LessonEntry.language` → `languages: [LanguageID]`. `lessons(for:)` 는
`languages.contains` 로 찾아, 알고리즘 레슨 하나가 **Rust 목록에도 Python 목록에도** 나온다.
순번 중복 검사도 언어마다 돌게 했다 — 여러 언어를 담은 레슨은 그 언어들의 목록에 모두
끼므로 각각에서 겹치지 않아야 한다.

`parseDocument` 가 이제 매니페스트와 본문의 언어 **집합이 정확히 같은지** 본다. 한쪽만 있어도
실패다: 본문에만 있으면 화면의 언어 선택에는 뜨는데 `lessons(for:)` 가 빼먹고, 매니페스트에만
있으면 목록에는 뜨는데 열면 그 언어의 블록이 없다.

## 동작 흐름

읽기는 단수·복수 두 표기를 다 받는다. **쓰기는 언어가 하나면 v1 단수 표기로 되돌아 쓴다.**

## 검증

- 신규 테스트 5건 — 단수 디코딩, 복수 디코딩(순서 보존), 둘 다 없으면 실패, 단수 왕복,
  여러 언어 레슨이 각 언어 목록에 잡힘
- **LearnKit 871 테스트 129 스위트 통과**
- `packtool validate` 실제 팩 무변화 (python 24편 실패 0건)

## 메모

**"쓸 때는 항상 복수로 통일" 을 하려다 되돌렸다.** round-trip 테스트("매니페스트를 다시
구우면 바이트가 같다")가 깨지면서 알게 된 것: **`packtool sign` 이 정규 매니페스트 바이트에
서명한다.** 표기를 바꾸면 그 순간 리포의 팩 5종 서명이 전부 무효가 된다.

그래서 규칙을 뒤집었다 — 복수 표기는 **단수로 적을 수 없는 경우에만** 나타난다. 표기가 둘인
것이 아니라 복수가 단수의 확장이다. 처음 판단은 "새 팩에 옛 표기가 퍼지지 않게" 였는데,
지켜야 할 것이 표기의 통일이 아니라 **서명된 바이트**라는 사실이 더 무거웠다.

## 병렬 작업의 함정 — 시그널 11 의 진짜 원인

사용자 요청으로 Sonnet 세션 둘을 병렬로 돌렸다. `EditorFeatureTests` 가 시그널 11 로 죽는
일이 반복됐고 처음엔 "증분 빌드 잔재" 로 판단했는데, **진짜 원인은 `.build` 경합**이었다 —
나와 두 에이전트가 같은 패키지 디렉터리에서 동시에 `swift build`/`swift test` 를 돌리면
빌드 산출물이 서로를 덮어쓴다. `rm -rf .build` 로 한 번 고쳐진 것은 우연이었다.

`swift test --scratch-path <내 전용 경로>` 로 분리하니 크래시가 사라지고 **진짜 실패**가
드러났다(위의 round-trip). 경합이 실패를 가리고 있었던 셈이다.

**다음에 병렬로 나눌 때 지킬 것 둘**:
1. 파일 범위만 나누지 말고 **빌드 디렉터리도 나눈다**(`--scratch-path`).
2. 에이전트에게 `rm -rf .build` 를 권하지 않는다 — 공유 워킹트리에서는 남의 실행을 날린다.
   이번에 내가 그렇게 안내해서 내 회귀 실행이 한 번 통째로 죽었다.