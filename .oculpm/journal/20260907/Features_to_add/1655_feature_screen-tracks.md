---
schema_version: 1
type: feature
slug: "screen-tracks"
status: done
difficulty: medium
created_at: "2026-09-07T16:55:21+09:00"
session_id: "20260907-004"
agent:
  id: "claude-code"
  session: "cedda3a8-2bf7-45b2-a0ee-3cd061225de6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TracksModel.swift"
    op: create
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TracksView.swift"
    op: create
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/TracksModelTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/TestSupport.swift"
    op: update
  - path: "App/Sources/PolyglotApp/Composition.swift"
    op: update
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: update
related:
  - ref: "20260907/Features_to_add/1648_feature_route-editor-screen.md"
    kind: "followup"
tags:
  - "release-wiring"
  - "ui"
  - "dashboard"
  - "mcp-tool"
---
[x] 트랙 화면 — 임의의 레슨으로 들어가는 유일한 길

`{#screen-tracks}`. `case .tracks` 가 `PlaceholderPanel` 이었다.

## 추가 기능

- **`TracksModel`** — 트랙 10종과 각 트랙의 레슨 전부. 레슨 한 줄은 순번·제목·상태·
  블록 칸 6개를 든다. 진도는 대시보드와 같은 `LessonProgressStore` 에서 오고, 팩 하나라도
  못 읽으면 전체를 실패로 본다(빈 목록을 그리면 "아직 안 함" 이라고 말하는 것이 된다).
- **`TracksView`** — 왼쪽 트랙 목록(선택 행은 반전, 준비 중 트랙은 흐림), 오른쪽 레슨 목록.
- **대시보드 → 트랙 이동** — 표의 트랙 행을 누르면 트랙 화면으로 옮겨 그 트랙이 펴진다.
  `DashboardView` 에 `onOpenTrack` 이 이미 있었지만 **받는 곳이 없어** 표를 눌러도 아무
  일도 일어나지 않고 있었다.
- 셸의 목적지 넷이 전부 실제 화면이 되어 `PlaceholderPanel` 을 지웠다.

## 열려 있던 결정 — 별도 화면으로 정했다

플래너 항목이 "대시보드의 트랙 표를 확장할지, 별도 화면을 그릴지부터 정한다" 였고
`design/` 에 트랙 아트보드가 없다. **별도 화면**으로 정한 근거는 취향이 아니라 기능이다 —
대시보드의 표는 트랙마다 **한 줄**이라 "이어서" 한 곳만 가리킬 수 있다. 그래서 이 앱에는
**5번 레슨을 다시 보러 갈 길이 아예 없었다.** 목록이 있어야 그 길이 생긴다.

아트보드가 없으므로 새 토큰을 만들지 않았다. 두 단 레이아웃·행 높이(40px = 8×5)·룰·진도
칸이 전부 기존 프리미티브와 8px 그리드 위에 있고, 색은 상태 표시에만 쓴다는 규칙도 그대로다.

`DashboardFeature` 타깃 안에 둔 것도 판단이다. 두 화면이 `TrackCatalog`·`TrackDescriptor`·
`ProgressCells`·`LessonProgressStore` 라는 같은 어휘를 쓴다 — 타깃을 가르면 그 넷을 두 번
정의하게 되고, 그러면 같은 트랙이 두 화면에서 다르게 보인다.

## 검증

조립된 `.app` 을 `POLYGLOT_START_DESTINATION=tracks` 로 띄워 확인했다 — 왼쪽에 MVP 3트랙
(`0 / 12`)과 준비 중 7트랙(`26 레슨` 등)이, 오른쪽에 파이썬 12편의 **실제 제목**과 블록
칸·상태가 섰다. 테스트 6건이 순서·상태 매핑·자이가르닉 칸·선택 규칙·읽기 실패·렌더를
고정한다. LearnKit 814 테스트(RunnerKit 제외) 통과.

## 메모

앱에 `EditorFeature` 가 링크되면서 링커 경고 105건이 새로 보인다. 벤더링된
`CodeEditLanguages` 의 프리빌드 오브젝트가 벤더 머신 경로(`/Users/Khan/Developer/…`)를
디버그 맵에 들고 있어서 나는 것으로, **이 세션의 변경과 무관하다** — `swift build
--package-path Packages/LearnKit --build-tests` 에서 이미 같은 105건이 난다. 컴파일러 경고는
여전히 0이다.