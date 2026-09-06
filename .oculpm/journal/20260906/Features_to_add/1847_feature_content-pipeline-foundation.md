---
schema_version: 1
type: feature
slug: "content-pipeline-foundation"
status: done
difficulty: high
created_at: "2026-09-06T18:47:43+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/ContentKit"
    op: create
  - path: "Packages/LearnKit/Tests/ContentKitTests"
    op: create
  - path: "docs/pack-format.md"
    op: create
  - path: "Content/packs/polyglot-mvp"
    op: create
  - path: "Tools"
    op: create
  - path: "Packages/LearnKit/Sources/LearnPersistence/Migrations/M007CardStateDifficulty.swift"
    op: create
  - path: "Packages/LearnKit/Tests/LearnPersistenceTests/CardStateRebuildRealE2ETests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/LearnPersistenceTests/Migration007Tests.swift"
    op: create
  - path: "Packages/LearnKit/Package.swift"
    op: update
  - path: ".gitignore"
    op: update
related:
  - ref: "20260906/Features_to_add/1746_feature_core-completion-round2.md"
    kind: "followup"
tags:
  - "content"
  - "parallel"
  - "swift-markdown"
  - "anthropic"
  - "migration"
  - "mcp-tool"
---
[x] 콘텐츠 파이프라인 기반 — 팩 포맷·레슨 파서·Tools 패키지·마이그레이션 007

Opus 5 세션 3개를 병렬로 돌려 콘텐츠 파이프라인의 기반을 세웠다. `LearnKit` **607개**, `Tools` **69개** — 합계 676 테스트 전부 초록, 양쪽 빌드 경고 0.

## 추가 기능

- **ContentKit** — 팩 디렉터리 레이아웃과 `manifest.json` v1, 정규 바이트 규칙, `stableids.lock`, 디렉티브 스펙, `MarkupWalker` 기반 레슨 파서, 원자적 설치·롤백과 경로 하드닝. 샘플 팩 `Content/packs/polyglot-mvp` 와 `docs/pack-format.md` 포함.
- **Tools 패키지** — 별도 SPM 패키지. `lessongen` 의 Anthropic 클라이언트(`URLSession` 직접 호출), 키 취급, `outline` 커맨드. `packtool` 은 의도적 스텁.
- **마이그레이션 007** — `card_state.difficulty` 의 CHECK 를 새 카드 센티널(0)이 통과하도록 완화.

## 동작 흐름

디렉티브 인자는 **식별자·열거 토큰·팩 상대경로·정수 넷뿐**이고 헤더는 한 줄에 끝난다. 자유 텍스트는 전부 본문 하위 디렉티브(`@Answer`/`@Question`/`@Choice`/`@Explanation`/`@Hint`/`@Prompt`)나 사이드카(`expected/<id>.txt`)로 뺐다. swift-markdown 의 인자 문자셋 제약이 강해서 생긴 구조인데, 결과적으로 정답 문자열에 콜론·괄호가 들어가는 실제 코드를 담을 수 있게 됐다.

## 실측으로 방어한 함정 넷

1. **`@X(id: a:b)` 는 에러 없이 `id="a"` 로 파싱되고 `:b` 가 사라진다.** 조용한 유실이라 파싱 결과를 정규형으로 되짚어 원문과 대조하고 불일치면 거부한다.
2. **`@X { y } z }` 는 마지막 중괄호까지 삼킨다.** 트리를 보기 전에 렉시컬 사전 검사로 거부한다. 펜스 코드 블록 안은 건너뛰고 디렉티브 이름은 대문자 시작만 인정해 `@dataclass` 오탐을 막는다.
3. **`FileManager.enumerator(at:)` 가 베이스 경로 심볼릭 링크를 해석한다** (`/var` → `/private/var`). 접두사 자르기 방식이 **조용히 0개**를 반환한다. 자체 재귀 워커로 교체했다.
4. **테스트 헬퍼를 `deinit` 기반 RAII 로 만들면 ARC 가 마지막 사용 직후 임시 디렉터리를 날린다.** 설치 테스트가 무작위로 깨진다 — `withTemporaryDirectory { }` 스코프로 수명을 고정했다.

