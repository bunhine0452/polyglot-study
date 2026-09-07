---
schema_version: 1
type: feature
slug: "app-loads-all-packs"
status: done
difficulty: high
created_at: "2026-09-07T16:39:59+09:00"
session_id: "20260907-004"
agent:
  id: "claude-code"
  session: "cedda3a8-2bf7-45b2-a0ee-3cd061225de6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/ContentKit/Install/PackLibrary.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Install/PackSQLSeed.swift"
    op: create
  - path: "Tools/Sources/PackValidate/PackSQLSeed.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/LearnCore/Identifiers.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/DashboardModel.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/DashboardPresentation.swift"
    op: update
  - path: "App/Sources/PolyglotApp/Composition.swift"
    op: update
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: update
  - path: "App/Scripts/build-app.sh"
    op: update
  - path: "scripts/ci-validate-packs.sh"
    op: update
  - path: "Content/fixtures/polyglot-mvp/manifest.json"
    op: rename
  - path: "Packages/LearnKit/Tests/ContentKitTests/PackLibraryTests.swift"
    op: create
related: []
tags:
  - "release-wiring"
  - "contentkit"
  - "dashboard"
  - "pack-installer"
  - "mcp-tool"
---
[x] 앱이 설치된 팩 전부를 읽는다 — MVP 36편이 대시보드에 떴다

`{#app-loads-all-packs}` 과 하위 둘(`{#wire-pack-installer}` · `{#bundle-packs}`).
"테스트는 통과하는데 앱에서는 안 된다" 상태의 첫 조각이다.

## 추가 기능

- **`ContentKit.PackLibrary`** — 팩 하나를 읽는 창구가 `ContentPack` 이라면, 여러 팩을
  하나의 커리큘럼으로 보는 창구다. 디렉터리 탐색(재귀하지 않는다 — 팩 안의 하위
  디렉터리를 팩으로 착각할 길을 막는다), 직접 열기(개발), `PackStore` 설치 후
  `current` 열기(배포). 팩 하나가 깨져도 나머지는 열고, 깨진 사실은 `problems` 로
  화면까지 올라간다.
- **`LearnCore.LessonRef`** — `(PackID, LessonID)` 쌍. `ResumePoint` 에 `packID` 가
  붙었다. 트랙마다 팩이 다르므로 `LessonID` 만으로는 어느 팩에서 읽을지가 정해지지
  않는다. 대시보드가 가리킨 레슨과 조립 루트가 여는 레슨이 이제 어긋날 수 없다.
- **`DashboardModel`** 이 `packIDs: [PackID]` 를 받아 여러 팩의 진도를 병합한다.
  하나라도 못 읽으면 전체 실패로 본다 — 읽힌 것만 그리면 그 트랙이 "아직 시작 안 함"
  으로 보이고, 그건 저장소를 못 읽은 것과 전혀 다른 말이다.
- **`build-app.sh`** 가 `Content/packs` 를 번들 `Resources/Content/packs` 에 넣는다.
  없으면 콘텐츠 0편 번들이 만들어지고 그 사실은 앱을 띄우기 전에는 드러나지 않으므로,
  조용히 넘어가지 않고 죽는다.

## 동작 흐름

`Composition` 의 팩 탐색 순서가 계약이다.

1. `POLYGLOT_PACK_PATH` — 팩 하나든 팩들이 담긴 디렉터리든. 설치를 거치지 않으므로
   콘텐츠를 고치면서 앱을 띄울 때 매니페스트 해시를 다시 굽지 않아도 된다.
2. 번들 `Resources/Content/packs` — **배포 경로**. 읽기 전용 씨앗이라 `PackStore`
   (`~/Library/Application Support/LearnKit/ContentPacks`)에 설치하고 `current` 를
   읽는다. 같은 버전이면 다시 설치하지 않고, `current` 만 없으면 포인터를 다시 세운다.
   번들에서 직접 읽지 않는 이유는 업데이트다 — 갱신된 팩은 번들이 아니라 스토어에 온다.
3. 저장소 `Content/packs` — 번들에 콘텐츠가 없을 때의 개발 폴백.

트랙 총수도 팩에서 읽는다. `TrackCatalog` 의 24/22/24 는 계획값이고 팩에는 12편씩
들어 있다 — 12편짜리 트랙에 24칸을 그리면 다 끝낸 학습자가 반만 한 것으로 보인다.
콘텐츠가 없는 7트랙은 계획값을 그대로 두고 "준비 중" 으로 남는다.

## 판단 두 가지

**픽스처를 배포 루트에서 뺐다.** 번들을 처음 구웠더니 팩이 4개였다 — 포맷 스펙
픽스처 `polyglot-mvp`(3언어 3편)가 섞였고, 팩 정렬이 사전순이라 학습자의 **첫 파이썬
레슨이 샘플 f-string 레슨**이 될 뻔했다. 제외 목록을 build-app.sh 에 박는 대신
`Content/fixtures/polyglot-mvp` 로 옮겼다. 특례가 세 곳(빌드 스크립트·개발 폴백·
테스트)에 각각 생기는 것을 한 번의 이동으로 없앤다. `Content/packs` 는 이제
"앱이 번들하는 것" 만 담고, CI 게이트는 두 루트를 모두 검증한다.

**`PackSQLSeed` 를 Tools 에서 ContentKit 으로 옮겼다.** 앱도 SQL 과제를 채점하려면
`assets/*.sql` 로 데이터베이스를 구워야 한다. 60줄을 복사해 두 벌로 두면 검증기가
보는 데이터베이스와 앱이 보는 데이터베이스가 갈린다 — 그러면 게이트는 아무것도
보장하지 못한다. `ContentPack` 이 양쪽의 유일한 팩 창구인 것과 같은 이유다.

## 검증

번들을 굽고(`콘텐츠 팩 3개 번들`) 스토어를 지운 뒤 앱을 실제로 띄워 스냅샷을 찍었다 —
Python·SQL·Swift 세 행이 각각 `0 / 12` 칸과 팩에서 온 실제 첫 레슨 제목("01 첫 코드
실행: print()로 화면에 출력하기" 등)을 그리고, 오류 알림은 없다. 설치 결과도 확인:
`ContentPacks/polyglot-{python,sql,swift}/0.1.0` + `current`.
LearnKit 801 테스트(RunnerKit 제외) · Tools 309 테스트 통과. `PackLibrary` 테스트 8건이
설치 멱등성·포인터 복구·스테이징 청소·리포의 실제 세 팩 36편을 고정한다.