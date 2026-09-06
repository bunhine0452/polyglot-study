---
schema_version: 1
type: feature
slug: "ci-gate-pr-checks"
status: done
difficulty: medium
created_at: "2026-09-07T07:19:09+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Sonnet 5 (병렬 워크트리 세션)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/pr-checks.yml"
    op: create
  - path: ".github/workflows/lessongen-manual.yml"
    op: create
  - path: "scripts/ci-run-swift-tests.sh"
    op: create
  - path: "scripts/ci-validate-packs.sh"
    op: create
  - path: "docs/ci.md"
    op: create
related:
  - ref: "20260907/Features_to_add/0615_feature_packtool-validation-gate.md"
    kind: "followup"
tags:
  - "ci"
  - "github-actions"
  - "packtool"
  - "parallel"
  - "mcp-tool"
---
[x] CI 게이트 — PR 필수 체크 3종과 lessongen 수동 워크플로

병렬 워크트리 세션(Sonnet)이 구현하고 부모 세션이 병합·재검증했다.

## 추가 기능

PR 필수 체크 3게이트 — `swift test`(LearnKit + Tools) · `App/Scripts/build-app.sh` · `packtool validate`. `lessongen` 은 `workflow_dispatch` 전용 워크플로로 분리했다(실행하면 크레딧이 나간다).

## 동작 흐름

**원격 저장소가 없어 워크플로를 실제로 돌려볼 수 없다.** 그래서 검증 가능성이 설계를 결정했다 — YAML 은 얇게 두고 로직 전부를 `scripts/` 의 셸 스크립트로 뺐다. 스크립트는 로컬에서 끝까지 돌려 증명할 수 있고, 실제로 그렇게 했다.

`packtool validate` 를 "packs 변경 PR 의 필수 체크"로 거는 데는 함정이 하나 있다. 워크플로 트리거를 `paths:` 로 좁히면 **packs 를 안 건드린 PR 에서 그 체크가 영영 대기 상태로 남아** 브랜치 보호가 병합을 막는다. 그래서 워크플로는 항상 트리거하고, 변경 감지(`github.event.pull_request.base.sha` diff)를 스크립트 안에서 해 변경이 없으면 통과로 끝낸다.

`--allow-missing-toolchain` 은 스크립트가 **기본으로 넘기지 않는다.** 옵트인으로만 켜지고, 켜면 "이 실행은 필수 체크로 쓰면 안 된다"를 stderr 로 경고한다.

## 내 지시가 틀렸던 것 — "경량 러너"

플래너 항목의 "경량 러너는 구조·문법만 돌고 게이트로 세지 않음"을 부모가 "비-macOS 러너"로 읽고 지시했는데 **성립하지 않는다.** `PackValidate` 가 무조건 `RunnerKit` 을 의존하고 `RunnerKit` 의 여러 파일이 `#if os` 가드 없이 `import Darwin` 을 쓴다. Linux 에서는 "실행 게이트 스킵"이 아니라 **`packtool` 이 컴파일 단계에서 실패**해 구조 단계조차 못 돈다. 3게이트 모두 `macos-14` 로 고정했고 근거는 `docs/ci.md` 에 남겼다.

## 검증

세션 보고를 그대로 받지 않고 병합 후 부모가 다시 돌렸다.

- `./scripts/ci-validate-packs.sh Content/packs/polyglot-mvp` → 통과, 종료 코드 0, JUnit 리포트 생성
- 없는 경로 → 종료 코드 2 (검증 실패 1 과 도구 오류 2 가 갈린다)
- `grep` — 필수 체크 경로에 `--allow-missing-toolchain` 이 기본으로 실리는 곳 0건
- LearnKit 912 · Tools 300 무변

실행으로 검증되지 **않은** 것: Actions 위에서의 실제 트리거, 잡 이름과 브랜치 보호 설정의 일치, `macos-14` 러너의 기본 Xcode 버전. 첫 푸시 때 확인해야 하며 `docs/ci.md` 에 목록으로 적혀 있다.