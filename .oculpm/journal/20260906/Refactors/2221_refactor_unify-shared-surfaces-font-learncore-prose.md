---
schema_version: 1
type: refactor
slug: "unify-shared-surfaces-font-learncore-prose"
status: done
difficulty: high
created_at: "2026-09-06T22:21:36+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: "Packages/LearnKit/Sources/DesignSystem/Primitives/AppFont.swift"
    op: update
  - path: "Packages/LearnKit/Sources/DesignSystem/Presenters/PresenterRoute.swift"
    op: create
  - path: "Packages/LearnKit/Sources/DesignSystem/Presenters/ResultPresentation.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/DesignSystem/Presenters/ResultTable.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/DesignSystem/Presenters/ResultPresenterView.swift"
    op: update
  - path: "Packages/LearnKit/Sources/DesignSystem/Prose/ProseParser.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Lesson/DirectiveBody.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/TrackToolchainStatus.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/OnboardingFeature/Internal/FontResolution.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/Features/DashboardFeature/Internal/DashboardFont.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/Features/ReviewFeature/Internal/ReviewFont.swift"
    op: delete
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonPresentation.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonModel.swift"
    op: update
  - path: "Packages/LearnKit/Tests/ContentKitTests/ProseRoundTripTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/DesignSystemTests/PrimitivesTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DesignSystemTests/PresenterRouterTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DesignSystemTests/ProseParserTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/LessonFeatureTests/LessonRunTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/DashboardModelTests.swift"
    op: update
  - path: "Packages/LearnKit/Tests/DashboardFeatureTests/DashboardRenderTests.swift"
    op: update
related: []
tags:
  - "designsystem"
  - "contentkit"
  - "font"
  - "markdown"
  - "mirror-types"
  - "mcp-tool"
---
[x] 공유 표면 통합 — AppFont public·DesignSystem→LearnCore 의존·Body.prose 들여쓰기 근본 수정

## 동기

병렬 화면 세션 넷이 각자 우회한 공유 표면의 구멍 셋. 뿌리는 하나 — 공유 어휘가 없어서
화면마다 사본을 만들었다. 걷어내지 않으면 화면이 늘 때마다 사본이 는다.

## 변경 요약

### 1. AppFont 를 public 으로 — 사본 넷 제거

`DesignSystem.AppFont` 가 internal 이라 `Typography` → `Font` 변환 공개 API 가 없었고,
화면 넷이 각자 헬퍼를 만들었다. 넷을 지우고 `AppFont` 하나로 통일했다.

- `OnboardingFeature/Internal/FontResolution.swift` (`Font.appSans`/`appMono`)
- `DashboardFeature/Internal/DashboardFont.swift` (`Font.dashSans`)
- `LessonFeature/Internal/LessonChrome.swift` 안의 `LessonFont`
- `ReviewFeature/Internal/ReviewFont.swift` (`Font.reviewSans`)

판단이 갈린 세 곳은 전부 AppFont 쪽을 골랐다.

- `.custom(fixedSize:)` vs `.custom(size:)` — 사본 셋은 `size:` 라 Dynamic Type 배율을
  탄다. `ResultSlotMetrics`·`LessonLayout` 이 포인트 값으로 높이를 미리 예약하므로
  글자만 커지면 예약이 깨진다.
- 폴백 실패 시 `.system` vs `.custom(폴백명)` — 사본 셋은 후자라 SwiftUI 가 조용히
  시스템 폰트로 떨어져도 관측할 방법이 없다. `resolvedSans == nil` 이 그 관측점.
- 해석 캐시 — 사본 셋은 폰트를 만들 때마다 `NSFont(name:)` 을 불렀다(스크롤 목록의
  모든 행에서 매번). `static let` 으로 한 번만 푼다.

패밀리명 두 표기(PostScript 형 `IBMPlexSansKR` / 표시명 `IBM Plex Sans KR`)를 둘 다
받는 처리를 `AppFont.resolve(_:)` 안에 넣었다 — 정확한 패밀리명, `NSFont(name:)`,
공백 제거 정규화 키의 3단계. `sans(points:)` 탈출구는 의도적으로 internal 로 남겼다.

### 2. DesignSystem 에 LearnCore 의존 — 미러 타입 제거

