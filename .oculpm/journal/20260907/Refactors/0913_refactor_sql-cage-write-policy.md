---
schema_version: 1
type: refactor
slug: "sql-cage-write-policy"
status: done
difficulty: high
created_at: "2026-09-07T09:13:44+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Sources/RunnerKit/InProcess/SQLiteCage.swift"
    op: update
  - path: "Packages/LearnKit/Sources/RunnerKit/InProcess/InProcessRunner.swift"
    op: update
  - path: "Packages/LearnKit/Tests/RunnerKitTests/SQLWritePolicyTests.swift"
    op: create
  - path: "Packages/LearnKit/Tests/RunnerKitTests/SQLInProcessRunnerTests.swift"
    op: update
  - path: "Content/packs/polyglot-sql"
    op: update
related:
  - ref: "20260907/Features_to_add/0756_feature_python-track-twelve-lessons.md"
    kind: "followup"
tags:
  - "runnerkit"
  - "sqlite"
  - "security"
  - "sql-track"
  - "content"
  - "mcp-tool"
---
[x] SQL 케이지에 쓰기를 열고 그 자리에 디스크 상한을 세웠다

## 동기

SQL 트랙 12편을 굽고 실행 게이트에 태우자 두 편이 **수리로 고칠 수 없는** 실패를 냈다.

```
sql-insert-update-delete      not authorized (차단됨: INSERT category)
sql-create-table-constraints  not authorized (차단됨: PRAGMA foreign_keys = ON)
```

`InProcessRunner` 가 설계상 읽기 전용이었다 — 클론 + `READONLY` + `query_only` + authorizer + 힙 상한 다섯 겹. 학습자 SQL 을 가두려는 의도인데, 그 결과 **SQL 커리큘럼의 3분의 1(DML·DDL)을 가르칠 수 없었다.**

repair 를 돌려도 통과할 수 없는 콘텐츠라 크레딧을 쓰지 않고 멈추고 사용자 판단을 받았다.

## 변경 요약

`SQLiteCage.WritePolicy` 를 넣었다 — `.readOnly` 와 `.clonedWritable(maxPages:)`.

**여는 근거는 신뢰가 아니라 격리다.** 대상은 실행마다 새로 뜨는 클론이고 워크스페이스째 지워진다(`RunWorkspace` 의 `defer`). 원본 시드는 손대지 않고, `originalDatabaseIsNeverTouched` 가 계속 그것을 지킨다.

**대신 여섯 번째 층이 필요했다.** 읽기 전용이 **구조적으로** 막고 있던 실패 모드가 하나 있다 — 파일을 채우는 것이다.

| 조건 | 3초 뒤 |
|---|---|
| 상한 없음 | **2,266MB · 1,677만 행**, 오류 없음 |
| 16,384 페이지 | 0MB, `database or disk is full` |

기존 다섯 겹 중 **디스크를 보는 층은 하나도 없었다** — 힙 상한은 메모리, `maxRows` 는 *반환* 행 수, 벽시계는 시간이다. `max_page_count`·`page_size` 로 grep 하면 0건이었다. 쓰기가 막혀 있어 필요가 없었던 것이고, 열자 그 공백이 그대로 드러났다.

그래서 쓰기 허용과 페이지 상한을 **값 하나로 묶었다.** 따로 끌 수 없다. `max_page_count` 는 `allowedPragmas` 에 넣지 않았다 — 넣으면 학습자가 스스로 상한을 올린다. `ATTACH`/`DETACH` 는 쓰기 허용에서도 거부한다(다른 파일에 손이 닿는 통로다).

**기본값으로 켠 이유**는 이 저장소의 원칙이다 — 호출부가 다섯인데 전부 기본값을 쓰고, *검증기가 보는 것과 앱이 보는 것이 다르면 게이트는 아무것도 보장하지 못한다.* 읽기 전용이 필요한 자리를 위해 `allowsWrites: false` 는 남겼다.

## 테스트를 지우지 않고 다시 썼다

`READONLY 라서 쓰기 문장은 전부 실패한다` 는 이제 **틀린 단언**이다. 지우는 대신 둘로 갈랐다 — 읽기 전용에서는 여전히 거부되고, 기본값에서는 같은 여섯 문장이 클론 위에서 성공한다. 정책 스위치가 실제로 정책을 가르는지 보는 것이 새 계약이다.

처음에 붙였던 `클론 파일이 상한 위로 자라지 않는다` 는 **뺐다.** 실행이 끝나면 워크스페이스가 지워져 측정 시점에 파일이 없고, 결국 `1 > 0` 을 단언하는 무의미한 초록이었다. 실패할 수 없는 테스트는 없느니만 못하다.

## 검증

LearnKit 1051 → **1058**, Tools 309 무변, 빌드 경고 0. 전체 스위트 5회 반복 통과.

새 테스트 6개가 계약을 고정한다 — 클론에 실제로 써진다, `CREATE TABLE` 도 된다, 폭주 `INSERT` 가 페이지 상한에서 멈춘다, 학습자가 상한을 못 올린다, `ATTACH` 는 여전히 거부, 읽기 전용 모드는 그대로.

막혀 있던 두 레슨을 다시 생성하니 **SQL 팩이 12편 실패 0건**으로 4단계를 전부 통과한다.