# Polyglot Study — 세션 핸드오프

`/Users/kimhyunbin/Desktop/1dev/project08` 에서 이어서 작업한다.
10개 언어(Python·Rust·C++·Go·Java·Next.js·TypeScript·SQL·Swift·Assembly)를 개별 트랙으로
학습하는 macOS 네이티브 앱. MVP 는 Python·SQL·Swift.

Swift 6.3 / SwiftUI, **macOS 14 하한 확정**, MIT 오픈소스, Developer ID 공증 배포
(App Store 는 로컬 툴체인 실행 때문에 영구 포기).

## 지금 실행할 수 있는 것 / 아직 없는 것

**앱이 뜨고, MVP 세 트랙 36편이 전부 보이고, 코드를 써서 채점까지 간다.**
도달 가능한 화면은 여섯이다 — 온보딩·대시보드·트랙·레슨·에디터·복습.

```bash
# 앱
./App/Scripts/build-app.sh && open App/.build/bundle/Polyglot.app

# 특정 화면을 바로 열기(디버그 훅)
POLYGLOT_START_DESTINATION=tracks ./App/.build/bundle/Polyglot.app/Contents/MacOS/Polyglot
POLYGLOT_START_LESSON=polyglot-swift/swift-variables-and-constants POLYGLOT_START_EDITOR=1 \
  ./App/.build/bundle/Polyglot.app/Contents/MacOS/Polyglot
# 창을 PNG 로 굽고 종료 (화면 녹화 권한이 없는 헤드리스에서도 된다)
POLYGLOT_SNAPSHOT_PATH=/tmp/shot.png POLYGLOT_SNAPSHOT_DELAY=6 ...

# 테스트 (RunnerKit 은 프로세스를 띄워서 병렬이면 물린다 — 아래 실측 참고)
swift test --package-path Packages/LearnKit --skip RunnerKitTests
swift test --package-path Packages/LearnKit --filter RunnerKitTests --no-parallel
swift test --package-path Tools

# 콘텐츠 파이프라인 — 생성 → 검증 → 수리 → 굽기 → 서명 → 검증
swift run --package-path Tools packtool validate Content/packs/polyglot-python
swift run --package-path Tools packtool build Content/packs/polyglot-python -o dist/p.tar --sign
swift run --package-path Tools packtool verify dist/p.tar.staging

# CI 게이트를 로컬에서 그대로
./scripts/ci-run-swift-tests.sh && ./scripts/ci-validate-packs.sh
./App/Scripts/verify-sparkle.sh
```

## 상태

> **⚠ 브랜치 상태부터 확인해라.** 릴리스 배선 커밋 6건이 `feat/release-wiring` 에 있고
> **아직 푸시되지 않았다.** `main` 은 `origin/main` 그대로다. 다음 세션의 첫 행동은
> 이 브랜치를 올려 PR 을 여는 것이다 (아래 "첫 할 일").
>
> ```bash
> git log --oneline origin/main..feat/release-wiring   # 6건 (feat 4 + docs 2)
> git status --short                                    # 비어 있어야 한다
> ```

- **저장소 공개**: https://github.com/bunhine0452/polyglot-study
  Pages 살아 있음 — `https://bunhine0452.github.io/polyglot-study/appcast.xml` (HTTP 200).
  앱이 실주소로 업데이트 확인까지 왕복 검증됨.
- 워킹트리 깨끗. **LearnKit 1087 + Tools 307 = 1394 테스트**, 컴파일러 경고 0.
  (Tools 가 둘 줄어든 것은 `SwiftGradingGate` 를 `RunnerKit` 으로 올리며 중복을 지웠기 때문이다.
  링커 경고 105건은 벤더 바이너리에서 나온다 — 아래 "앱 배선" 참고.)
- **전체 스위트 5회 반복 통과**(2026-09-07): LearnKit 814(RunnerKit 제외) + RunnerKit 273(직렬)
  + Tools 307, 15/15 초록.
