---
oculpm_plan: v1
id: polyglot-algorithms
title: "알고리즘 트랙 — 언어를 가로지르는 하나의 콘텐츠 + 시각화"
status: active
created: 2026-09-08
updated: 2026-09-08
owner: claude-code
---

알고리즘은 언어가 아니라 개념이다. 트랙 하나 안에서 풀이 언어를 골라 학습하고, 개념에 붙은 시각화가 언어와 무관하게 같은 그림을 보여준다. 설계 근거는 design/AlgorithmLesson.dc.html 아트보드에 그려져 있다 — 레퍼런스는 Swift Playgrounds 의 3분할(탐색·에디터·라이브 프리뷰)이고, 우측 프리뷰 자리가 시각화다.

## 트랙을 팩 단위로 {#track-by-pack}
- [x] TrackDescriptor 의 식별자를 languageID 에서 트랙ID 로 바꾸고 packID 를 싣는다 — 완료: 한 언어에 트랙 둘(Rust 입문·알고리즘)이 목록에 따로 뜬다 {#track-descriptor-pack-id}
- [ ] DashboardModel 의 진도 묶기와 TracksModel 의 선택을 트랙 단위로 옮긴다 — 완료: 언어별 묶기 잔재가 grep 에 0건이고 기존 대시보드 테스트가 전부 통과 {#dashboard-group-by-track}
- [ ] 툴체인 조회는 언어로 남긴다 — 완료: 알고리즘 트랙이 선택된 언어의 rustc·python3 상태를 그대로 읽는다 {#toolchain-lookup-stays-language}

## 레슨 다국어 {#multi-language-lesson}
- [x] Example·Blank·Task 를 언어별로 반복 가능하게 하고 Concept·Quiz·Reflection 은 공용으로 둔다 — 완료: 한 레슨에 Rust·Python 두 벌이 담기고 순서 위반이 여전히 throw {#block-language-variants}
- [x] 매니페스트 레슨 엔트리를 language 단수에서 languages 배열로 — 완료: 깨진 매니페스트(선언한 언어에 과제가 빠진 경우)가 고유 에러로 실패 {#manifest-languages-plural}
- [x] 레슨 화면에 풀이 언어 선택을 붙이고 고른 언어를 기억한다 — 완료: 언어를 바꾸면 예제·빈칸·과제만 갈아타고 개념·시각화는 그대로 {#lesson-language-picker}
- [ ] 진도를 레슨 단위로 남기고 어떤 언어로 풀었는지는 부가 기록으로 — 완료: 언어를 바꿔도 완료 표시가 유지된다 {#progress-per-lesson-not-language}

## 시각화 {#visualization}
- [x] 프레임 모델 스키마 v1 — 장면 셋(배열·그래프·표)으로 네 계열을 덮는다. 트리는 좌표를 저작한 그래프다 — 완료: 네 계열 표본이 각각 파싱되고 프레임마다 자막이 강제된다 {#frame-model-schema}
  - [x] 배열 장면 — 값·포인터 여럿·구간 강조·제외 표시 {#scene-array}
  - [x] 그래프 장면 — 노드 좌표 저작, 방문·프론티어·간선 역할, 노드별 값(거리) {#scene-graph}
  - [x] 표 장면 — 2차원 격자, 채워진 칸과 참조 화살표 {#scene-table}
- [x] @Visualize 블록 디렉티브와 사이드카 경로 — 완료: 레퍼런스 레슨이 7블록으로 파싱되고 사이드카 누락이 throw {#visualize-directive}
- [x] SwiftUI 재생기 — 단계 이동·스크럽·재생, 자막 표시 — 완료: 키보드만으로 프레임을 앞뒤로 옮길 수 있다 {#frame-player-view}
- [x] packtool 에 시각화 검증을 더한다 — 완료: 프레임이 0개거나 자막이 빈 사이드카가 팩 검증에서 잡힌다 {#visuals-authoring-check}

## 에디터 보강 {#editor}
- [ ] 자동완성 팝업 — 레퍼런스의 핵심 어포던스. 종류 뱃지와 문서 패널 — 완료: rust-analyzer 응답이 팝업으로 뜨고 키보드로 선택된다 {#completion-popup}
- [ ] 좌측 블록 탐색 패널 — 완료: 블록 사이를 목록에서 오갈 수 있고 완료 상태가 보인다 {#block-navigator}

## 콘텐츠 {#content}
- [x] 32편 아웃라인 — 정렬·탐색 12, 그래프 8, 트리 6, DP 6 — 완료: 각 편에 시각화 대상 장면이 지정돼 있다 {#algorithms-outline}
- [x] Rust 풀이로 32편 생성 — 완료: packtool validate 통과하고 모든 과제의 테스트가 실제로 돈다 {#algorithms-rust-lessons}
- [x] 32편의 시각화 사이드카 — 완료: 모든 레슨이 프레임을 갖고 자막이 왜를 설명한다 {#algorithms-visuals}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-08T12:15:09+09:00 | #track-descriptor-pack-id | claude-code | ☐→x |  | TrackID 신설, TrackDescriptor 에 packID 추가하고 hasContent 를 팩 유무에서 파생. 테스트로 증명 — 같은 rust 트랙 둘이 따로 서고 진도가 안 섞인다 |
| 2026-09-08T12:45:26+09:00 | #block-language-variants | claude-code | ☐→x | .oculpm/journal/20260908/Features_to_add/1245_feature_lesson-language-variants.md | 예제·빈칸·과제만 언어마다 반복. 새 에러 3종으로 짝 안 맞는 팩을 막는다. 862 테스트 통과, 실제 팩 5종 파싱 무변화 |
| 2026-09-08T12:45:32+09:00 | #algorithms-outline | claude-code | ☐→x |  | tracks/algorithms.outline.json 32편 — 정렬·탐색 12 / 그래프 8 / 트리 6 / DP 6, visual 은 array 12·graph 14·table 6. prerequisite 역행 0건 |
| 2026-09-08T12:47:35+09:00 | #scene-array | claude-code | ☐→x |  | 값·이름붙은 포인터·구간 역할(강조/제외). 프레임이 자기 배열을 선택적으로 실어 정렬(자리바꿈)까지 덮는다 — 길이가 다르면 throw |
| 2026-09-08T12:47:42+09:00 | #scene-graph | claude-code | ☐→x |  | 노드 좌표 저작, 노드·간선 공용 역할(frontier/current/visited/settled), 노드별 거리. 트리도 이 장면으로 그린다 |
| 2026-09-08T12:47:48+09:00 | #scene-table | claude-code | ☐→x |  | 행·열 머리글에서 크기를 유도해 desync 불가. 칸 값·역할·참조(from)로 DP 의 "어디서 왔는가" 를 그린다 |
| 2026-09-08T12:58:30+09:00 | #manifest-languages-plural | claude-code | ☐→x |  | LessonEntry.languages 배열로. 손으로 쓴 디코더가 v1 단수 표기도 읽고 인코딩은 복수로 통일. parseDocument 가 매니페스트와 본문의 언어 집합 일치를 요구. 실제 팩 5종 무변화 |
| 2026-09-08T13:05:08+09:00 | #visuals-authoring-check | claude-code | ☐→x | .oculpm/journal/20260908/Features_to_add/1304_feature_manifest-languages-plural.md | VisualsStage 를 구조 단계에 얹었다 — 검증기를 새로 쓰지 않고 VisualFrameSet 디코더를 그대로 태운다. 파일명과 id 불일치도 잡는다. visuals/ 없는 팩은 무영향(실제 팩 5종 확인). PackValidate 54건 통과 |
| 2026-09-08T13:15:02+09:00 | #visualize-directive | claude-code | ☐→x | .oculpm/journal/20260908/Features_to_add/1314_feature_visualize-directive-and-player.md | @Concept 의 선택적 하위 디렉티브로. 블록 7개는 불가 — LessonBlockSequence.count 가 전역이라 기존 122편이 영원히 미완료가 된다. visuals/ 를 등록 디렉터리로 넣어 미등록 사이드카는 설치 거부 |
| 2026-09-08T13:15:10+09:00 | #frame-player-view | claude-code | ☐→x | .oculpm/journal/20260908/Features_to_add/1314_feature_visualize-directive-and-player.md | VisualPlayerState(순수 값 타입) + 장면 뷰 셋. 키보드로 앞뒤·처음/끝·재생 토글. DesignSystem 이 아니라 LessonFeature 에 둔다 — DesignSystem 은 ContentKit 을 의존하지 않는 콘텐츠 무관 계층 |
| 2026-09-08T13:45:28+09:00 | #lesson-language-picker | claude-code | ☐→x |  | 언어가 하나면 아예 안 그린다. 바꾸면 예제·빈칸·과제만 갈아타고 개념·퀴즈·돌아보기와 보던 블록 자리는 유지, 빈칸 답·실행 결과는 지운다(다른 코드의 것이라). 신규 테스트 5건 |
| 2026-09-08T15:00:07+09:00 | #algorithms-rust-lessons | claude-code | ☐→x |  | lessongen import 로 손으로 써서 비용 $0. packtool validate 네 단계 32편 실패 0건 — 96개 블록이 실제로 컴파일·실행된다 |
| 2026-09-08T15:20:38+09:00 | #algorithms-visuals | claude-code | ☐→x |  | 32편 전부에 사이드카와 @Visualize. 배열 12·그래프 14(트리 포함)·표 6. 프로젝트 디코더로 32/32 통과, 각 프레임이 자막을 갖고 DP 는 from 으로 "어느 칸에서 왔는가" 를 보인다 |
<!-- oculpm:plan-log end -->
