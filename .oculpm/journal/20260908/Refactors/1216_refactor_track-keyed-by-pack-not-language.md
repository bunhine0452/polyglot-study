---
schema_version: 1
type: refactor
slug: "track-keyed-by-pack-not-language"
status: done
difficulty: medium
created_at: "2026-09-08T12:16:38+09:00"
session_id: "20260908-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/LearnCore/Identifiers.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TrackCatalog.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/DashboardModel.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TracksModel.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TracksView.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/DashboardView.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Install/PackLibrary.swift"
    op: update
  - path: "App/Sources/PolyglotApp/Composition.swift"
    op: update
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/TestSupport.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/TracksModelTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/PsychologyDesignTests.swift"
    op: update
related: []
tags:
  - "dashboard"
  - "tracks"
  - "identifiers"
  - "refactor"
  - "mcp-tool"
---
[x] 트랙을 언어가 아니라 팩으로 묶는다 — 한 언어에 트랙 여럿이 가능해졌다

`polyglot-algorithms` 플랜의 `{#track-descriptor-pack-id}`. 알고리즘 트랙은 언어를
가로지르는 하나의 콘텐츠인데, 대시보드가 **트랙을 언어로 식별**하고 있어 설 자리가 없었다.

## 동기

`TrackDescriptor.id` 가 `languageID.rawValue` 였다. 그래서:

- 같은 언어의 두 트랙(Rust 입문 · 알고리즘)이 목록에서 한 줄로 합쳐진다
- 진도를 `[LanguageID: [LessonProgress]]` 로 묶어 서로의 진도를 먹는다
- 선택 상태가 `LanguageID?` 라 둘을 구분해 고를 수 없다

**저장 계층은 이미 옳았다** — `LessonRef` 가 `(PackID, LessonID)` 이고 진도의 PK 도 그렇다.
언어로 묶인 것은 표현 계층뿐이라 변경이 DashboardFeature 안으로 한정됐다.

## 변경 요약

**`TrackID` 신설**(LearnCore). 트랙 목록의 키다. 언어와 1:1 인 동안은 `trackID` 가 언어
이름과 같게 두어 기존 진도·선택 상태가 그대로 이어진다.

**`TrackDescriptor`** 가 `trackID` 와 `packID: PackID?` 를 갖는다. `hasContent` 는 저장하지
않고 `packID != nil` 로 파생시켰다 — 따로 들고 있으면 "콘텐츠는 있다는데 팩이 없는" 상태를
만들 수 있고 그러면 진도를 읽을 곳이 없다.

**진도 묶기**를 `[PackID: [LessonProgress]]` 로. **레슨 목록 공급자**를
`(LanguageID) -> [LessonRef]` 에서 `(PackID) -> [LessonRef]` 로. `PackLibrary` 에
`lessons(inPack:)` · `lessonCount(inPack:)` 를 더했다 — 기존 언어 기준 접근자는 남겼다.

**조립부**의 판정을 "이 언어의 팩이 있나" 에서 **"이 팩이 설치돼 있나"** 로 바꿨다. 언어로
판정하면 같은 언어의 다른 팩이 깔려 있다는 이유로 이 트랙이 열린 것처럼 보인다.

**테스트 픽스처**가 팩 하나를 모든 트랙이 공유하고 있었다. 진도를 팩으로 묶는 순간 트랙끼리
진도가 섞이므로 **트랙마다 팩 하나**(`polyglot-<lang>`)로 바꿨다 — 앱의 실제 구성과 같다.

## 검증

- 새 테스트 "한 언어에 트랙이 둘이면 따로 서고 진도가 섞이지 않는다" — 같은 `rust` 를 쓰는
  트랙 둘이 목록에 따로 서고, 입문에 3편을 심어도 알고리즘은 0편이며, 레슨의 팩이 각각
  자기 것이고, 선택이 트랙 단위로 동작한다. **언어로 묶었다면 이 테스트의 `0` 이 `3` 이 된다.**
- LearnKit 826 테스트 121 스위트 통과
- `build-app.sh` 통과 — 앱 조립·서명까지

## 메모

**복습 큐는 여전히 언어 단위다.** 카드 테이블 인덱스가 `(language_id, due_at)` 이고
`CardStateSnapshot` 에 팩이 없다. 한 언어에 트랙이 둘이면 두 줄이 같은 복습 수를 보이고
합계가 두 번 세어진다. 스키마 변경이라 이번 범위 밖 — 알고리즘 트랙이 실제로 붙기 전에
풀어야 한다.

지금 카탈로그는 여전히 언어당 트랙 하나라 **동작은 그대로다.** 이번에 바뀐 것은 능력이지
화면이 아니다.