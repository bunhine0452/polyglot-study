# Polyglot Study — 세션 핸드오프

`/Users/kimhyunbin/Desktop/1dev/project08` 에서 이어서 작업한다.
10개 언어(Python·Rust·C++·Go·Java·Next.js·TypeScript·SQL·Swift·Assembly)를 개별 트랙으로
학습하는 macOS 네이티브 앱. MVP 는 Python·SQL·Swift.

Swift 6.3 / SwiftUI, **macOS 14 하한 확정**, MIT 오픈소스, Developer ID 공증 배포
(App Store 는 로컬 툴체인 실행 때문에 영구 포기).

## 지금 실행할 수 있는 것 / 아직 없는 것

**앱이 뜬다.** `.xcodeproj` 없이 SPM `executableTarget` + 번들 조립 스크립트로 `.app` 을
만든다. 화면 다섯(온보딩·대시보드·레슨·복습·에디터콘솔/SQL결과)이 목 데이터가 아니라
실제 러너·채점기·`ToolchainProbe` 를 탄다.

실행 가능:

```bash
cd Packages/LearnKit && swift test          # 1051개
swift test --package-path Tools             # 309개

# 콘텐츠 파이프라인 — 생성 → 검증 → 수리 → 굽기 → 서명 → 검증
swift run --package-path Tools packtool validate Content/packs/polyglot-python
swift run --package-path Tools packtool build Content/packs/polyglot-python -o dist/pack.tar --sign
swift run --package-path Tools packtool verify dist/pack.tar.staging

# CI 게이트를 로컬에서 그대로
./scripts/ci-run-swift-tests.sh
./scripts/ci-validate-packs.sh

# Sparkle 왕복 (앱 조립 → 로컬 피드 → 설치 → 거부)
./App/Scripts/verify-sparkle.sh
```

없는 것: 레지스터 화면(Assembly 트랙까지 후순위 — `docs/milestones/`), 공증·DMG,
레슨 콘텐츠 2트랙(SQL·Swift 는 아직 시드 1편씩).

## 상태

- 커밋 91개, 워킹트리 깨끗. **LearnKit 1051 + Tools 309 = 1360 테스트**, 양쪽 빌드 경고 0.
- 플랜 3개: `polyglot-core` **55/55 완료**, `polyglot-surface` 48/53, `polyglot-tutor` 0/25.
- 동작: GRDB 마이그레이션 7단계, FSRS-6 스케줄러, SQLite 인프로세스 러너, 서브프로세스
  러너(Swift·Python 실행·채점), C 런처(rlimit·killpg), sandbox-exec 격리, 툴체인 자동 감지,
  콘텐츠 팩 포맷·레슨 파서, OpenRouter 클라이언트, 앱 셸과 화면 5종,
  `packtool` 4단계 검증 게이트와 결정적 배포 팩·서명, `lessongen` 생성·수리 루프,
  **sourcekit-lsp 완성·진단**, **Sparkle 자동 업데이트**, **PR 필수 체크 3게이트**,
  **파이썬 트랙 12레슨**.

## 시작 전 반드시 읽을 것

1. `AGENTS.md` — ocul-pm 기록 규칙. **작업 단위마다 `journal_write`, 직후 `plan_update`.**
2. `.oculpm/planner/polyglot-surface.md` · `polyglot-tutor.md` — 항목마다 완료 기준이 붙어 있다.
3. `.oculpm/discussion/mac-polyglot-learning-app/discussion.md` — **하단 토의 로그의 정정 항목을
   특히.** 본문에 낡은 기록이 남아 있을 수 있고 로그가 최신이다.
4. `.oculpm/journal/20260906/` · `20260907/` — 일지 27건. 같은 함정을 다시 밟지 마라.

## 다음 작업 — 남은 것은 대부분 **인프라 대기**다

`polyglot-surface` 48/53. 남은 5개 중 코드로 풀리는 것이 없다.

**(A) 막힌 것 — 사람이 자원을 줘야 한다**

- `{#notarize-staple-dmg}` 계열 3개 — **Developer ID Application 인증서**가 있어야 한다.
  지금은 ad-hoc 서명이라 다른 맥에서 Gatekeeper 에 막힌다. (Sparkle 업데이트 경로 자체는
  ad-hoc 로도 동작한다 — 아래 실측 참고.)
- `{#sparkle-appcast}` · `{#release-ci}` — **git 원격과 GitHub Pages** 가 있어야 한다.
  `SUFeedURL` 이 아직 아무도 소유하지 않은 추정 주소라 `release.sh` 가 그 호스트로는
  릴리스를 **거부한다**(`UNVERIFIED_FEED_HOSTS`). 워크플로도 실제로 트리거된 적이 없다.
- `{#grammars-escape-hatch}` — 이월. 이유와 켜는 법은 `docs/milestones/assembly-registers.md`.

