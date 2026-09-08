---
schema_version: 1
type: feature
slug: "lesson-language-variants"
status: done
difficulty: high
created_at: "2026-09-08T12:45:15+09:00"
session_id: "20260908-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/LessonBlock.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/LessonParser.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/LessonParseError.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonContent.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonModel.swift"
    op: update
  - path: "Tools/Sources/LessonGenKit/Lesson/LessonSerializer.swift"
    op: update
  - path: "Tools/Sources/LessonGenKit/Repair/LessonDraftReader.swift"
    op: update
  - path: "Tools/Sources/PackValidate/ParseFailureClassifier.swift"
    op: update
  - path: "Packages/LearnKit/Tests/ContentKitTests/LessonParserTests.swift"
    op: update
related:
  - ref: "20260908/Refactors/1216_refactor_track-keyed-by-pack-not-language.md"
    kind: "followup"
tags:
  - "contentkit"
  - "parser"
  - "lesson"
  - "algorithms"
  - "mcp-tool"
---
[x] 레슨 하나에 여러 언어의 풀이 — 개념·퀴즈는 공용, 예제·빈칸·과제는 언어별

`polyglot-algorithms` 의 `{#block-language-variants}`. 알고리즘은 언어를 가로지르는 하나의
콘텐츠인데 스키마가 **레슨 하나에 언어 하나**를 박아 두고 있었다.

## 추가 기능

블록 **종류의 순서**는 그대로 계약이다. 달라진 것은 실행기를 태우는 셋이 언어마다 한 번씩
반복될 수 있다는 것뿐이다.

```
@Concept                                   한 번
@Example(rust)  @Example(python)           언어마다
@Blank(rust)    @Blank(python)             언어마다
@Task(rust)     @Task(python)              언어마다
@Quiz  @Reflection                         한 번
```

개념·퀴즈·돌아보기를 공용으로 둔 이유: **이진 탐색이 무엇인지는 Rust 로 풀든 Python 으로
풀든 같다.** 언어마다 다시 쓰면 같은 설명 넷이 서로 어긋나기 시작한다.

`LessonBlockKind.allowsLanguageVariants` 가 그 셋을 표시하고, `LessonDocument.language` 는
`languages: [LanguageID]` 가 됐다 — **선언 순서 그대로**이고 그것이 화면의 언어 선택 순서다.
단수 접근자 `example`·`blank`·`task` 는 없앴다. `example(for:)` 로 언어를 밝히게 해서,
여러 언어 레슨에서 "첫 언어" 를 조용히 집는 일이 생기지 않게 했다.

새 에러 셋: 같은 언어로 같은 블록 두 번(`duplicateLanguage`), 선언한 언어에 짝이 없음
(`languageWithoutBlock`), 매니페스트가 선언한 언어가 본문에 없음(`manifestLanguageMissing`).
가운데 것이 핵심이다 — 예제는 python 으로 썼는데 과제가 rust 뿐이면 python 학습자는 읽기만
하고 못 푼다. 그 팩을 설치하지 않는다.

## 동작 흐름

언어의 정본은 **본문**이다. 매니페스트는 자기가 선언한 언어가 그 목록에 있는지만
확인받는다. `LessonContent` 는 고른 언어를 들고 `document.blocks(for:)` 로 6블록을 뽑는다 —
언어가 하나면 결과가 예전과 같다.

`ExecutionStage` 는 손대지 않았다. 이미 `blocks` 를 순회하며 case 로 갈라서 **모든 언어
변형을 그대로 돌린다.**

## 검증

- 새 테스트 6건 — 두 언어 파싱, 고른 언어로 보면 다시 6블록, 단일 언어 레슨 무변화,
  중복 언어 throw, 과제 없는 언어 throw, 매니페스트 불일치 throw
- **LearnKit 862 테스트 127 스위트 통과**
- `packtool validate` 실제 팩 5종 파싱 실패 0건 (cpp 의 78건은 이 맥의 clang++ 가
  `iostream` 헤더를 못 찾는 환경 문제로, 전부 execution 단계다)

## 메모

**증분 빌드 잔재로 시그널 11 을 세 번 재현했다.** `EditorFeatureTests/PackTaskLoadingTests`
가 결정적으로 죽어서 내 파서 변경을 의심했지만, HEAD 를 별도 워크트리에 뽑아 돌리니
통과했고, 내 트리에서도 `.build` 를 지우니 그대로 사라졌다. 병렬 세션이 같은 워킹트리에
`16a3ac6`(연습장 화면)을 커밋해 EditorFeature 쪽이 바뀐 것과 겹친 시점이다.

**교훈**: 세그폴트는 Swift 트랩이 아니다. 트랩이면 메시지가 남는다. 메시지 없는 시그널 11
이고 소스에 재귀가 없다면 **빌드 산출물을 먼저 의심할 것.** 코드에서 원인을 찾느라 시간을
썼다.

또 하나: 이 저장소는 지금 **여러 세션이 한 워킹트리를 공유**하고 있다. 작업 중 브랜치가
`main` 에서 `feat/scratch-screen` 으로 바뀌었다.