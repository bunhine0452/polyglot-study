# CI 게이트

이 저장소에는 git 원격이 없다(`git remote -v` 가 비어 있다) — 즉 아래 워크플로는
**한 번도 GitHub Actions 위에서 돌아본 적이 없다.** 이 문서는 무엇을 로컬에서
실제로 실행해 증명했고, 무엇을 실행 없이 설계·문서 검토로만 판단했는지를 구분해
적는다. "돌려봤다"고 쓴 것은 전부 이 워크트리에서 실제로 돌린 것이다.

## 파일 지도

| 파일 | 역할 |
|---|---|
| `.github/workflows/pr-checks.yml` | PR 필수 체크 3종. 얇다 — 로직은 전부 `scripts/`. |
| `.github/workflows/lessongen-manual.yml` | `lessongen` 을 `workflow_dispatch` 로만 수동 실행. |
| `scripts/ci-run-swift-tests.sh` | 게이트 1 — `swift test` (LearnKit + Tools). |
| `scripts/ci-validate-packs.sh` | 게이트 3 — `packtool validate` 팬아웃 + 변경 감지. |

게이트 2(`build-app.sh`)는 이미 `App/Scripts/build-app.sh` 로 존재해서 워크플로가
직접 호출한다 — 이 저장소 몫이 아닌 스크립트를 감싸는 별도 wrapper 를 만들지 않았다.

## PR 게이트 3종

세 잡 모두 `macos-14` 러너에서, **모든 PR 에 항상** 트리거된다(`on.pull_request`
에 `paths:` 필터를 걸지 않는다).

### 왜 workflow 레벨 `paths:` 필터를 쓰지 않았나

`{#ci-gate}` 는 "packtool validate 를 packs 변경 PR 의 필수 체크로" 라고 적혀
있다. 가장 직관적인 구현은 워크플로 자체를
`on: pull_request: paths: ['Content/packs/**']` 로 거는 것이지만, 이건 GitHub
Actions 의 알려진 함정을 밟는다 — **필수 체크로 지정된 워크플로가 path 필터에
안 걸려 아예 안 도는 PR 은, 그 체크가 영영 "Expected — Waiting" 상태로 남아
머지를 막는다.** (워크플로가 안 도니 성공도 실패도 아닌 상태로 고정된다.)

그래서 워크플로는 항상 돌게 하고, **`scripts/ci-validate-packs.sh` 내부에서**
`git diff --name-only "$PR_BASE_SHA...HEAD" -- Content/packs` 로 변경을 감지해
없으면 즉시 통과한다. "필수 체크다"와 "packs 변경 PR 에서만 실제로 게이트가
선다"가 이렇게 동시에 성립한다.