**(B) 언제든 할 수 있는 것 — 콘텐츠**

파이프라인이 닫혀 있다. 파이썬 트랙 12편이 이 루프로 만들어졌고 게이트가 2편에서 결함을
잡아 `repair` 가 고쳤다. SQL·Swift 트랙도 같은 방식으로 채우면 된다.

```bash
swift run --package-path Tools lessongen outline --language sql --lessons 12 --output tracks
# 개요를 사람이 읽고 고친 뒤
swift run --package-path Tools lessongen lesson --outline tracks/sql.outline.json \
  --pack Content/packs/polyglot-sql --pack-id polyglot-sql --serialization-retries 3 --max-usd 0.20
swift run --package-path Tools packtool validate Content/packs/polyglot-sql --report json -o /tmp/r.json
swift run --package-path Tools lessongen repair --report /tmp/r.json --pack Content/packs/polyglot-sql
```

실측: 레슨당 약 $0.0023, 동시성 4에서 약 1분. 트랙 하나 $0.03 안팎.
**Swift 트랙은 채점이 SwiftPM 템플릿을 공유해 직렬화되므로**(`SwiftGradingGate`)
검증 시간이 파이썬보다 훨씬 길다.

**(C) 튜터** — `polyglot-tutor` 0/25. 첫 항목 `{#nl-embedding-spike}` 가 게이트다.

## 작업 방식

병렬 Opus 5 세션이 잘 작동했다. 단 **순서를 지켜야 한다.**

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
- `SwiftTestingGrader` 는 예열된 SwiftPM 템플릿 **하나**를 공유한다. 동시 채점은
  `SwiftGradingGate` 로 상호 배제해야 한다 — 액터만으로는 부족하다(메서드 안에서 `await`
  하면 재진입이 허용된다). 같은 종류의 버그를 세 번 밟았다.

**sourcekit-lsp**

- `xcrun --find sourcekit-lsp` 로 잡힌다. `initialize` 38~50ms, `triggerCharacters: [".", "("]`.
- **디스크에 없는 URI 로도 완전히 동작한다** — 유령 경로에 `didOpen` 해도 진단과 완성이 온다.
  그래서 학습자 코드는 디스크에 닿지 않고 빈 임시 디렉터리만 `rootUri` 로 준다.
- 완성은 워밍 후 중앙값 28ms 이지만 **문서를 연 직후 첫 요청은 270ms** — 서버의 빌드 설정
  해석과 겹친다. "200ms" 는 한 번 분석된 뒤의 이야기다.
- 진단에 `code` 가 없어 `ruleID` 는 nil. 출처는 인라인 진단 행의 라벨이 진다.
- `label` 은 사람이 읽는 시그니처다. 삽입할 문자열은 `textEdit.newText`.

**동시성 — 안전 보장의 수명**

- 회수·정리 같은 **안전 보장을 취소 가능한 Task 에 매달지 마라.** 프로세스 그룹 기록이
  `awaitSpawn` 폴러 안에만 있었고, 그 폴러는 출력 드레인이 끝나면 취소된다 — 즉시 끝나는
  프로그램에서 취소가 SPAWNED 파싱을 앞지르면 그룹을 영영 모르고 손자가 남는다.
  드레인 스레드가 파싱 즉시 기록하도록 옮겼다(`LauncherStatusChannel.onSpawn`).
- 같은 종류의 버그가 넷째다. 앞의 셋은 "예열·재사용을 위해 공유한 자원에 동시 접근" 이었다.

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

**swift-markdown / 콘텐츠 팩**

- 디렉티브 인자에 콜론·중괄호·괄호·쉼표·큰따옴표를 못 쓴다. `@X(id: a:b)` 는 **에러 없이** `:b` 를 버린다.
- 중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 조용히 사라진다. 한 줄 본문은 마지막 `}` 까지 삼킨다.
- `Markup` 은 `Sendable` 이 아니다.
- `FileManager.enumerator(at:)` 가 베이스 경로 심볼릭 링크를 해석한다(`/var`→`/private/var`).
  접두사 자르기가 **조용히 0개**를 반환한다.
- 문법 스펙은 `docs/pack-format.md`, 샘플 팩은 `Content/packs/polyglot-mvp`.

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

- `SubmissionRecord` 의 `passed`/`failureKind` 를 `.passed`/`.failed(kind)` 한 열거형으로 합칠지.
  지금은 도메인 타입이 DB CHECK 가 거부하는 조합을 표현할 수 있다(아무도 안 밟고 있음).
- 튜터 착수 시점. 콘텐츠 파이프라인을 끝내고 가는 게 순서상 맞다.
- 디자인은 `design/` 에 스위스 그리드 아트보드 7종이 있고 캔버스로 발행돼 있다. UI 착수 시
  `{#designsystem-tokens}` 의 색 12종·타입 스케일이 거기서 나온다.