- `ResultPresentation`(= `GradeResult.Presenter` 사본) 삭제. `route`/`title`/
  `pendingReason` 은 `extension GradeResult.Presenter` 로. `PresenterRoute` 는 남겼다 —
  미러가 아니라 "뷰가 셋뿐"이라는 사실이다.
- `ResultTable`(= `ResultSet` 사본) 삭제. 표 프리젠터가 `ResultSet` 을 직접 그린다.
  미러에만 있던 diff 표식(`Mark`·`isMismatch`)은 채우는 코드가 한 줄도 없어 그려진
  적이 없다 — 함께 지웠다. 비교는 `RunnerKit.SQLResultDiff` 몫이고 그 모듈은 러너를
  들고 있어 디자인 시스템이 의존할 수 없다.
- 잇던 코드도 사라졌다 — `LessonPresentation.presentation(for:)`, `ResultSetBridge`,
  두 열거형의 1:1 대응을 확인하던 `LessonPresentationTests` 두 개.
- 대시보드는 `LanguageKit` 을 붙여 `TrackToolchainStatus` 가 `ModuleAvailability` 를
  그대로 실어 나르게 했다(`.probed(tool:_:)`). 재선언하던 ready·missing·stub 이
  사라졌다. 도구 이름을 따로 받는 이유는 `ModuleAvailability` 에 그게 없기 때문
  (경로와 설치 힌트뿐이고 `.missing` 에는 경로조차 없다). `.unsupported` 는 온보딩의
  `{#availability-mapping}` 판단을 그대로 따라 `.missing` 표현으로 접었다.

`Package.swift` 수정은 두 의존 추가로 한정했다. DesignSystem 은 `LearnCore` 하나만
본다 — `LanguageKit` 이 필요한 쪽은 대시보드이지 디자인 시스템이 아니다.

### 3. ContentKit.Body.prose 왕복 결함 근본 수정

**원인.** `MarkupFormatter.linePrefix(for:)` 가 노드의 조상 사슬 전체를 훑어
`parent is BlockDirective` 인 단계마다 4칸을 붙인다. `Body.prose` 가 디렉티브 본문의
자식을 **붙어 있는 채로** 포맷해서 모든 줄이 (깊이 × 4)칸 밀렸고, `trimmedWhitespace()`
는 문자열 양 끝만 깎으므로 첫 줄만 되돌아왔다. 번호 재작성은 별개 원인 —
`orderedListNumerals` 기본값이 `.allSame(1)`.

**수정.** 포맷 전에 `child.detachedFromParent` 로 노드를 떼어낸다(조상 사슬이 없어져
접두사가 0). 옵션에 `orderedListNumerals: .incrementing(start: 1)` 추가.

실측 5증상 전부 해소 — 평평한 목록, 순서 목록 번호, 인용, 코드 펜스(닫는 펜스 포함),
깊이 2 디렉티브의 8칸. `ContentKitTests/ProseRoundTripTests` 9개가 고정한다(왕복
고정점 테스트 포함).

**렌더러 방어 코드는 지웠다.** `ProseParser.strippingEmittedIndent` /
`stripOneIndentLevel` / `emittedIndentWidth` / `maximumIndentStripPasses` /
`leadingSpaceCount` 전부. 남겨 둘 이유가 없었다 — 그 규칙은 손으로 쓴 4칸 들여쓰기를
오해할 수 있는 추측이었고 이제 그 입력이 오지 않는다. 대응 테스트 4개도 정리했다.

- 남은 업스트림 한계: 저자가 `3.` 부터 시작한 목록은 여전히 `1.` 로 재작성된다
  (swift-markdown #76, `numeralPrefix(for:)` 의 FIXME). 옵션으로는 막을 수 없다.

## 검증

`swift build --package-path Packages/LearnKit` 경고 0, `swift build --package-path App`
경고 0, `swift build --package-path Tools` 성공. `swift test` 870개(857 → 870) 3회
연속 초록. 봉인 테스트 전부 생존 — 프리미티브 cornerRadius·shadow 0건, 색 리터럴
`Tokens.swift` 밖 0건, 대시보드 위협 어휘 0건, 복습 4버튼 동일성. 사본이 되살아나지
않게 화면 소스에 `NSFontManager`·`NSFont(name:`·`.custom(` 0건 grep 봉인을 추가했다.