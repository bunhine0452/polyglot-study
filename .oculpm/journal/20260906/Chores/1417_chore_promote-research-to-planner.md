---
schema_version: 1
type: chore
slug: "promote-research-to-planner"
status: done
difficulty: high
created_at: "2026-09-06T14:17:11+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".oculpm/planner/polyglot-core.md"
    op: create
  - path: ".oculpm/planner/polyglot-surface.md"
    op: create
  - path: ".oculpm/discussion/mac-polyglot-learning-app/discussion.md"
    op: update
  - path: "LICENSE"
    op: create
  - path: ".gitignore"
    op: update
related:
  - ref: "20260906/Chores/1246_chore_mac-polyglot-app-design-discussion.md"
    kind: "followup"
  - ref: "20260906/Features_to_add/1319_feature_learnkit-core-scaffold.md"
    kind: "followup"
tags:
  - "planning"
  - "research"
  - "correction"
  - "mcp-tool"
---
[x] Opus 5 병렬 계획 4갈래를 플래너 2개로 승격 + 논의 문서 정정 9건

Opus 5 서브에이전트 4개(영속화·스케줄링 / 실행기 / 콘텐츠 / UI·배포)를 병렬로 돌려 상세 계획을 받고, 중복과 의존을 정리해 플래너로 승격했다.

## 한 일

- 라이선스를 **MIT** 로 확정하고 `LICENSE` 작성, `.gitignore` 에 Swift·Xcode 항목을 oculpm 관리 블록 바깥에 추가, 생성물 `design/polyglot-study-app.html`(2.6MB) 무시.
- 초기 커밋 `ddbd7c2` (27파일).
- 플래너 2개 생성 — 항목 한도(120)를 넘어 하나로 못 담아 **실행 순서 경계로 분할**했다.
  - `polyglot-core` — 4 페이즈 77항목 (영속화 / 스케줄링 / 격리·툴체인 / 백엔드·채점)
  - `polyglot-surface` — 5 페이즈 82항목 (팩 포맷 / packtool·lessongen·CI / UI 기반 / 화면 7개 / 배포)

## 논의 문서 정정 (토의 로그 9행 추가)

리서치가 설계 문서의 사실 오류를 여럿 잡아냈다. 계획에 전부 반영돼 있다.

- **swift-fsrs** 최신 태그 v5.0.0 에는 FSRS-6 이 없다 — `BasicSchedulerV6` 와 21-length `defaultWv6` 는 main 에만. 커밋 SHA 핀이 필수이고, 벤더링 표면도 200줄이 아니라 약 2,600줄.
- **SQLiteData** 1.12.0 은 `swift-tools-version: 6.4` 라 Swift 6.3.3 으로 해석 자체가 안 된다. 도입 보류하고 GRDB 의 `ValueObservation` 을 `AsyncSequence` 로 노출하는 쪽으로.
- **CodeEditLanguages** 는 CESE 0.15.2 의 `exact` 전이 의존이라 제거 불가. 대신 CEL 0.1.20 이 python·sql·swift 그래머를 이미 포함해 MVP 그래머 비용이 0.
- **BlockDirective 예시가 파싱되지 않는다** — 중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 조용히 버려지고, 인자 값에 콜론·괄호·따옴표를 못 쓴다. 자유 텍스트는 전부 본문 하위 디렉티브나 사이드카로 뺐다.
- **Textual** 의 `MarkupParser` 는 문서 전체를 AttributedString 으로 렌더해 대화형 컨트롤을 담을 수 없다. 산문만 태우는 하이브리드로 변경, 플랫폼 하한 macOS 15 이슈가 딸려온다.
- **로그인 셸의 python3 는 /usr/bin 의 3.9.6** 이다. 3.13.12 는 miniconda 경로라 PATH 뒤에 있다. 툴체인 감지는 PATH 첫 매치가 아니라 전수 열거 후 버전 정책으로 골라야 한다.
- **swiftc 에 JSON 진단이 없다** — `-fdiagnostics-format=json` 은 clang 전용. `-diagnostic-style=llvm` 텍스트 파싱 + `-print-diagnostic-groups` 로 ruleID 를 얻는다.
- **swift-subprocess** 의 `.string(limit:)` 은 초과 시 잘라내는 게 아니라 throw 하고 버린다 — 계약과 달라 `Buffer` 를 직접 세야 한다.
- **결정** — Pyodide 를 MVP 에서 제외하고 Python 은 로컬 `python3` 서브프로세스로. `input()` 실습 가능 여부와 무한루프 정지 확실성이 갈랐다.

## 검증

`plan_create` 응답으로 두 플랜 파일 생성과 항목 수(77 / 82)를 확인했다. 논의 문서는 `oculpm:discussion-log` 마커 2개가 그대로 남아 있음을 grep 으로 확인했고, 기존 행은 수정하지 않고 9행을 append 만 했다. 커밋 전 시크릿 스캔에서 하드코딩된 키·토큰은 0건이었다.

## 메모

플랜을 둘로 나눈 것은 도구 한도 때문이지만 경계 자체는 의미가 있다 — 콘텐츠 검증 게이트가 `CodeRunner` 백엔드를 전제하므로 core 의 4페이즈가 surface 보다 먼저다.