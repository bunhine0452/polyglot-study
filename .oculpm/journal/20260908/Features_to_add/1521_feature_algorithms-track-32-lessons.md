---
schema_version: 1
type: feature
slug: "algorithms-track-32-lessons"
status: done
difficulty: high
created_at: "2026-09-08T15:21:16+09:00"
session_id: "20260908-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Content/packs/polyglot-algorithms"
    op: create
  - path: "tracks/algorithms.outline.json"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TrackCatalog.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/DashboardModelTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/ContentKitTests/PackLibraryTests.swift"
    op: update
related:
  - ref: "20260908/Features_to_add/1314_feature_visualize-directive-and-player.md"
    kind: "followup"
tags:
  - "content"
  - "algorithms"
  - "visualization"
  - "lessongen"
  - "packtool"
  - "mcp-tool"
---
[x] 알고리즘 트랙 32편과 시각화 — API 없이, 96개 블록이 실제로 돈다

`{#algorithms-rust-lessons}` 와 `{#algorithms-visuals}`. 사용자 요청으로 Sonnet 세션
여섯을 병렬로 썼다(레슨 넷 · 시각화 셋).

## 추가 기능

Rust 로 푸는 알고리즘 **32편** — 정렬·탐색 12 · 그래프 8 · 트리 6 · DP 6. 편마다
시각화 사이드카가 붙는다(배열 12 · 그래프 14 · 표 6, 트리는 좌표를 저작한 그래프).

**알고리즘 트랙을 카탈로그에 등록**했다. `{#track-descriptor-pack-id}` 가 이걸 위해
있었다 — 언어와 1:1 이 아닌 첫 트랙이다.

## 동작 흐름

`lessongen import` 로 손으로 썼다. API 를 부르는 `lesson` 커맨드와 다른 것은 드래프트를
**어디서 얻는가**뿐이고, 그 뒤 직렬화·파서 검사·팩 쓰기·sha256 대조는 같은 코드를 지난다.
**비용 $0.**

`@Visualize` 부착은 import **뒤에** 한 번만 돌린다 — import 를 다시 돌리면 레슨 본문이
드래프트에서 새로 쓰이며 그 디렉티브가 지워진다.

## 검증

- `packtool validate` 네 단계(구조·문법·의미·실행) **32편 실패 0건**. 레슨마다 예제·빈칸·
  과제 세 블록이 rustc 로 컴파일·실행되므로 **96개 블록**이다.
- 시각화 32개를 **프로젝트 자체 디코더**(`VisualFrameSet`)로 검증 — 32/32 통과.
- LearnKit 909 테스트 136 스위트, 앱 빌드 통과.

## 메모

**참조 레슨을 먼저 끝까지 통과시킨 것이 결정적이었다.** 31편을 나누기 전에 이진 탐색
한 편을 밀었고 거기서 세 가지가 걸렸다 — (1) 기대 출력을 **손으로 계산했다가 틀렸다**
(4단계인 줄 알았는데 3단계였다), (2) 빈칸 템플릿에도 `fn main()` 이 필요했다, (3) 개요의
`language` 가 트랙 이름(`algorithms`)으로 적혀 있었다. 셋 다 나머지 작성 지침에 미리
박아 넣어 31편이 한 번에 통과했다.

**내 검증 스크립트에 구멍이 있었고 `packtool` 이 잡았다.** 빈칸에 표식 `___1___` 이
없으면 치환이 무의미해지고 **원본이 그대로 컴파일돼 통과한다**. `cycle-detection` 한 편이
그랬다 — 빈칸 없는 빈칸 문제가 나갈 뻔했다. 스크립트에 "표식과 정답 슬롯이 1..n 으로
맞는가" 를 넣고 32편을 다시 돌렸다(다른 편에는 없었다).

**에이전트가 내 지시를 어긴 것이 옳았던 경우.** 힙 레슨에 "`BinaryHeap` 을 쓰라" 고
했는데, 개요의 목표가 "배열로 표현하고 sift-up/sift-down 을 직접 구현" 이라 그대로 쓰면
학습 목표가 사라진다. 손으로 구현하고 그 판단을 보고했다.

**테스트가 숫자를 하드코딩하고 있었다.** "10트랙"·"122편"·"활성 5트랙" 같은 것들이
트랙을 하나 더할 때마다 걸린다. 카탈로그에서 유도하도록 바꿨다. `PackLibraryTests` 의
총수는 **팩 단위**로 세게 했다 — 언어로 세면 Rust 를 쓰는 두 팩이 한 숫자로 합쳐져 어느
트랙의 총수도 아닌 값(58)이 나온다.

**공유 `.build` 경합이 이번 세션에서 세 번 나를 속였다.** `build-app.sh` 가 실패했는데
`--scratch-path` 로 격리하니 통과했다. 매번 코드를 먼저 의심하게 만든다 — 여러 세션이 한
워킹트리를 쓰는 동안에는 **빌드 디렉터리부터 분리**하는 것이 규칙이어야 한다.