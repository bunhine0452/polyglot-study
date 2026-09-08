---
schema_version: 1
type: feature
slug: "visual-frame-model-v1"
status: done
difficulty: medium
created_at: "2026-09-08T12:48:22+09:00"
session_id: "20260908-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/VisualFrameSet.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/VisualFrameSetError.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/ArrayVisual.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/GraphVisual.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Visual/TableVisual.swift"
    op: create
  - path: "Packages/LearnKit/Tests/ContentKitTests/VisualFrameSetTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/ContentKitTests/VisualFrameSetDecodingTests.swift"
    op: create
  - path: "tracks/algorithms.outline.json"
    op: create
related:
  - ref: "20260908/Features_to_add/1245_feature_lesson-language-variants.md"
    kind: "followup"
tags:
  - "contentkit"
  - "visualization"
  - "algorithms"
  - "schema"
  - "mcp-tool"
---
[x] 시각화 프레임 모델 v1 — 장면 셋으로 네 계열을 덮는다

`{#frame-model-schema}` 와 하위 장면 셋, 그리고 `{#algorithms-outline}`. 두 갈래를 Sonnet
병렬 세션에 나눠 맡기고(사용자 요청) 파일 범위를 겹치지 않게 못박았다.

## 추가 기능

**장면은 셋뿐이다** — 배열·그래프·표. 트리는 그래프의 특수한 경우다: 부모·자식이 겹치지
않게 좌표를 저작해 둔 그래프이지 트리 전용 렌더러가 필요한 게 아니다. 아웃라인의 네 계열
32편이 array 12 · graph 14(그래프 8 + 트리 6) · table 6 으로 이 셋에 들어간다.

**프레임은 차이가 아니라 전체 상태다.** 재생기가 임의의 프레임으로 곧장 스크럽해도 앞을
전부 재생해 상태를 누적할 필요가 없다.

**자막은 필수**다 — 빈 문자열도 거부한다. 그림만으로는 "왜" 가 안 남는다.

**검증이 디코딩 시점에 붙는다.** 매니페스트처럼 "느슨하게 디코드한 뒤 `validate()`" 가
아니라, 각 장면의 검증 이니셜라이저를 `init(from:)` 이 곧바로 부른다 — 의미가 깨진 값이
존재하는 순간 자체가 없다.

## 동작 흐름

사이드카는 평평하다. `kind` 를 먼저 읽고 **같은 디코더**를 장면 타입에 넘겨 자기 키를
읽게 한다 — `"scene": {...}` 중첩을 만들지 않아 손으로 쓰기 좋다.

깨진 입력이 각각 다른 에러로 실패한다: 프레임 0개, 자막 빈 문자열, 범위 밖 인덱스, 없는
노드 id, 미지의 kind, 노드 id 중복, 선언 안 된 노드를 가리키는 간선, 뒤집힌 구간, 빈 표.

## 검증

- ContentKit **176 테스트 23 스위트 통과**
- 다섯 종류의 깨진 입력이 실제 JSON 디코딩에서 서로 다른 에러로 실패하는 것을 한 테스트가
  나란히 증명한다
- 아웃라인: 32편, 레슨 키가 기존 아웃라인과 `visual` 하나만 다르고, id 중복 0,
  **prerequisite 가 자기보다 앞선 레슨만 참조**(역행 0건)

## 메모

**병렬 세션의 설계 결정 하나가 아웃라인과 충돌했다.** 배열 값이 시각화 전체에 고정이라
"스왑 애니메이션은 v1 범위 밖" 으로 문서화돼 있었는데, 아웃라인의 배열 12편 중 **5편이
정렬**이다. 값이 자리를 바꾸는 것이 그 레슨의 핵심이라 그대로 두면 5편을 못 그린다.

프레임이 자기 `values` 를 **선택적으로** 싣게 넓혔다 — 없으면 시작 배열이다. 훑기
시각화(이진 탐색·투 포인터·슬라이딩 윈도우)의 사이드카는 그대로 간결하고, 정렬만 값을
싣는다. 길이가 다르면 throw 한다: 정렬은 자리바꿈이지 크기 변경이 아니고, 길이가 흔들리면
포인터 검증의 기준 자체가 프레임마다 달라진다.

**병렬로 나눌 때 접점을 먼저 확인해야 한다는 사례다.** 두 갈래 모두 각자 옳았지만
"배열 계열에 정렬이 몇 편인가" 라는 접점을 아무도 안 봤다.