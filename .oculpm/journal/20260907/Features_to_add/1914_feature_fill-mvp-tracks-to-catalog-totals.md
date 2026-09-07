---
schema_version: 1
type: feature
slug: "fill-mvp-tracks-to-catalog-totals"
status: done
difficulty: high
created_at: "2026-09-07T19:14:41+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "ba0d427a-9898-445d-86dd-7a33d01b4b02"
language: "ko"
verified_by_user: false
files_touched:
  - path: "tracks/python.outline.json"
    op: update
  - path: "tracks/sql.outline.json"
    op: update
  - path: "tracks/swift.outline.json"
    op: update
  - path: "tracks/sql.notes.txt"
    op: update
  - path: "tracks/swift.notes.txt"
    op: update
  - path: "Content/packs/polyglot-python/manifest.json"
    op: update
  - path: "Content/packs/polyglot-sql/manifest.json"
    op: update
  - path: "Content/packs/polyglot-swift/manifest.json"
    op: update
  - path: "Content/packs/polyglot-python/lessons/python-csv-and-json-processing.md"
    op: correct
  - path: "Content/packs/polyglot-python/lessons/python-string-methods-split-join.md"
    op: correct
  - path: "Packages/LearnKit/Tests/ContentKitTests/PackLibraryTests.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "HANDOFF.md"
    op: update
related: []
tags:
  - "content"
  - "lessongen"
  - "packtool"
  - "mvp"
  - "mcp-tool"
---
[x] MVP 3트랙을 카탈로그 계획값까지 채운다 — 36편 → 70편

사용자가 열린 결정 둘을 닫았다 — **MVP 는 `TrackCatalog` 의 계획값까지 채우고**(python 24 ·
sql 22 · swift 24), **나머지 7트랙은 "준비 중" 으로 둔다**(코드 변경 없음). 카탈로그의 숫자와
팩의 실제 편수가 어긋나 있던 항목이 이로써 닫혔다.

## 추가 기능

3트랙 36편 → **70편**. 신규 34편 전부가 `packtool validate` 네 단계(구조·문법·의미·실행)를
통과한다. 생성 $0.106 + 수리 $0.042 + 개요 4회 ≈ **$0.116**.

## 동작 흐름

1. **개요 확장.** `lessongen outline --lessons 24|22|24` 를 돌리되 프롬프트에 기존 12편의
   slug·제목을 못 박았다. 돌아온 개요에서 앞 12편이 바이트 동일인지 확인하고, 신규분만
   원본 뒤에 이어 붙였다 — slug 가 영구 식별자라 모델이 한 글자라도 바꾸면 이미 나간
   레슨 파일·매니페스트가 고아가 된다. python 은 모델이 13편을 내놔 종속자가 없는 잎
   `inheritance-basics` 를 뺐다(유일한 선수 `classes-and-objects` 는 남는다).
2. **레슨 생성.** `--only <stableID>` 로 신규분만. sql·swift 는 `tracks/*.notes.txt` 의
   하네스 계약을 `--notes` 로 함께 넘겼다(python 은 계약이 `LessonLanguage` 에 내장).
3. **실행 게이트.** 70편 중 **12편이 실패**(python 3 · sql 2 · swift 7). `lessongen repair`
   가 12편 전부를 고쳤고 격리(3회 실패 시 팩에서 제거)까지 간 레슨은 없다.
4. **재검증.** sql 22 · swift 24 는 실패 0. python 만 2편이 남아 손으로 고쳤다(아래).

## 게이트가 잡은 계약 둘 — 노트에 박았다

- **SQL 예제는 문을 여러 개 써도 마지막 결과셋 하나만 stdout 에 나온다.** `sql-create-view`
  가 CREATE VIEW → SELECT → SELECT → DROP → CREATE → SELECT 를 이어 쓰고 expected 에 세
  결과셋을 붙였다가 실패했다. 실제 출력이 마지막 `SELECT COUNT(*) AS n_customers` 와 정확히
  일치하는 것으로 확정했다.
