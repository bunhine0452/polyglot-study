# Polyglot Study — 세션 핸드오프

`/Users/kimhyunbin/Desktop/1dev/project08` 에서 이어서 작업한다.
10개 언어(Python·Rust·C++·Go·Java·Next.js·TypeScript·SQL·Swift·Assembly)를 개별 트랙으로
학습하는 macOS 네이티브 앱. MVP 는 Python·SQL·Swift.

Swift 6.3 / SwiftUI, **macOS 14 하한 확정**, MIT 오픈소스, Developer ID 공증 배포
(App Store 는 로컬 툴체인 실행 때문에 영구 포기).

## 지금 실행할 수 있는 것 / 아직 없는 것

**아직 앱이 아니다.** `.xcodeproj` 가 없고 SwiftUI 코드가 0줄이다. 지금 있는 것은
라이브러리·CLI·테스트뿐이다.

실행 가능:

```bash
cd Packages/LearnKit && swift test          # 607개
swift test --package-path Tools             # 135개
swift run --package-path Tools lessongen --help
swift run --package-path Tools lessongen outline --language python --lessons 3
```

없는 것: 앱 타깃, DesignSystem, EditorUI, 화면 7종, packtool 실제 구현(스텁), 레슨 콘텐츠(샘플 1팩).

## 상태

- 커밋 42개, 워킹트리 깨끗. **LearnKit 607 + Tools 135 = 742 테스트**, 양쪽 빌드 경고 0.
- 플랜 3개: `polyglot-core` **55/55 완료**, `polyglot-surface` 12/53, `polyglot-tutor` 0/40.
- 동작: GRDB 마이그레이션 7단계, FSRS-6 스케줄러, SQLite 인프로세스 러너, 서브프로세스
  러너(Swift·Python 실행·채점), C 런처(rlimit·killpg), sandbox-exec 격리, 툴체인 자동 감지,
  콘텐츠 팩 포맷·레슨 파서, OpenRouter 클라이언트(실왕복 검증됨).

## 시작 전 반드시 읽을 것

1. `AGENTS.md` — ocul-pm 기록 규칙. **작업 단위마다 `journal_write`, 직후 `plan_update`.**
2. `.oculpm/planner/polyglot-surface.md` · `polyglot-tutor.md` — 항목마다 완료 기준이 붙어 있다.
3. `.oculpm/discussion/mac-polyglot-learning-app/discussion.md` — **하단 토의 로그의 정정 항목을
   특히.** 본문에 낡은 기록이 남아 있을 수 있고 로그가 최신이다.
4. `.oculpm/journal/20260906/` — 일지 9건. 같은 함정을 다시 밟지 마라.

## 다음 작업 — 두 갈래

**(A) 콘텐츠 파이프라인 완성** — `{#packtool-structural}` → `{#packtool-execution}` →
`{#packtool-report}`. 전제가 갖춰져 있다(ContentKit 공개 API + 완성된 `CodeRunner` 백엔드).
`{#task-solution-and-starter}` 가 게이트의 핵심이다 — "starter 가 이미 통과하는 무의미한 과제"가
AI 생성물의 가장 흔한 실패다. 설정된 모델(`z-ai/glm-5.3-flash`) 등급에서는 **repair 루프가
선택이 아니라 전제**다.

**(B) 처음으로 실행 가능한 앱** — `{#xcode-app-target}` → `{#designsystem-tokens}` →
`{#ds-primitives}` → `{#app-shell-chrome}` → `{#screen-onboarding}`.
온보딩 화면을 첫 화면으로 고르는 이유는 이미 동작하는 `ToolchainProbe` 에 바로 물리기 때문이다 —
목 데이터 없이 진짜 감지 결과가 뜬다. 디자인은 `design/Onboarding.dc.html` 에 있다.

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