## 마이그레이션 007 — 도메인 기본값과 DB 제약의 불일치

`CardSchedulingState.difficulty` 는 새 카드에서 0(FSRS 관례상 첫 복습 전까지 미정의)인데 `chk_card_state_difficulty` 가 `1.0..10.0` 을 요구해 **한 번도 복습하지 않은 카드는 저장 자체가 불가능**했다. 스키마는 새 카드를 담으려는 의도가 분명했다 — `state IN ('new', …)` 를 허용하고 due 큐의 `introducing` 버킷이 그 행을 읽는다.

아무도 못 잡은 이유: 스케줄링 테스트는 CHECK 없는 인메모리 페이크, 영속화 테스트는 손으로 넣은 유효값, 재구축 드라이버는 복습 1회 이상인 카드만 쓴다.

센티널은 `difficulty = 0.0 OR (1.0 ≤ x ≤ 10.0)`. nullable 을 버린 근거가 006 과 다르다 — 006 의 `NULL` 후보는 "모른다"였지만 여기 0 은 **정의된 도메인 값**이다. 짝인 `stability` 가 이미 0 을 쓰고 CHECK 가 그걸 받는 것도 근거다. `state='new'` 와 교차 구속하는 안은 **일부러 거절**했다 — 캐시 행의 두 컬럼을 묶으면 스케줄러가 낸 조합 하나가 어긋나는 순간 저장이 실패하고, 그게 이번에 고친 사고와 같은 종류다.

SQLite 함정 둘: `ALTER TABLE RENAME` 이 뷰 안 참조를 자동으로 고쳐 쓰므로 **뷰를 먼저 DROP**, 새 테이블을 나중에 rename 하면 저장된 SQL 의 이름 토큰에 따옴표가 붙으므로 **헌 테이블 쪽 이름을 바꾸고 최종 이름으로 CREATE**.

## 검증

`swift test` 607개 3회 반복 무실패, `Tools` 69개. 테이블 재생성 전후 스키마 동일성은 두 각도로 확인했다 — `card_state` 밖은 바이트 비교(인덱스 2개와 `card_state_stale` 뷰 원문 보존), 안은 `PRAGMA table_info`/`index_xinfo`/`foreign_key_list` 구조 비교 + CHECK 를 괄호 균형으로 파싱해 이름→식 사전 대조. 007 등록을 잠시 주석 처리해 E2E 6케이스가 전부 빨개지는 것도 실측했다.

Tools 세션은 안전 검사기 없이 반환돼 병합 전 직접 훑었다 — 변경이 전부 `Tools/` 안, 외부 호스트는 `api.anthropic.com` 과 루프백 테스트 서버뿐, 하드코딩 키 0건, 프로세스 실행 API 없음.

## 메모

**Anthropic 실왕복은 하지 않았다.** 이 환경에 `ANTHROPIC_API_KEY` 가 없다. 대신 로컬 루프백 HTTP 서버로 진짜 소켓 왕복 3건(헤더 전송, 429→529→200 재시도, 연결 거부)을 태웠고 조립·해석·백오프는 순수 함수로 오프라인 검증했다. `{#lessongen-http-client}` 의 "왕복 1회 성공"은 키를 가진 사람이 한 번 태워야 닫힌다 — 롤업상 부모가 done 으로 보이므로 plan-log 에 명시했다.

`claude-api` 스킬에서 확인한 것 중 계획을 바꾼 것: Opus 5 는 거절 시 서버측 fallback 이 기본 활성화인데 **Batch API 에서는 그 파라미터가 거절된다.** `{#lessongen-batch-fanout}` 붙일 때 빼야 한다.