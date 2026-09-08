---
schema_version: 1
type: feature
slug: "lesson-progress-recording"
status: done
difficulty: medium
created_at: "2026-09-08T15:36:42+09:00"
session_id: "20260908-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonContent.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/LessonModel.swift"
    op: update
  - path: "Packages/LearnKit/Sources/Features/LessonFeature/Internal/ActiveBlockCard.swift"
    op: update
  - path: "App/Sources/PolyglotApp/Composition.swift"
    op: update
  - path: "Packages/LearnKit/Tests/LessonFeatureTests/LanguagePickerTests.swift"
    op: update
related: []
tags:
  - "lesson"
  - "progress"
  - "persistence"
  - "mcp-tool"
---
[x] 레슨 진도를 실제로 저장한다 — 아무도 쓰지 않던 값을 대시보드가 읽고 있었다

`{#progress-per-lesson-not-language}` 를 하려다 더 큰 것을 발견했다. **`completeBlock`
호출처가 소스 전체에 한 곳도 없었다** — 레슨 화면이 진도를 아예 저장하지 않았고, 지금까지의
진도는 테스트 시드로만 존재했다. 대시보드는 아무도 쓰지 않는 값을 읽어 그리고 있었다.

## 추가 기능

`LessonContent` 가 `packID` 를 갖는다 — 진도가 `(PackID, LessonID)` 로 저장되므로 화면이
진도를 쓰려면 필요하다. `LessonModel` 은 주입된 클로저로 블록 완료를 적고, **어떤 언어로
풀었는지가 함께 간다**.

**`advance()` 는 떠난 자리를 적는다** — 넘어간 자리가 아니라. 다음 블록은 아직 안 끝났다.

**"레슨 마치기" 를 새로 만들었다.** `advance()` 는 마지막 블록에서 아무 일도 하지 않으므로
그 블록은 영영 기록되지 않고, 여섯 블록이 다 차야 `completed` 로 전이하는 진도가 영원히
`inProgress` 에 머문다. **레슨이 끝나는 길 자체가 없었다.**

**실패를 숨기지 않는다.** 쓰기가 실패하면 `progressFailed` 가 선다 — 학습자가 끝낸 블록이
사라진 것을 모르면 다음에 열었을 때 진도가 되돌아가 있다.

**DB 를 못 열면 아무것도 적지 않는다.** 인메모리 페이크에 적으면 앱을 닫는 순간 사라지는데
학습자는 저장된 줄 안다 — 조용히 잃는 것보다 나쁘다.

## 검증

- 신규 테스트 4건 — 떠난 블록이 기록됨, 마치기가 마지막 블록을 기록함, 실패가 드러남,
  기록기 없이도 화면이 돎
- **LearnKit 912 테스트 136 스위트 통과**, 앱 빌드 통과
- 진도 테스트만 3회 반복해 안정성 확인

## 메모

**고정 시간 대기가 전체 스위트에서 깨졌다.** 기록이 비동기라 `Task.sleep(50ms)` 뒤에 셌는데,
단독 실행에서는 통과하고 912건과 함께 돌리면 5건 중 일부만 도착한 상태에서 세어 실패했다.
시간이 아니라 **조건**(기록이 n건에 이를 때까지)을 기다리도록 바꿨다. 부하에 따라 갈리는
테스트는 통과해도 믿을 수 없다.