---
schema_version: 1
type: chore
slug: "merge-release-wiring-branch"
status: done
difficulty: low
created_at: "2026-09-07T18:22:33+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "ba0d427a-9898-445d-86dd-7a33d01b4b02"
language: "ko"
verified_by_user: false
files_touched: []
related: []
tags:
  - "release"
  - "ci"
  - "git"
  - "mcp-tool"
---
[x] 릴리스 배선 6커밋을 main 에 올린다 — PR #2, 5게이트 전부 초록

직전 세션이 릴리스 배선 6커밋(feat 4 + docs 2)을 `feat/release-wiring` 에 쌓아 두고
**푸시하지 않은 채** 끝냈다. `main` 은 `origin/main` 그대로였다. 코드는 이미 검증돼 있었으므로
(전체 스위트 5회 반복 15/15, 조립된 `.app` 실행 스냅샷) 남은 일은 올려서 게이트를 받는 것뿐이었다.

## 한 일

- `feat/release-wiring` 푸시 → PR #2 (`feat: 릴리스 배선 — 앱이 팩 36편을 읽고 에디터에서 채점까지 간다`).
- CI 5게이트 대기. **게이트가 도는 동안 같은 브랜치에 push 하지 않았다** —
  `concurrency.cancel-in-progress` 가 자기 잡을 취소시킨다(이미 밟았던 함정).
- 전부 초록인 것을 확인하고 **merge 커밋**으로 머지(`06b9f7b`). squash 가 아니라 merge 를 고른 것은
  6커밋의 메시지 본문에 설계 근거(문지기가 잠금인 이유, `withSlot` 이 `-> Void` 인 이유의 재현 표)가
  들어 있어서다 — 뭉치면 그 근거가 커밋 하나의 본문으로 눌린다.
- 브랜치 정리: 로컬·원격 모두 삭제, `git fetch --prune` 으로 스테일 ref 제거.

## 게이트 실측 (macos-26 러너, PR #2)

| 게이트 | 결과 | 소요 |
| --- | --- | --- |
| swift test (RunnerKit · 직렬) | pass | 8m25s |
| swift test (LearnKit) | pass | 7m18s |
| build-app.sh | pass | 6m26s |
| packtool validate (packs) | pass | 4m42s |
| swift test (Tools) | pass | 4m23s |

5잡이 병렬로 돌아 **벽시계 약 9분**. HANDOFF 에 적힌 "20~30분" 은 잡을 갈라 병렬로 돌리기 전의
값으로 보인다 — 갈라 놓은 지금은 가장 느린 잡(RunnerKit 직렬 8m25s)이 곧 전체 소요다.
RunnerKit 직렬 8m25s 는 직전 세션의 로컬 실측 8m47s 와 거의 같다.

## 검증

`git status -sb` 가 `## main...origin/main`(어긋남 0), `git log --oneline -3` 에 머지 커밋 `06b9f7b`,
`gh api .../branches` 가 `main`·`gh-pages` 둘만 반환. `git worktree list` 1개(본체만),
`.git` 16MB — 132GB 사고의 재발 없음.

## 메모

머지 후 `polyglot-surface` 의 남은 미완 6건 중 코드로 풀리는 것은 없다. 2건은 Assembly 트랙
착수 시점으로 이월(`{#grammars-*}`), 4건은 Developer ID Application 인증서(연 $99)에 막혀 있다.
`{#release-ci}` 는 PR 게이트 절반이 실제 PR 에서 증명됐고 남은 태그 잡만 인증서를 기다리므로
`~` 에서 `!` 로 내렸다.