- **`try` 를 쓰는 `@Test` 함수에는 `throws` 가 필요하다.** `swift-capstone-word-frequency` 가
  빠뜨려 `errors thrown from here are not handled` 로 과제 전체가 컴파일 실패했다. 반대로
  `#expect(throws:)` 만 쓰는 함수는 `throws` 가 없어야 맞다 — 수리 결과가 그렇게 갈렸다.

## 손으로 고친 둘

- **`python-csv-and-json-processing`** — 상류가 구조화 출력에서 **소문자 리터럴 `json` 을
  지운다**(아래 "메모"). `repair` 로는 영영 안 고쳐져 레슨을 다시 썼다. 두 번째 수리 시도는
  `import json` 을 아예 피해 문자열 이어붙이기로 JSON 을 만들었는데, "CSV와 JSON 다루기"
  레슨이 `json` 모듈을 안 가르치는 것은 내용이 틀린 것이라 `json.dumps`/`json.loads` 와
  `ensure_ascii=False`, 그리고 "JSON 은 타입을 잃지 않는다"(loads 가 정수를 정수로 돌려준다)를
  가르치도록 개념·예제·빈칸·과제·퀴즈·회고를 새로 썼다.
- **`python-string-methods-split-join`** — expected 의 줄 끝 공백 두 칸이 지워져 대조에
  실패했다. 공백을 되살리는 대신 `print("[" + line.replace(...) + "]")` 로 바꿔 공백이
  대괄호 안에 보이게 했다. 교육 요지(replace 는 strip 과 달리 양끝 공백을 남긴다)가 더
  살고, 어떤 에디터·린터가 다시 공백을 먹어도 깨지지 않는다.

손으로 고친 뒤 매니페스트의 `bytes`/`sha256` 을 다시 계산해 넣었다 — `packtool` 에 매니페스트
갱신 명령이 없어서 구조 단계가 `brokenReference` 7건으로 막았다. `stableids.lock` 은 stableID·
경로가 그대로라 손대지 않았다.

## 검증

- `packtool validate` 세 팩 각각 **실패 0** (24 · 22 · 24 = 70편).
- `scripts/ci-validate-packs.sh` — 대상 4개(팩 3 + 픽스처 `polyglot-mvp`), 검증 실패 0 ·
  도구 오류 0, exit 0.
- 손으로 쓴 과제는 팩에 넣기 전 채점 하네스와 같은 방식으로 로컬에서 먼저 확인했다 —
  solution 5/5 통과, starter 5건 실패.
- `PackLibraryTests` 의 실제 팩 단언을 36편 → 70편(24/22/24)으로 고쳤다.

## 메모

**상류(OpenRouter → NextBit, `z-ai/glm-5.3-flash`)가 구조화 출력에서 소문자 리터럴 `json` 을
지운다.** 같은 호출 로그 안에서 모델의 `reasoning` 에는 `import json` 5건 · `csv_to_json` 5건이
있는데 `responseText` 에는 0건이고, 대신 `import`(뒤가 빈 채)와 `csv_to_` 가 온다. 블록 id 도
`csv-json-roundtrip` → `csv--roundtrip` 으로 가운데가 빠진다. 결정적 단서는 **산문의 대문자
`JSON` 은 살아남는다**는 것 — 대소문자를 가리는 문자열 제거이지 모델의 실수가 아니다.
코드펜스 언어 태그(```json)를 지우는 상류 처리로 보인다.

영향 범위: 소문자 `json` 이 반드시 들어가야 하는 레슨은 이 경로로 생성할 수 없다.
`--provider` 를 풀어도 같은 업스트림이 잡혀 회피하지 못했다. 재시도로 해결되지 않으므로
`repair` 를 3회 돌려 레슨이 팩에서 격리되기 전에 손으로 쓰는 편이 빠르다.