이 diff 로직은 **로컬에서 실제 커밋 두 개로 검증했다** — 아래 "실행으로 확인한
것" 참고. GitHub Actions 의 `pull_request` 이벤트 컨텍스트(`github.event.
pull_request.base.sha`)가 실제로 원하는 값을 주는지는 **첫 실 PR 에서만
확인된다.** `fetch-depth: 0` 으로 체크아웃해 히스토리를 전부 가져오는 것까지가
로컬에서 재현 가능한 최대치다.

### 필수 체크로 등록하기 (저장소 설정 — 파일이 아니다)

브랜치 보호 규칙에 다음 세 잡 이름을 "Require status checks to pass" 에 추가해야
한다 — 이건 GitHub 저장소 Settings UI 작업이라 이 워크트리가 대신 할 수 없다.

- `swift test (LearnKit + Tools)`
- `build-app.sh`
- `packtool validate (packs)`

### 게이트 3 — packtool validate 상세

`scripts/ci-validate-packs.sh` 는:

1. `PR_BASE_SHA` 가 있고 저장소에 존재하는 ref 면, 그 이후 `Content/packs/` 변경
   파일을 팩 루트 단위로 접어 대상으로 삼는다. 변경이 없으면 즉시 `exit 0`.
2. `PR_BASE_SHA` 가 없거나(로컬 수동 실행) 해석 불가능한 ref 면(예: 얕은
   체크아웃), **안전 측으로 `Content/packs/*/manifest.json` 이 있는 모든 팩을
   검증한다** — "탐지를 못 했으니 그냥 통과"가 되지 않게.
3. 각 팩에 `packtool validate <dir> --report junit -o <파일>` 을 돈다.
   `--allow-missing-toolchain` 을 **기본으로 넘기지 않는다** — 이게 CI 쪽의
   toolchain-skip-policy 다. 아래 절 참고.
4. 종료 코드는 packtool 의 관례를 그대로 따른다 — 팩 검증 실패(1)와 도구/사용법
   오류(2)를 구분해서 판정한다. 팩 하나가 도구 오류로 죽어도 나머지 팩은 계속
   검증해 한 번에 전체 실패 목록을 보여준다.

명시적으로 팩 경로를 인자로 주면(`scripts/ci-validate-packs.sh Content/packs/foo`)
diff 감지를 건너뛰고 그 팩만 돈다 — 로컬 점검·디버깅용 경로다.

## `{#toolchain-skip-policy}` — 툴 쪽과 CI 쪽

**툴 쪽은 이미 구현돼 있었다** (이 워크트리가 만들지 않았다) —
`Tools/Sources/PackValidate/ExecutionStage.swift` 의 `readiness(for:launcher:)` 와
`PackValidator.validate()` 가 계약을 강제한다.

- 툴체인이 없으면 **기본은 실패** — `ExecutionStage.toolchainFailure` 가
  `.execution` 단계 실패를 리포트에 추가하고, `packtool validate` 는 exit 1.
- `--allow-missing-toolchain` 을 명시해야만 건너뛰고, 그 경우 `skipNotes` 에
  사유가 남고 `stagesRun` 에서 `.execution` 이 **빠진다** — "안 돈 걸 통과로
  적지 않는다."

CI 쪽 절반은 이 정책을 **뒤집을 수 있는 스위치를 필수 체크에 절대 노출하지
않는 것**이다. `scripts/ci-validate-packs.sh` 는 `--allow-missing-toolchain` 을
환경변수(`ALLOW_MISSING_TOOLCHAIN=1`)나 명시 플래그로만 켤 수 있고, 필수 체크
워크플로(`pr-checks.yml`)는 그 변수를 **설정하지 않는다.** 즉 PR 필수 체크에서
`packtool validate` 가 통과했다는 것은 실행 게이트까지 실제로 돌았다는
뜻이다 — "스킵된 clean" 이 필수 체크를 통과하는 경로 자체가 없다.

### 검증 — 실행으로 확인한 것

이 계약(스킵 아니라 실패가 기본, 플래그로만 스킵)은 이미 `Tools` 테스트
스위트(`ExecutionGateTests` 12개)가 주입 가능한 `ReadinessProbe` 로
결정론적으로 덮고 있다. 실제 머신에 툴체인이 있으면 "없다"는 분기가 테스트에서
영영 안 돌기 때문에 이렇게 설계돼 있다(코드 주석 그대로).

```
$ swift test --package-path Tools --filter ExecutionGateTests
...
✔ Test "툴체인이 없으면 스킵이 아니라 실패가 기본이다" passed after 0.011 seconds.
✔ Test "--allow-missing-toolchain 을 명시하면 건너뛰고 그 사실이 남는다" passed after 0.011 seconds.
✔ Test run with 12 tests in 1 suite passed after 1.157 seconds.
```

**시도했지만 채택하지 않은 방법**: 지시대로 `PATH` 를 좁혀 실제 머신에서
"툴체인 없음"을 흉내내는 것을 먼저 검토했다. 코드를 읽어 보니 이 저장소의
툴체인 탐지는 `PATH` 하나만 보지 않는다 —

- `LanguageToolchain`/`ToolchainProbe` 는 `xcrun --find`·홈브루·`uv`/`pyenv`
  같은 여러 절대경로 후보를 스캔한다(HANDOFF 에 이미 기록된 사실 — python3 이
  머신에 셋 있고 감지기가 버전 정책으로 그중 하나를 고른다).
- 실행 게이트는 python·swift 모두 **`learn-launcher` 헬퍼가 있어야** `.ready`
  후보에 오른다(`ExecutionStage.readiness`). 그런데 `LauncherDiscovery.locate()`
  는 `LEARN_LAUNCHER_PATH` 환경변수가 비어 있거나 잘못돼도 **cwd 에서 위로
  올라가며 `Packages/LearnKit/.build/**/learn-launcher` 를 다시 찾는다** —
  이 디렉터리는 병렬로 도는 다른 세션이 지금 쓰고 있는 공유 빌드 캐시라
  건드리면 그쪽 빌드가 깨질 수 있다.

즉 `PATH` 를 좁히는 것만으로는 "정말 툴체인이 없는 상태"를 안정적으로
재현하지 못하고(다른 후보 경로가 여전히 잡힌다), 확실히 재현하려면 다른
세션이 쓰는 공유 빌드 산출물을 건드려야 한다 — 이번 작업 지시(`Packages/**`
불가침, 동시 세션과 충돌 회피)와 충돌한다. 그래서 이 방법은 **실행하지
않았다.** 대신 위의 결정론적 단위 테스트 실행을 증거로 채택했다 — 이쪽이
실제로 더 신뢰할 수 있는 증거다(외부 상태에 의존하지 않는다).

## `lessongen-manual.yml`

`workflow_dispatch` 전용. `args` 입력을 `swift run --package-path Tools
lessongen` 뒤에 그대로 붙인다. **이 워크플로는 실행하지 않았다** — 실행하면
실제로 OpenRouter 크레딧이 나간다(HANDOFF: "실왕복은 크레딧이 나가므로
최소로"). YAML 파싱만 `python3 -c "import yaml; yaml.safe_load(...)"` 로
확인했다. 시크릿은 `OPENROUTER_API_KEY`·`OPENROUTER_MODEL`·단계별 오버라이드
4종을 **이름으로만** 참조한다 — 값은 이 저장소 어디에도 없다.

## `{#release-ci}` 중 태그 푸시 절반은 여기 없다

`{#release-ci}` 플래너 항목은 PR 게이트 3종과 "태그 푸시 시 공증·appcast" 를
함께 묶고 있다. 후자(`{#notarize-staple-dmg}`, `{#sparkle-appcast}`)는 병렬
세션이 진행 중이라 이 워크트리가 손대지 않는다 — `pr-checks.yml` 끝에 주석으로
자리만 남겼고, `on: push: tags` 트리거는 이 파일들 어디에도 없다.

## 지시 중 확인해 보니 다른 것 — "경량 러너" 전제

플래너 `{#toolchain-skip-policy}` 항목과 이번 작업 지시 둘 다 "경량 러너는
구조·문법만 돌고 게이트로 세지 않음" 이라는 문구를 쓴다. 이걸 "ubuntu 같은
비-macOS 러너에서 구조·문법 단계만 싸게 돌린다"로 읽으면 **이 아키텍처에서는
성립하지 않는다** — 확인했다.

`Tools/Sources/PackValidate` 타깃(구조·문법·의미·실행 네 단계 전부가 이 안에
있다)은 `Package.swift` 에서 **무조건** `RunnerKit` 에 의존한다. 그리고
`RunnerKit` 의 여러 파일이 `#if os(macOS)` 가드 없이 최상단에서
`internal import Darwin` 을 한다(`SQLiteHeapLimit.swift`,
`ProcessGroupReaper.swift`, `ToolchainProbe.swift`, `BoundedCommand.swift`,
`ProcessGroupMemory.swift` 등). `Darwin` 모듈은 비-Darwin 플랫폼에 아예 없으므로,
Linux 러너에서는 `swift build --package-path Tools` 자체가 **컴파일 단계에서
실패한다** — `packtool` 바이너리가 만들어지지 않으니 구조 단계조차 돌 수 없다.
"구조·문법만 돈다"는 실행 시점의 스킵이 아니라 **빌드가 안 되는 것**이다.

그래서 이번 PR 게이트 세 잡을 전부 `macos-14` 로 고정했다(item 1 의 지시와도
일치한다). "경량 러너"를 실제로 의미 있게 읽는다면 "같은 macOS 러너에서
`--allow-missing-toolchain` 으로 실행 게이트만 생략해 더 싸게 돈다"이지,
"다른 OS 러너"가 아니다 — 그리고 위 toolchain-skip-policy 절에서 적었듯,
그런 실행은 CI 쪽에서 **필수 체크로 세우지 않는 것**이 이번 작업의 설계다.
지금은 그런 별도 저비용 macOS 잡을 추가하지 않았다 — 작업 지시가 PR 게이트를
"3게이트만" 이라고 명시했고, 팩이 하나뿐인 지금 실행 게이트 비용이 무시할
수준(로컬에서 팩 1개 전체 4단계 약 50초, 캐시 히트 시 수 초)이라 지금 추가하는
것은 YAGNI 다. 팩이 늘어나 실행 게이트가 비싸지면 재고할 항목으로 남긴다.

## 실행으로 확인한 것 / 안 한 것 — 요약

**확인함 (로컬 실행):**
- `scripts/ci-validate-packs.sh` 전 분기 — 팩 명시 인자, discover-all,
  `PR_BASE_SHA` 로 실제 두 커밋 사이 변경 팩 탐지, `PR_BASE_SHA` 가 diff 없음,
  `PR_BASE_SHA` 해석 불가 폴백, 구조 단계 실패(exit 1), 존재하지 않는 경로/
  알 수 없는 플래그(exit 2). 모두 기대한 종료 코드와 요약 출력을 냈다.
- `packtool validate Content/packs/polyglot-mvp` 4단계 전부 통과, JUnit 리포트가
  유효한 XML(`xml.dom.minidom` 파싱 확인).
- `ExecutionGateTests`(fail-by-default, allow-missing-toolchain 스킵) 12개 전부
  통과 — toolchain-skip-policy 의 실제 실행 증거.
- 두 워크플로 YAML 모두 `yaml.safe_load` 파싱 성공.

**확인 안 함 (원격이 없어서):**
- GitHub Actions 위에서 워크플로가 실제로 트리거되는지, 잡 이름이 브랜치
  보호에서 기대한 문자열과 일치하는지.
- `github.event.pull_request.base.sha` 컨텍스트가 `fetch-depth: 0` 체크아웃과
  결합했을 때 실제로 올바른 diff 를 내는지 — 로컬에서는 진짜 커밋 두 개로
  같은 `git diff` 호출을 재현했지만, Actions 러너의 체크아웃·이벤트 페이로드
  자체는 재현하지 못한다.
- `macos-14` GitHub 호스팅 러너 이미지에 기본 선택된 Xcode 가 이 프로젝트의
  Swift 6.3 툴체인 요구를 실제로 만족하는지. `swift --version`/
  `xcodebuild -version` 스텝을 각 잡 앞에 넣어 첫 실행 로그에서 바로 보이게는
  해 두었다.
- `lessongen-manual.yml` 실행 자체(비용 때문에 의도적으로 미실행).
- `actions/checkout@v4`, `actions/upload-artifact@v4` 등 마켓플레이스 액션의
  가용성 — 이 환경에 네트워크로 GitHub Marketplace 를 확인할 수 없었다. 둘 다
  GitHub 공식 액션이라 존재 자체는 거의 확실하지만 "확실하다"와 "확인했다"는
  다르다.

첫 푸시 뒤 확인해야 할 것은 정확히 이 목록이다.
