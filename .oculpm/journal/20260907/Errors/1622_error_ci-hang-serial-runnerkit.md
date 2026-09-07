---
schema_version: 1
type: error
slug: "ci-hang-serial-runnerkit"
status: done
difficulty: high
created_at: "2026-09-07T16:22:12+09:00"
session_id: "20260907-003"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "ba0d427a-9898-445d-86dd-7a33d01b4b02"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/pr-checks.yml"
    op: update
  - path: "scripts/ci-assert-toolchain.sh"
    op: create
  - path: "scripts/ci-validate-packs.sh"
    op: update
  - path: "docs/ci.md"
    op: update
  - path: "HANDOFF.md"
    op: update
  - path: ".oculpm/planner/polyglot-surface.md"
    op: update
related:
  - ref: "20260907/Features_to_add/0914_feature_github-repo-and-sql-track.md"
    kind: "followup"
tags:
  - "ci"
  - "concurrency"
  - "runnerkit"
  - "measurement"
  - "disk"
  - "mcp-tool"
---
[x] CI 가 매달린 건 특정 테스트가 아니라 병렬 실행이었다

## 발생 원인

원격을 붙이고 CI 를 처음 돌리자 `swift test` 게이트가 완주하지 못했다. 네 번의 왕복으로 네 가지가 차례로 드러났고, **셋은 로컬에서 재현 불가능한 것**이었다.

**① 러너 툴체인.** `macos-14` 의 기본 Swift 가 5.10 인데 세 패키지가 tools 6.2 를 요구해 11초 만에 죽었다. 이미지를 하나씩 시도하지 않고 매트릭스로 한 번에 쟀다 — `macos-14` 5.10 · `macos-15` 6.1.2 · **`macos-26` 6.3.3**(로컬과 동일). `macos-latest` 가 아니라 `macos-26` 을 명시했다. latest 는 드리프트하고, 그때 조용히 깨지는 것보다 명시적으로 낡는 편이 낫다.

**② 내 편집 실수.** 툴체인 단언 스텝을 자동 삽입하면서 `checkout` 과 그 `with: fetch-depth: 0` 사이를 갈랐다. `with` 가 `run` 스텝에 붙어 **워크플로 파일이 통째로 거부**됐고, 잡이 하나도 안 떠서 로그도 없었다. 되돌린 뒤 파싱해서 "`run` 스텝에 `with` 없음"을 단언하고 올렸다.

**③ `learn-launcher` 가 Tools 빌드로 안 만들어진다.** LearnKit 의 실행 타깃이라 Tools 의 의존성 그래프 밖이다. Swift 팩 36건이 전부 "실행 게이트를 태울 수 없다"로 죽었는데 **같은 실행에서 SQL 팩은 통과**했고(인프로세스라 런처가 불필요) 그 대비가 원인을 바로 가리켰다. 로컬에서는 LearnKit 을 이미 빌드해 둬서 영영 안 보이는 종류다.

**④ 진짜 원인 — 병렬 실행.** 위 셋을 고치고도 LearnKit 스위트가 60분 타임아웃에 잘렸다.

## 해결 방법

로그가 답을 줬다. 빌드는 4.7분이고, 테스트 시작 3.2초 만에 스위트 8개가 통과한 뒤 **로그가 55분 30초 동안 한 줄도 없었다.** 테스트 구간의 20초 이상 공백이 딱 하나이고 그게 3,327초다. 느려서 기어간 게 아니라 한 번에 멈춘 것이다. 끝난 8개는 전부 프로세스를 안 띄우는 순수 계산이었다.

후보 셋(LSPKit·RunnerKit·나머지)을 **한 번의 push 로** 갈랐다. LSPKit 5분 42초 통과, 나머지 4분 57초 통과, **RunnerKit 만 25분 상한 초과**. 내가 유력하게 봤던 LSPKit 은 무죄였다.

그런데 병렬 로그는 범인을 안 가리켰다 — 미완료 목록에 프로세스를 안 쓰는 순수 SQL 비교 테스트까지 있었다(동시성 풀이 고갈돼 스케줄조차 안 된 것). 그래서 `--no-parallel` 로 다시 돌렸고 **8분 47초에 통과**했다.

| 실행 방식 | 결과 |
|---|---|
| 병렬(기본) | 25분 상한 초과, 34개 스위트 중 0개 종료 |
| `--no-parallel` | **8분 47초 통과** |

같은 코드·같은 러너다. 특정 테스트가 매달리는 게 아니라 **동시에 수십 개가 `zsh -lic`·`sandbox-exec`·`swiftc` 를 띄우면서 물린다.** `RLIMIT_NPROC` 이 프로세스 트리가 아니라 uid 전체를 센다는 기존 실측과 맞물리는 자리다.

`LanguageToolchain` 주석에 같은 종류의 흔적이 이미 있었다 — "8개를 동시에 돌리면 `zsh -lic` 로그인 셸이 8번 뜨고, 실측에서 그 폭풍이 실행 하나를 30초 넘게 밀어냈다." 앱은 진행 중인 Task 를 캐시해 막았지만 **테스트는 각자 독립이라 그 캐시를 공유하지 않는다.**

RunnerKit 을 직렬 잡으로 고정했다. 회피가 아니라 사용자 코드를 가두는 우리를 검사하는 스위트에 맞는 실행 방식이다. 다만 "동시에 프로세스를 많이 띄우면 물린다" 자체는 테스트만의 문제가 아닐 수 있어 `{#concurrent-spawn-limit}` 로 남겼다.

## 곁들여 — 저장소가 132GB 였다

병렬 세션이 만든 워크트리 27개를 방치했더니 각자 `.build` 를 들었고, 그 안의 `CodeEditLanguages` 하나가 패키지당 3.2GB 였다. 전부 커밋 깨끗·미병합 0건을 확인하고 제거했다. **132GB → 121MB.** `HANDOFF.md` 작업 방식에 0번으로 넣었다 — 워크트리는 병합 직후 뗀다.

## 검증

CI 5게이트가 실제 러너에서 전부 통과했다 — RunnerKit 직렬 8분 47초, LearnKit 나머지 7분 11초, Tools 4분 46초, build-app 4분 33초, packtool validate 6분 26초. PR #1 머지 완료.

## 메모

잡이 `cancelled` 로 보이는 이유가 **둘**이다 — 타임아웃 초과와 `concurrency.cancel-in-progress`. 로그에서 구별되지 않는다. 게이트를 지켜보면서 동시에 push 하면 영영 완주하지 못하고, 그렇게 몇 번을 날린 뒤에야 소요 시간으로 둘을 가릴 수 있다는 걸 알았다. 중간에 "러너가 느려서"로 잘못 보고한 것도 이 때문이다.