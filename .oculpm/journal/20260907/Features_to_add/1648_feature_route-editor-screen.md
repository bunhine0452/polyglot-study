---
schema_version: 1
type: feature
slug: "route-editor-screen"
status: done
difficulty: high
created_at: "2026-09-07T16:48:22+09:00"
session_id: "20260907-004"
agent:
  id: "claude-code"
  session: "cedda3a8-2bf7-45b2-a0ee-3cd061225de6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/Features/EditorFeature/EditorTaskLoading.swift"
    op: create
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: "App/Package.swift"
    op: update
  - path: "App/Sources/PolyglotApp/Composition.swift"
    op: update
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: update
  - path: "Packages/LearnKit/Tests/EditorFeatureTests/PackTaskLoadingTests.swift"
    op: create
related:
  - ref: "20260907/Features_to_add/1639_feature_app-loads-all-packs.md"
    kind: "followup"
tags:
  - "release-wiring"
  - "editor"
  - "contentkit"
  - "sql"
  - "mcp-tool"
---
[x] 에디터 화면을 셸에 라우팅했다 — 과제 블록에서 채점까지 이어진다

`{#route-editor-screen}`. `EditorFeature`·`EditorUI`·`LSPKit` 이 앱에 **링크조차** 안 돼
있었다. 코드를 못 쓰는 코딩 학습 앱은 릴리스할 수 없다.

## 추가 기능

- **`EditorTask.load(pack:task:…)`** — 팩의 `@Task` 블록을 화면 값으로 옮긴다.
- **`Composition.makeEditor`** — 레슨 모델에서 헤더 문구를 물려받고, SQL 이면 시드
  데이터베이스를 붙인다.
- **셸 라우팅** — 에디터는 레슨 위에 얹히고 뒤로 가면 레슨이 그대로 남는다.
- **디버그 훅** `POLYGLOT_START_LESSON=<packID>/<lessonID>` (+ `POLYGLOT_START_EDITOR=1`).
  `POLYGLOT_START_DESTINATION` 과 같은 자리다 — 스냅샷으로 특정 화면을 굽거나 개발 중
  매번 클릭하지 않기 위해서다.

## 동작 흐름

대시보드 "이어서" → `LessonModel(onOpenEditor:)` → 과제 블록의 "에디터에서 열기" →
셸이 `EditorModel` 로 화면을 갈아 끼운다 → 실행/제출이 진짜 백엔드(`swiftc`·
`PythonUnittestGrader`·`InProcessRunner`+`SQLResultSetGrader`)를 탄다.

## 변환을 EditorFeature 에 둔 이유 — 그리고 거기서 드러난 함정 둘

`EditorTask` 의 주석은 이 변환을 "앱 계층이 맡는다" 고 적어 두었었다. `EditorFeature`
에 `ContentKit` 을 붙여 여기로 옮겼다. 규칙이 `packtool` 의 실행 게이트(`BlockGate`)와
**글자 하나까지 같아야** 하는데, 앱 계층에는 그 대조를 테스트로 고정할 자리가 없다.
옮기자마자 게이트와 대조해야만 보이는 것 둘이 나왔다.

1. **Python 진입점은 `solution.py` 여야 한다.** 팩의 숨은 테스트가
   `from solution import …` 로 모듈을 부르고(`docs/pack-format.md` 의 언어별 규약),
   `EditorModel.defaultGrade` 가 `task.entryFileName` 을 그대로 채점기에 넘긴다.
   `main.py` 를 줬으면 파이썬 12편이 전부 ImportError 로 뒤집혔을 것이다. Swift 는
   반대로 채점기가 이름을 무시하고 `Solution.swift` 로 다시 담으므로(그래야
   `@testable import Solution` 이 선다) 실행 버튼용 `main.swift` 로 둔다.
2. **SQL 의 참조 질의는 `solutions/` 가 아니라 `tests/` 에서 온다.** `BlockGate` 가
   SQL 에서만 `tests` 를 `reference` 로 넘기는 것과 같은 규칙인데, 이유가 취향이
   아니다 — 배포 팩은 `PackLayout.strippedInDistribution` 에 따라 `solutions/` 를
   **벗겨 낸다.** 정답 파일에 기댔으면 SQL 채점이 **배포본에서만** 깨졌을 것이다.
   개발 트리에서는 영원히 재현되지 않는 종류의 결함이다.

SQL 시드는 팩당 한 번 굽고 재사용한다. 실행기가 매 실행마다 복제본을 쓰므로
(`SQLDatabaseClone`, APFS copy-on-write) 쓰기 과제(insert-update-delete)가 다른 과제를
오염시키지 않는다. 시드를 못 구우면 nil 로 삼키지 않고 던진다 — 시드가 없으면 참조
질의가 `no such table` 로 죽고, 학습자에게는 자기 코드가 틀린 것처럼 보인다.

## 검증

조립된 `.app` 을 실제로 띄워 두 장을 찍었다. Swift 과제는 `Swift · 레슨 01 / 12` ·
`블록 4 / 6 · 테스트 과제` · `테스트 4개 통과 시 완료` 와 starter 코드가, SQL 과제는
`sqlite 3.51.0 · pack-seed.db · 읽기 전용` 이 헤더에 떴다 — 시드가 실제로 구워져
화면까지 갔다는 뜻이다.

테스트 7건이 규칙을 고정한다: 진입점 이름과 팩의 `from solution import` 대조,
SQL 참조가 `tests/` 이고 `solutions/` 와 **다름**, 과제 바 번호(`04 테스트 과제`),
세 팩의 과제가 `EditorView` 로 비트맵까지 감, 그리고 **팩에서 조립한 SQL 과제가 실제
시드 DB 위에서 solution 통과·starter 실패로 채점됨**(팩토리 주입 없이 기본 배선).
LearnKit 808 테스트(RunnerKit 제외) 통과.