- 플랜: `polyglot-core` **55/55(archived)**, `polyglot-surface` **54/58**, `polyglot-tutor` 0/25.
- CI **5게이트**가 PR 필수 체크로 걸려 있고 실제 러너에서 통과한 이력이 있다(PR #1) —
  swift test 셋(RunnerKit 직렬 / LearnKit 나머지 / Tools), build-app.sh, packtool validate.
- 콘텐츠: **MVP 3트랙 36편**(python·sql·swift 각 12편) 전부 4단계 게이트 통과.
  누적 생성 비용 약 $0.19, 레슨당 약 $0.005.

## 첫 할 일

1. `feat/release-wiring` 을 푸시하고 PR 을 연다. **5게이트가 초록인지 확인하고 머지**,
   그다음 `git worktree list` 로 잔여 워크트리 0개인지 보고 브랜치를 지운다.
   - CI 는 `macos-26` 러너에서 20~30분 걸린다. 게이트를 지켜보는 동안 **push 하지 마라** —
     `concurrency.cancel-in-progress` 로 자기 잡을 취소시켜 영영 완주하지 못한다.
2. 머지 후에는 **코드로 풀 수 있는 릴리스 항목이 없다**(아래). 아래 "열린 결정" 둘을
   먼저 정하는 편이 다음 작업 범위를 정한다.

## 릴리스까지 남은 것

**코드로 풀리는 것은 없다.** `{#release-wiring}` 페이즈의 배선 항목이 2026-09-07 에 전부
닫혔다 — 팩 적재(`{#app-loads-all-packs}` + `{#wire-pack-installer}`·`{#bundle-packs}`),
에디터 라우팅(`{#route-editor-screen}`), 트랙 화면(`{#screen-tracks}`), 동시 실행 상한
(`{#concurrent-spawn-limit}`). 남은 미완 항목 여섯 중 둘은 이월(`{#grammars-*}`, Assembly
트랙 착수 시점), 넷은 아래의 인증서에 막혀 있다.

**돈과 계정이 필요한 것 — 코드로 안 풀린다.**

**Developer ID Application 인증서** (Apple Developer Program, 연 $99). 없으면 ad-hoc
서명이라 다른 맥에서 Gatekeeper 가 막는다. 이게 `{#notarize-staple-dmg}` 계열 3개와
`{#release-ci}` 의 태그 잡을 전부 막고 있다. **인증서를 사기 전에는 손대지 마라** —
공증 스크립트를 붙들고 시간을 쓰게 된다.

Sparkle 자동 업데이트는 ad-hoc 서명으로도 왕복이 검증돼 있다 — 인증서는 Gatekeeper 용이지
업데이트 경로용이 아니다.

## 시작 전 반드시 읽을 것

1. `AGENTS.md` — ocul-pm 기록 규칙. **작업 단위마다 `journal_write`, 직후 `plan_update`.**
2. `.oculpm/planner/polyglot-surface.md` · `polyglot-tutor.md` — 항목마다 완료 기준이 붙어 있다.
3. `.oculpm/discussion/mac-polyglot-learning-app/discussion.md` — **하단 토의 로그의 정정 항목을
   특히.** 본문에 낡은 기록이 남아 있을 수 있고 로그가 최신이다.
4. `.oculpm/journal/20260906/` · `20260907/` — 일지 36건(14 + 22). 같은 함정을 다시 밟지 마라.
   특히 `20260907/Errors/1732_error_actor-hop-corrupts-grade-result.md` — 이번 세션이
   5회 반복에서만 잡은 결함이고, 이분법으로 좁힌 재현 표가 그대로 들어 있다.

## 작업 방식

병렬 Opus 5 세션이 잘 작동했다. 단 **순서를 지켜야 한다.**

0. **워크트리는 병합 직후 `git worktree remove` 로 뗀다.** 2026-09-07 에 27개를 방치했더니
   저장소가 **132GB** 가 됐다(각 워크트리가 자기 `.build` 를 들고, 그 안의
   `CodeEditLanguages` 하나가 패키지당 3.2GB). 정리 후 121MB 다.
1. **공유 계약을 부모가 먼저 확정하고 커밋한다.** 타깃 선언·의존성·공유 도메인 타입.
   디렉터리만 갈라주면 두 세션이 같은 개념을 각자 정의한다 — 실제로 겪었다.
2. 각 세션을 **독립 git 워크트리**(`isolation: "worktree"`)로 띄운다. `.build` 락 충돌이 사라진다.
3. 파일 소유권을 경로 단위로 배타 배정하고, 공유 파일 수정 권한은 **세션당 하나만** 준다.
4. 병합 후 **통합 검증에 세션 하나를 더 쓴다.** 각 조각이 자기 테스트를 통과해도 이어 붙였을 때만
   드러나는 결함이 매 라운드 나왔다.
5. 모든 세션에 **전체 스위트 5회 반복**을 완료 조건으로 건다. 한 번 통과는 증거가 아니다.
6. 세션에 "내 지시 중 틀린 것이 있으면 근거와 함께 보고하라"를 항상 넣는다. 자주 틀렸다.

## 검증 규칙

- **벽시계·프로세스 상태 단언은 원자적이지 않다.** 시간 예산은 관대하게, 구조 단언은 엄격하게
  (`EXPLAIN QUERY PLAN` 에 SCAN 없음 같은 것).
- 정책은 grep 테스트로 고정돼 있다 — `public import GRDB` 0건, `LearnPersistence` 밖 GRDB import
  0건, `eraseDatabaseOnSchemaChange` 0건. 깨지 마라.
- 마이그레이션 001~007 은 **절대 수정 금지**(출시 클로저 불변). 변경은 항상 새 번호.
  골든 스키마 스냅샷이 바이트로 고정돼 있고 재생성은 `LEARNKIT_REGENERATE_GOLDEN=1`.

## 실측으로 확인된 사실 — 다시 조사하지 마라

**환경**: macOS 26.6.2 / arm64, Xcode **26.6 설치됨**(`sourcekit-lsp` 동봉 — Swift LSP 조달 비용 0).
python3 이 셋 있고 로그인 셸은 `/usr/bin` 의 3.9.6 을 준다(감지기가 버전 정책으로 uv 의 3.14.3 을
고른다). `/usr/bin/java` 는 존재하지만 실행 실패하는 스텁. go·tsc 미설치.

**프로세스·격리**

- macOS 는 `RLIMIT_AS`/`RLIMIT_DATA` 를 지원하지 않는다(EINVAL). 메모리는 `proc_pid_rusage` 폴링으로만.
- `RLIMIT_NPROC` 은 프로세스 트리가 아니라 **실 uid 전체**를 센다. 절대값을 걸면 `swiftc` 가 죽는다.
- `proc_listpids(..., NULL, 0)` 은 필터를 무시하고 시스템 전체 수를 돌려준다.
- `setsid` 는 런처가 아니라 **자식**이 불러야 한다. 런처가 세션 리더면 `killpg` 가 자신을 죽인다.
- `NOTE_EXIT` 은 유실될 수 있다(부모가 rusage 폴링 중일 때). `kevent` 타임아웃을 짧게 끊어야 한다.
- `sandbox-exec` 규칙 경로는 반드시 `realpath(3)`. SBPL 은 **마지막 매치가 이긴다**(deny 를 뒤에).
- `/usr/bin/swiftc`·`/usr/bin/python3` 는 **xcrun 셰이더**다. `xcrun --find` 로 해석한 경로를
  실행해라 — 샌드박스에서 xcrun 캐시 쓰기가 거부돼 stderr 가 오염된다. 프로파일을 여는 건 탈출구다.

**서명·아카이브·배포**

- **ad-hoc 서명은 Sparkle 을 막지 않는다.** `SUUpdateValidator` 의 판정은
  `passedDSACheck || passedCodeSigning` 이라 서명 검증만 유효해도 통과한다.
  실제로 막는 것은 **dyld** 다 — Hardened Runtime 이 라이브러리 검증을 함께 켜는데
  ad-hoc 에는 Team ID 가 없어 프레임워크 로드가 거부된다. ad-hoc 일 때만
  `disable-library-validation` 을 붙인다(배포용 번들에는 붙으면 안 된다).
- Sparkle 의 `generate_keys` 와 `generate_appcast` 는 서로 다른 실행 파일이라 첫 appcast
  생성 때 키체인 승인 대화상자가 뜬다. 헤드리스에서 실패하면 `errSecUserCanceled(-128)`
  인데 Sparkle 은 "not found in the Keychain" 으로 찍는다 — 키는 멀쩡히 있다.

- **CryptoKit 의 Ed25519 는 결정적이지 않다.** 같은 키로 같은 바이트에 두 번 서명하면 다른
  64바이트가 나오고 둘 다 유효하다(논스에 난수를 섞는다). RFC 8032 의 순수 Ed25519 를
  기대하고 "서명까지 재현된다" 고 적었다가 테스트에 잡혔다. 재현성 계약은 서명 파일을
  뺀 트리 전부다.
- `/usr/bin/tar` 는 mtime·uid·gid·uname·gname 을 파일 시스템에서 읽어 결정적이지 않다.
  `TarWriter` 로 ustar 를 직접 쓴다. name 필드가 100바이트라 그보다 긴 경로는 거부한다.
- **`SDKROOT` 이 비어 있으면 swiftc 가 표준 라이브러리를 못 찾는다** — 멀쩡한 Swift 레슨이
  전부 컴파일 실패로 뒤집힌다. 실행 게이트 앞에서 `xcrun` 으로 채운다.
- `SwiftTestingGrader` 는 예열된 SwiftPM 템플릿 **하나**를 공유한다 —
  `defaultTemplateDirectory` 가 **고정 경로**라 인스턴스를 새로 만들어도 같은 자리를 쓴다.
  상호 배제는 이제 **그 안에** 있다(`ExecutionLimits.swiftTemplateGate`, 2026-09-07) —
  호출자에 두면 새 호출자가 생길 때마다 같은 실수를 반복한다. 액터만으로는 부족하다
  (메서드 안에서 `await` 하면 재진입이 허용된다). 같은 종류의 버그를 세 번 밟았다.
  **`grade`/`warmUp` 을 쪼개지 마라** — 아래 "동시성" 의 마지막 항목이 이유다.

**sourcekit-lsp**

- `xcrun --find sourcekit-lsp` 로 잡힌다. `initialize` 38~50ms, `triggerCharacters: [".", "("]`.
- **디스크에 없는 URI 로도 완전히 동작한다** — 유령 경로에 `didOpen` 해도 진단과 완성이 온다.
  그래서 학습자 코드는 디스크에 닿지 않고 빈 임시 디렉터리만 `rootUri` 로 준다.
- 완성은 워밍 후 중앙값 28ms 이지만 **문서를 연 직후 첫 요청은 270ms** — 서버의 빌드 설정
  해석과 겹친다. "200ms" 는 한 번 분석된 뒤의 이야기다.
- 진단에 `code` 가 없어 `ruleID` 는 nil. 출처는 인라인 진단 행의 라벨이 진다.
- `label` 은 사람이 읽는 시그니처다. 삽입할 문자열은 `textEdit.newText`.

**테스트를 러너에서 돌릴 때**

- **RunnerKit 스위트는 병렬로 돌리면 물린다.** 실측(2026-09-07): 병렬은 25분 상한 초과에
  로그가 19분간 침묵, `--no-parallel` 은 8분 47초 통과. 같은 코드·같은 러너다. 특정
  테스트가 매달리는 게 아니라 동시에 수십 개가 `zsh -lic`·`sandbox-exec`·`swiftc` 를
  띄우면서 물린다. `RLIMIT_NPROC` 이 uid 전체를 센다는 위 실측과 맞물리는 자리다.
- 잡이 `cancelled` 로 보이는 이유는 **둘**이다 — 타임아웃 초과와
  `concurrency.cancel-in-progress`. 로그에서 구별되지 않는다. 게이트를 지켜보면서 동시에
  push 하면 영영 완주하지 못한다. 소요 시간이 타임아웃과 같으면 전자, 짧으면 후자다.
- `learn-launcher` 는 `swift build --package-path Tools` 로 **안 만들어진다**(LearnKit 의
  실행 타깃이라 Tools 의 의존성 그래프 밖). 로컬에서는 이미 빌드돼 있어 안 보이고, CI 에서
  Swift 팩 36건 실패로 처음 드러났다.
- 러너 이미지는 **`macos-26`** 이어야 한다 — macos-14 는 Swift 5.10, macos-15 는 6.1.2 라
  tools 6.2 를 못 받는다.

**동시성 — 안전 보장의 수명**

- 회수·정리 같은 **안전 보장을 취소 가능한 Task 에 매달지 마라.** 프로세스 그룹 기록이
  `awaitSpawn` 폴러 안에만 있었고, 그 폴러는 출력 드레인이 끝나면 취소된다 — 즉시 끝나는
  프로그램에서 취소가 SPAWNED 파싱을 앞지르면 그룹을 영영 모르고 손자가 남는다.
  드레인 스레드가 파싱 즉시 기록하도록 옮겼다(`LauncherStatusChannel.onSpawn`).
- 같은 종류의 버그가 넷째다. 앞의 셋은 "예열·재사용을 위해 공유한 자원에 동시 접근" 이었다.
- **문지기는 `ConcurrencyGate` 하나뿐이다**(`RunnerKit/Concurrency`). 같은 모양의 세마포어를
  세 곳에 각자 적어 두고 있었다. 액터가 **아니라** 잠금인 이유: 액터로 만들면 `withSlot` 의
  본문이 액터 위에서 돌아 본문에 `Sendable` 요구가 붙는다. 여기서는 상태만 잠금으로
  지키고 본문은 호출자의 격리에서 돈다(`isolation: isolated (any Actor)? = #isolation`).
  반납이 동기 함수인 것도 그래서다 — `defer` 안에서 `Task { await … }` 로 미루면 안전 보장이
  취소 가능한 Task 에 매달린다.
- 상한 획득 순서는 **템플릿 → 스폰**이다. 반대로 잡는 곳을 만들지 마라.
- **액터 격리 함수에서 배열을 담은 구조체를 한 단계 더 거쳐 돌려보내면 그 값이 깨진다.**
  (실측 2026-09-07, Swift 6.3.3 / Xcode 26.6) `SwiftTestingGrader.grade` 의 본문을
  `performGrade` 로 떼어 내고 `return try await performGrade(…)` 로 넘기기만 해도 돌아온
  `SwiftGrading` 의 `GradeResult.diagnostics` 가 쓰레기 포인터가 되어 `hasErrors` 에서
  `EXC_BAD_ACCESS`(0x10) 로 죽는다. 문지기를 제네릭 래퍼로 감싼 형태 6/6 재현, 게이트 없이
  단순 분할만 해도 2/2 재현, **한 함수로 되돌리면 0/5**. 게이트는 방아쇠가 아니었다 —
  한 단계 더 거치는 것 자체가 방아쇠다. 그래서 `ConcurrencyGate.withSlot` 은 `-> Void` 로
  못박혀 있고, 값을 돌려받는 자리는 `acquire()`/`release()` 를 호출부에 펼쳐 쓴다.
  이 계열의 다섯째 사고다(앞의 넷은 위 "예열·재사용 자원의 동시 접근" 과
  `@Sendable` 클로저 기본 인자의 `freed pointer was not the last allocation`).
- `NSLock.lock()`/`unlock()` 은 **async 컨텍스트에서 직접 부를 수 없다**. 읽기는 동기
  프로퍼티로 빼야 한다.

**툴체인·라이브러리**

- swiftc 에 **JSON 진단이 없다**(`-fdiagnostics-format=json` 은 clang 전용).
  `-diagnostic-style=llvm` + `-print-diagnostic-groups` 로 파싱한다.
- `swift test --event-stream-output-path` 는 `--help` 에 없지만 **실재한다**.
- `sqlite3_hard_heap_limit64` 는 macOS SDK 헤더에 선언이 없다(심볼은 존재) → `dlsym`.
- `sqlite3_error_offset()` 은 `no such table` 에 -1 을 준다.
- swift-subprocess 의 `.string(limit:)` 은 초과 시 **잘라내는 게 아니라 throw 하고 버린다.**
- `swift-fsrs` 최신 태그에는 FSRS-6 이 **없다**. 커밋 `4fbaf20…` SHA 핀. 이미 벤더링돼 있다.
- **FSRS 퍼즈는 봉인돼 있다**(`FuzzSeal` 에 `.disabled` 케이스만). 절대 켜지 마라 — 켜는 순간
  이후 모든 `replay` 가 원본과 영영 불일치한다.
- SQLiteData 최신은 tools 6.4 라 Swift 6.3.3 으로 **해석 불가**. GRDB `ValueObservation` 을 쓴다.
- CodeEditSourceEditor 0.15.2 는 CodeEditLanguages 를 `exact` 전이 의존한다(제거 불가, 대신
  python·sql·swift 그래머가 이미 들어 있다). `alex-pinkus/tree-sitter-swift` 는 main 에
  `src/parser.c` 가 없어 `0.7.3-with-generated-files` 태그를 물어야 한다.
- Textual 은 macOS 15 라 **탈락**. `ProseRenderer` 자체 구현 — 인라인은
  `AttributedString(markdown:)` 의 `.inlineOnlyPreservingWhitespace` 에 위임, 블록만 250~400줄.

**앱 배선 — 콘텐츠 팩과 에디터**

- `Content/packs/` 는 **앱이 번들하는 것만** 담는다. 포맷 스펙 픽스처 `polyglot-mvp` 는
  `Content/fixtures/` 에 따로 산다 — 배포에 섞이면 팩 정렬이 사전순이라 학습자의 첫 파이썬
  레슨이 3편짜리 샘플이 된다. CI 게이트는 두 루트를 모두 검증한다.
- **Python 과제의 진입점은 `solution.py` 여야 한다.** 팩의 숨은 테스트가
  `from solution import …` 로 부르고 `EditorModel.defaultGrade` 가 `entryFileName` 을 그대로
  채점기에 넘긴다. `main.py` 를 주면 파이썬 12편이 전부 ImportError 로 뒤집힌다. Swift 는
  반대로 채점기가 이름을 무시하고 `Solution.swift` 로 다시 담는다(`@testable import Solution`).
- **SQL 의 참조 질의는 `solutions/` 가 아니라 `tests/` 에서 읽는다.** 배포 팩은
  `PackLayout.strippedInDistribution` 에 따라 `solutions/` 를 벗겨 낸다 — 정답 파일에 기대면
  SQL 채점이 **배포본에서만** 깨지고 개발 트리에서는 영원히 재현되지 않는다.
- 앱이 `EditorFeature` 를 링크하면서 **링커 경고 105건**이 보인다. 벤더링된
  `CodeEditLanguages` 의 프리빌드 오브젝트가 벤더 머신 경로(`/Users/Khan/Developer/…`)를
  디버그 맵에 들고 있어서다. `swift build --package-path Packages/LearnKit --build-tests`
  에서도 같은 105건이 난다 — 이 저장소의 코드와 무관하고, 컴파일러 경고는 여전히 0이다.
- 디버그 훅: `POLYGLOT_START_DESTINATION`(화면) · `POLYGLOT_START_LESSON=<packID>/<lessonID>`
  · `POLYGLOT_START_EDITOR=1` · `POLYGLOT_SNAPSHOT_PATH`/`_DELAY`(창을 PNG 로 굽고 종료).

**swift-markdown / 콘텐츠 팩**

- 디렉티브 인자에 콜론·중괄호·괄호·쉼표·큰따옴표를 못 쓴다. `@X(id: a:b)` 는 **에러 없이** `:b` 를 버린다.
- 중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 조용히 사라진다. 한 줄 본문은 마지막 `}` 까지 삼킨다.
- `Markup` 은 `Sendable` 이 아니다.
- `FileManager.enumerator(at:)` 가 베이스 경로 심볼릭 링크를 해석한다(`/var`→`/private/var`).
  접두사 자르기가 **조용히 0개**를 반환한다.
- 문법 스펙은 `docs/pack-format.md`, 샘플 팩은 `Content/fixtures/polyglot-mvp`
  (배포되지 않는 픽스처다 — 아래 "앱 배선" 참고).

**OpenRouter (`z-ai/glm-5.3-flash`)**

- **미지원 파라미터를 조용히 버린다.** 서빙 엔드포인트 23곳 중 6곳이 구조화 출력 미지원 →
  라우팅을 안 좁히면 200 과 함께 산문이 온다. `provider.require_parameters` 필수.
- **오류가 HTTP 200 에 실려 온다** → 재시도 판정은 `error.metadata.error_type`.
- 이 모델은 사고 필수, effort 는 `low/high/max` — **medium 없음**.
- Batch 변종이 프로모션가보다 **비싸다**. 동시성 제한 병렬 요청을 쓴다.
- Swift 에서 `"\r\n"` 은 Character 하나라 `split(separator:"\n")` 이 CRLF 를 뭉친다.

**튜터(`polyglot-tutor`) 전제**

- `NLContextualEmbedding` 의 CJK(ja·ko·zh)와 Latin(en) 모델은 **서로 다른 벡터 공간**이다.
  한국어 질의로 영어 문서를 벡터 검색하는 것은 이 API 로 구조적으로 불가능하다. → 영문 문서는
  FTS5, 한국어 노트·레슨은 벡터. 언어 장벽은 `Diagnostic.message` 의 영문이 건넌다.
- "다운로드 0" 이 아니다 — OS 가 CJK 88MB / Latin 111MB 를 OTA 로 받는다.
- `mlx-swift-lm` 3.31.4 에는 `traits` 도 `MLXGuidedGeneration` 도 없다.
- 첫 항목 `{#nl-embedding-spike}` 가 **게이트**다. FTS5 단독을 못 이기면 벡터 절반을 접어라.

## 시크릿

`.env` 에 `OPENROUTER_API_KEY`·`OPENROUTER_MODEL` 이 있다. `.gitignore` 로 막혀 있고
`.env.example` 만 커밋된다. **값을 로그·테스트·픽스처·커밋·일지 어디에도 남기지 마라.**
oculpm 이 `.env*` 경로를 일지 파일 목록에서 차단한다. 실왕복은 크레딧이 나가므로 최소로 —
재시도·백오프 검증은 루프백 서버로 한다.

## 열린 결정

**먼저 정해야 다음 범위가 잡히는 둘.**

- **MVP 를 3트랙 36편으로 낼 것인가, 트랙당 더 채울 것인가.** 지금 앱은 트랙당 12편을
  보여주고 그 숫자를 팩에서 읽으므로 어느 쪽이든 화면은 정직하다. 더 채운다면
  `lessongen outline` → `lesson` → `validate` 루프가 이미 돌아가고 비용은 레슨당 약 $0.005 다.
- **나머지 7개 트랙을 "준비 중" 으로 둔 채 낼 것인가.** 지금은 대시보드·트랙 화면 둘 다
  흐리게 "N 레슨 · 콘텐츠 준비 중" 으로 그린다. 릴리스에 포함해도 거짓말은 아니지만,
  10트랙을 광고하는 첫인상이 3트랙 제품과 어긋나는지가 판단할 지점이다.

**그 밖에.**

- `SubmissionRecord` 의 `passed`/`failureKind` 를 `.passed`/`.failed(kind)` 한 열거형으로 합칠지.
  지금은 도메인 타입이 DB CHECK 가 거부하는 조합을 표현할 수 있다(아무도 안 밟고 있음).
- 튜터 착수 시점. 콘텐츠 파이프라인을 끝내고 가는 게 순서상 맞다.
- 디자인은 `design/` 에 스위스 그리드 아트보드 7종이 있고 캔버스로 발행돼 있다. **트랙 화면은
  아트보드가 없다** — 기존 프리미티브와 8px 그리드만으로 그렸으니, 아트보드를 그리게 되면
  `TracksView` 가 그 기준으로 다시 맞춰져야 한다.
- `TrackCatalog` 의 계획 총수(Python 24 · SQL 22 · Swift 24)와 실제 팩(각 12편)이 다르다.
  앱은 콘텐츠가 있는 트랙의 총수를 **팩에서** 읽으므로 화면은 정직하지만, 카탈로그의 숫자는
  준비 중 7트랙에만 쓰인다. 트랙을 더 채울지 정하면 이 값도 함께 정리해야 한다.
