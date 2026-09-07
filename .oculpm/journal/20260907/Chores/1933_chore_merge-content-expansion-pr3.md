---
schema_version: 1
type: chore
slug: "merge-content-expansion-pr3"
status: done
difficulty: verylow
created_at: "2026-09-07T19:33:54+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "ba0d427a-9898-445d-86dd-7a33d01b4b02"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260907/Features_to_add/1914_feature_fill-mvp-tracks-to-catalog-totals.md"
    kind: "followup"
  - ref: "20260907/Chores/1822_chore_merge-release-wiring-branch.md"
    kind: "followup"
tags:
  - "release"
  - "ci"
  - "git"
  - "content"
  - "mcp-tool"
---
[x] 콘텐츠 확장 70편을 main 에 올린다 — PR #3, 5게이트 초록

MVP 3트랙 70편 확장(187 파일)을 `feat/fill-mvp-tracks` 로 올려 PR #3 을 열고 머지했다.
커밋을 `main` 에 직접 쌓지 않고 브랜치로 옮긴 뒤 PR 을 연 것은 이 저장소의 관행이
"푸시 → PR → 5게이트 → 머지 → 브랜치 정리" 이기 때문이다.

## 게이트 실측 (macos-26 러너, PR #3)

| 게이트 | 결과 | 소요 |
| --- | --- | --- |
| swift test (LearnKit) | pass | 7m27s |
| swift test (RunnerKit · 직렬) | pass | 7m25s |
| **packtool validate (packs)** | pass | **6m38s** |
| build-app.sh | pass | 6m9s |
| swift test (Tools) | pass | 4m6s |

`packtool validate` 가 PR #2 의 4m42s 에서 6m38s 로 늘었다 — 이번에는 packs 가 바뀐 PR 이라
게이트가 실제로 서서 70편의 예제·빈칸·과제를 러너에서 전부 실행했다. `scripts/ci-validate-packs.sh`
가 diff 를 보고 packs 변경이 없으면 빠르게 통과하도록 짜여 있다는 설계가 여기서 드러난다.

RunnerKit 직렬이 8m25s(PR #2) → 7m25s 로 줄었다. 같은 코드다 — 러너 편차로 본다.

## 검증

`git status -sb` 가 `## main...origin/main`, `main` = `13c6c90`(머지 커밋),
`gh api .../branches` 가 `main`·`gh-pages` 둘만 반환. `git worktree list` 1개,
`.git` 17MB — 132GB 사고의 재발 없음.

## 메모

머지 후 HANDOFF 에 남은 공백 하나를 별도 PR #4 로 올렸다 — 상류가 구조화 출력에서 소문자
리터럴 `json` 을 지운다는 실측. 일지와 PR 본문에만 있으면 다음 세션이 못 보고 같은 함정을
밟는다(3회 실패하면 `lessongen` 이 레슨을 팩에서 격리한다).