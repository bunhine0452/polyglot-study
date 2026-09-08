---
schema_version: 1
type: feature
slug: "visualize-directive-and-player"
status: done
difficulty: high
created_at: "2026-09-08T13:14:51+09:00"
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
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackLayout.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/VisualFrameSet.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Visualization/VisualPlayerView.swift"
    op: create
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Visualization/VisualPlayerState.swift"
    op: create
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Visualization/ArraySceneView.swift"
    op: create
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Visualization/GraphSceneView.swift"
    op: create
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Visualization/TableSceneView.swift"
    op: create
  - path: "Tools/Sources/PackValidate/VisualsStage.swift"
    op: create
  - path: "Content/fixtures/polyglot-mvp/visuals/aggregate-fold.json"
    op: create
  - path: "Content/fixtures/polyglot-mvp/lessons/sql-0001-aggregate.md"
    op: update
  - path: "Content/fixtures/polyglot-mvp/manifest.json"
    op: update
related:
  - ref: "20260908/Features_to_add/1248_feature_visual-frame-model-v1.md"
    kind: "followup"
tags:
  - "contentkit"
  - "visualization"
  - "lesson"
  - "designsystem"
  - "packtool"
  - "mcp-tool"
---
[x] @Visualize 디렉티브와 재생기 — 블록 수를 늘리지 않고 시각화를 붙인다

`{#visualize-directive}` 와 `{#frame-player-view}`. 재생기와 packtool 검증은 Sonnet 병렬
세션에 맡기고 디렉티브는 직접 했다.

## 추가 기능

**`@Visualize` 는 `@Concept` 의 선택적 하위 디렉티브다.** 최상위 블록이 아니다.

```
@Concept(id: aggregate-basics) {
산문…
@Visualize(id: aggregate-fold, frames: visuals/aggregate-fold.json) { 한 줄 설명 }
}
```

**왜 블록이 아닌가** — 이것이 이번 작업의 핵심 판단이다. 블록으로 독립시키려면 레슨의
블록 수가 6에서 7로 늘어야 하는데 그 값이 **전역**이다:

```
LearnCore.LessonBlockSequence.count = 6
M005:  CHECK (current_block_index BETWEEN 0 AND 5)
```

7로 올리면 **기존 122편이 전부 "블록 4 / 7" 로 보이고 영원히 완료되지 않는다.** 레슨마다
블록 수가 다를 수 있게 만드는 것은 진도·대시보드 칸·마이그레이션을 함께 건드리는 별개
프로젝트다. 그리고 사실에도 맞는다 — 시각화는 개념을 *보여주는* 것이지 별도의 학습 단계가
아니다. `design/AlgorithmLesson.dc.html` 의 7행 탐색은 화면의 표현일 뿐 데이터 모델이
그럴 필요는 없다.

`visuals/` 를 `PackLayout.contentDirectories` 에 등록했고, `referencedFiles` 가 사이드카를
포함해 **매니페스트 미등록이면 설치가 거부**한다.

`VisualScene` 에 `frameCount` 와 `caption(at:)` 을 더했다 — 재생기가 장면 종류를 몰라도
이동과 자막을 그릴 수 있다. 장면이 하나 더 늘어도 이동 로직은 그대로다.

## 동작 흐름

`VisualPlayerState`(순수 값 타입, SwiftUI 없음)가 이동을 담고, 세 장면 뷰가 그린다.
키보드만으로 앞뒤 이동·처음/끝·재생 토글이 된다.

## 검증

- **LearnKit 898 테스트 133 스위트 통과**
- `packtool validate` — 샘플 팩(시각화 포함) 실패 0건, 실제 팩 5종 무변화
- **사이드카를 일부러 깨뜨려 확인**: 포인터를 범위 밖으로 바꾸니
  `frames[2] 의 포인터 '지금'(99) 가 배열 범위(0..<5) 밖이다` 와 크기 불일치가 각각 다른
  실패로 잡혔다

## 메모

**병렬 세션이 타입을 복제했다.** 재생기를 `DesignSystem` 에 만들라고 했는데 그 타깃은
`LearnCore` 만 의존해서 `ContentKit.VisualFrameSet` 을 못 본다. 에이전트는 `Package.swift`
수정 금지를 지키느라 **필드 모양만 같은 그림자 타입 4개**를 만들었고, 그 사실을 헤더 주석과
보고서에 정직하게 적었다.

내 지시가 틀렸다. `DesignSystem` 은 **콘텐츠 무관 계층**이라 ContentKit 의존을 넣으면 계층이
뒤집힌다. 재생기의 올바른 자리는 둘 다 이미 의존하는 `LessonFeature` 였다. 옮기고 그림자
타입 4개를 지웠다 — `Package.swift` 는 끝내 건드리지 않았다.

**교훈**: 병렬 세션에 UI 를 맡길 때 "어느 모듈에" 를 지정하려면 **그 모듈의 의존 그래프를
먼저 확인해야 한다.** 파일 범위만 나누고 의존을 안 본 것이 원인이다.

샘플 팩에 실제 사이드카를 넣었다(`aggregate-fold.json`, MAX 가 다섯 행을 한 값으로 접는
과정 6프레임). **예시가 없는 포맷 기능은 썩는다** — 샘플 팩은 포맷의 레퍼런스다. 배열 장면이
정수만 그리므로 f-string 레슨 대신 숫자가 자연스러운 SQL 집계 레슨에 붙였다.