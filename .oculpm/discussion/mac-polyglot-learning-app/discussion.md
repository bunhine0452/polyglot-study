---
oculpm_discussion: v1
id: mac-polyglot-learning-app
title: "macOS 다국어 학습 앱 설계 — 실행 전략·UI 스택·콘텐츠 파이프라인"
status: open
created: 2026-09-06
updated: 2026-09-06
owner: claude-code
---

## 문제 정의

Python · Rust · C++ · Go · Java · Next.js · TypeScript · SQL · Swift · Assembly 10종을 **각각 독립 트랙으로** 학습하는 macOS 네이티브 앱을 Swift 로 만든다. 단순 문서 뷰어가 아니라 레슨 안에서 코드를 쓰고 실행하고 채점받는 앱이므로, 결정해야 할 축이 넷이다.

1. **실행** — 10개 언어의 코드를 무엇으로, 어떻게 안전하게 실행하는가
2. **UI** — 코드 에디터·하이라이팅·결과 표시를 어떤 컴포넌트로 세우는가
3. **콘텐츠** — 레슨 본문과 문제를 무엇으로 채우고 어떻게 검증하는가
4. **범위** — 무엇을 첫 버전에 넣고 무엇을 자르는가

이 문서는 병렬 리서치 4갈래(실행 런타임 / 에디터 UI / 앱 아키텍처 / 커리큘럼·라이선스)의 결과를 근거로 위 네 축을 정리한다. 아직 미결인 쟁점은 하단에 따로 모았다.

### 사용자가 이미 확정한 전제

| 축 | 선택 | 파생 결과 |
|---|---|---|
| 코드 실행 | **로컬 툴체인 연동** | App Sandbox 를 끈다 → Mac App Store 포기, Developer ID 공증 배포 |
| 학습 콘텐츠 | **Claude API 동적 생성** | 원문 재배포 라이선스 부담이 크게 줄어든다 (아래 참조), 대신 API 키·오프라인·품질 검증 문제가 새로 생긴다 |
| MVP 언어 | **Python + SQL + Swift** | 셋 다 이 맥에서 추가 설치 없이 실행 가능 — 실행기 3종을 즉시 검증 가능 |
| 배포 | **오픈소스 공개** | GPL 계열 의존성이 치명적이지 않다. 다만 라이선스 전염 범위는 의식적으로 골라야 한다 |

### 실측 환경 (2026-09-06, 대상 머신)

| 항목 | 값 | 의미 |
|---|---|---|
| OS / 아키텍처 | macOS 26.6.2 / **arm64** | Assembly 트랙은 ARM64(AAPCS64)가 정규 |
| **Xcode** | **미설치** (CommandLineTools 만) | **선행 작업 0번** — SwiftUI 앱 빌드 불가 |
| 설치됨 | swift 6.3.3 · python3 3.13.12 · rustc 1.98.0 · clang 21.0.0 · node 26.7.0 · sqlite3 3.51.1 · `/usr/bin/as` | MVP 3종 전부 커버 |
| 미설치 | go · java/javac · tsc · nasm | 2차 트랙에서 설치 안내 UI 필요 |
| git | **저장소 아님** | 오픈소스 공개 전 `git init` 필요 |

---

## 후보 해결 방안

### 방안 A — 전면 로컬 툴체인 {#opt-local-toolchain}

모든 언어를 사용자 머신에 설치된 컴파일러/인터프리터를 서브프로세스로 호출해 실행한다.

- **장점** — 10개 언어를 균일한 방식으로 다룬다. 실제 개발 환경과 동일해 학습 전이가 좋다. 구현이 개념적으로 단순하다.
- **단점** — 사용자가 Go·JDK·rustup 등을 직접 설치해야 하는 진입 장벽. MVP 이후 언어마다 설치 안내 UX 를 만들어야 한다. App Sandbox 를 끄므로 App Store 는 영구 포기.
- **비용** — 중. 단 언어가 늘수록 선형 증가.

### 방안 B — 인앱 런타임 우선 {#opt-inapp}

Pyodide(Python) · JavaScriptCore(TS/JS) · SQLite(SQL) · 에뮬레이터(Assembly)를 앱에 임베드해 툴체인 없이 완결한다.

- **장점** — 설치 0, 네트워크 0, 샌드박스 친화적. App Store 경로가 살아 있다.
- **단점** — **Rust·Go·Java·Swift·C++ 는 컴파일러 자체를 WASM 안에서 돌릴 수 없다.** ("언어를 wasm 으로 컴파일"과 "그 언어의 컴파일러를 wasm 에서 실행"은 다른 문제다.) 즉 10개 중 4~5개가 원천 불가. 번들 용량도 커진다(clang-wasm ~100MB).
- **비용** — 중. 단 커버리지가 근본적으로 제한됨.

### 방안 C — `CodeRunner` 프로토콜 + 백엔드 교체 (권고) {#opt-hybrid}

실행을 프로토콜 하나로 추상화하고, 언어별로 **가장 싼 백엔드**를 고른다.

```
CodeRunner (프로토콜)
├─ InProcessRunner   SQLite/DuckDB — 프로세스조차 안 띄움
├─ WebViewRunner     Pyodide, JavaScriptCore — 툴체인 0
├─ SubprocessRunner  swiftc, rustc, go, javac, clang++ — C 런처 헬퍼로 격리
├─ EmulatorRunner    Assembly — 명령어 수·타임아웃을 엔진이 강제
└─ RemoteRunner      Judge0 — 최후 폴백 (선택)
```

- **장점** — 방안 A 의 커버리지와 방안 B 의 무설치성을 언어별로 골라 가진다. MVP 3종이 정확히 서로 다른 백엔드 3개(InProcess / WebView 또는 Subprocess / Subprocess)에 걸쳐 있어 **첫 버전에서 추상화의 진위가 검증된다.** 나중에 App Store 타깃을 만들고 싶어지면 백엔드 목록만 잘라내면 된다.
- **단점** — 프로토콜 설계를 처음에 잘못 잡으면 백엔드마다 특수 케이스가 새어 나온다. → `RunnerContractTests`(모든 백엔드에 동일 적용하는 공용 계약 테스트)로 방어.
- **비용** — 초기 설계 비용이 A·B 보다 높고, 그 이후로는 가장 싸다.

---

## 쟁점별 조사 결과

### 1. 실행과 격리

**샌드박스** — App Sandbox 하에서 자식 프로세스는 부모 샌드박스를 상속하며, `com.apple.security.app-sandbox` + `com.apple.security.inherit` **딱 두 개**의 엔타이틀먼트만 가질 수 있다(다른 걸 하나라도 주면 커널이 자식을 abort). `/opt/homebrew/bin/python3` 같은 컨테이너 밖 바이너리는 애초에 읽기가 거부된다. **로컬 툴체인 노선이면 App Sandbox 를 끄는 것 외에 길이 없다.** Hardened Runtime 은 켜고, 사용자 코드는 `sandbox-exec` 프로파일로 따로 가둔다.

**자원 제한 — macOS 26.6.2 실측**

| rlimit | 결과 |
|---|---|
| `RLIMIT_CPU` · `RLIMIT_NPROC` · `RLIMIT_NOFILE` · `RLIMIT_FSIZE` | ✅ 동작 |
| **`RLIMIT_AS` · `RLIMIT_DATA`** | ❌ **EINVAL — macOS 미지원** |

**메모리 상한은 rlimit 으로 못 건다.** `proc_pid_rusage()` 폴링 후 kill 하는 수밖에 없다. 그리고 `posix_spawn` 에는 rlimit 옵션이 없으므로, 번들에 **얇은 C 런처 헬퍼**를 넣어 `fork → setsid → setrlimit(CPU/NPROC/FSIZE) → execv`, 부모는 벽시계 타임아웃에 `killpg` 하는 구조가 실무 정답이다. `setsid` + `killpg` 가 무한루프·fork bomb 방어의 실제 핵심.

**툴체인 감지의 함정** — `command -v` 판정은 **오탐한다.** 이 맥의 `/usr/bin/java` 는 존재하지만 실행하면 `Unable to locate a Java Runtime`. CLT 스텁 구조 때문이다. 반드시 `--version` 을 2초 타임아웃으로 **실제 실행해서 종료코드까지** 확인해야 한다. 또 GUI 앱은 로그인 셸 PATH 를 상속하지 않으므로(launchd), `zsh -lic` 질의 + 관례 경로 스캔(`/opt/homebrew/bin`, `~/.cargo/bin`, `~/.sdkman/...`, `~/.local/share/mise/shims`)을 병행해야 한다.

**원격 실행** — Piston 공개 API 는 **2026-02-15 부로 화이트리스트 전용**이 되어 사실상 닫혔다. Judge0 CE(`ce.judge0.com`)는 키 없이 아직 동작하며 71개 언어·비교적 최신 버전을 제공하지만 SLA 가 없다. 폴백으로만.

### 2. 에디터 UI 스택

| 후보 | 판정 |
|---|---|
| **CodeEditSourceEditor** | ✅ **1순위.** macOS 전용·SwiftUI 네이티브·tree-sitter·MIT. 결정적으로 CodeEdit(23k★)이 이 위에 완전한 LSP 를 이미 구현해둬 참조 구현이 있다. ⚠️ **main 이 9개월 정체 + "not production ready" 경고 유효** → 버전 핀 고정 + 포크 각오 |
| CodeEditorView | Apache-2.0 백업. iOS 까지 필요해지면 1순위가 뒤바뀐다 |
| STTextView | 가장 활발하지만 **GPLv3 또는 상용 듀얼** — 앱 라이선스를 강제한다 |
| **Runestone** | ❌ **iOS 전용** (`Package.swift` 가 `.iOS(.v14)` 단독). macOS 후보 아님 |
| Monaco/CodeMirror + WKWebView | 지름길이지만 네이티브 감성·단축키·접근성이 계속 어긋난다 |

**하이라이팅** — `tree-sitter/swift-tree-sitter` + `slsrepo/Neon`. ⚠️ **2026-08 에 ChimeHQ 스택이 대이동해 기존 문서의 URL 이 전부 무효다.** 10개 언어 그래머는 전부 존재하고 `Package.swift` 를 동봉하므로 SPM 직접 번들이 가능하지만 함정 둘: **`alex-pinkus/tree-sitter-swift` 의 main 에는 `src/parser.c` 가 없다** (→ `with-generated-files` 브랜치나 태그를 물어야 함), Assembly 는 `RubixDev/tree-sitter-asm`(55★)이 유일해 품질 리스크가 있다. `CodeEditLanguages` 는 그래머가 xcframework 바이너리라 확장이 막히고 정체 상태 → 쓰지 않는다. **Highlightr 는 2026년 유지보수 중단을 선언했다** — 정적 코드블록용으로는 후계 `HighlighterSwift` 를 쓴다.

**레슨 렌더링** — `swift-markdown`(swiftlang, Apache-2.0, 커밋 2026-09-03)이 **BlockDirective 를 정식 파싱**한다. 즉 퀴즈·빈칸을 정규식으로 뜯을 필요 없이 문법으로 표현할 수 있다.

```markdown
@Quiz(id: "q1", answer: "b") {
  - a) 리스트
  - b) 튜플
}
@Blank(id: 1, answer: "range") 함수는 정수 시퀀스를 만듭니다.
```

렌더러는 없으므로 `Textual`(MarkdownUI 의 후계, MIT)에 `MarkupParser` 로 꽂는 하이브리드가 실질 최적해. **MarkdownUI 는 maintenance mode, Down 은 2021년 이후 방치** — 둘 다 제외.

**출력** — NSTextView + ANSI SGR 파서로 시작(100줄), Python `input()` 같은 대화형 실습이 필요해지는 시점에 SwiftTerm(MIT, 커밋 2026-09-04, 매우 활발)으로 승격.

### 3. 데이터와 아키텍처

**영속화는 GRDB.swift.** 학습 진도·제출 이력·오답 노트는 append-heavy 이벤트 로그 + 집계/FTS 쿼리 워크로드인데, 이게 SwiftData 가 2026년에도 가장 약한 지점이다(삽입 벤치 ~20x 차이, `ModelContext`/`Predicate` 가 `Sendable` 아님, `@ModelActor` 의 격리가 생성 위치에 따라 바뀌는 미문서화 함정). SwiftUI 글루는 `SQLiteData`(Point-Free)로 상쇄하되, 리포지토리 프로토콜로 감싸 걷어낼 수 있게 둔다.

**스키마의 핵심은 `review_log` 를 절대 지우지 않는 것.** FSRS 파라미터를 재최적화하거나 알고리즘을 바꿀 때 전체 스케줄을 로그로부터 재계산해야 한다. `card_state` 는 캐시로 취급한다.

**복습 알고리즘은 FSRS-6** (2025년 말 출시, Anki 25.07 부터 기본, 사실상 표준). `open-spaced-repetition/swift-fsrs`(MIT)를 **벤더링**해 `ReviewScheduler` 프로토콜 뒤에 숨긴다 — 스케줄링 공식 자체는 200줄 이하라 소규모 패키지에 직접 의존하기보다 소스를 들고 있는 편이 안전하다. 개인화 옵티마이저는 Swift 구현이 없으므로 리뷰 1,000건 이상 쌓인 뒤 `fsrs-rs` XCFramework 로 2단계에서 붙인다.

**언어 모듈은 동적 플러그인이 아니라 정적 등록 + 데이터 팩.** `dlopen` 은 코드사이닝·공증·샌드박스 셋 다에서 비용을 치른다. 새 언어 추가는 앱 재배포로 하되, **레슨 콘텐츠는 동적으로 추가**되므로 실사용상 문제가 작다.

**Swift 6 동시성 경계는 타깃 = 격리 도메인**으로 물리화한다. UI/Feature 타깃에 `.defaultIsolation(MainActor.self)`(SE-0466), Core/Persistence/Runner 타깃은 `nonisolated` 기본 유지.

### 4. 콘텐츠와 라이선스

리서치 결과 **본문을 합법적으로 임베드할 수 있는 언어는 Rust·Go·TypeScript·Swift·Python 5개뿐**이었다. C++(learncpp 독점, Core Guidelines 는 "personal or internal business use only"), Java(Oracle All rights reserved, `devjava-content` 는 LICENSE 파일 자체가 없음), Assembly(주요 자료가 CC BY-NC-ND 또는 라이선스 없음), Next.js Learn(오픈소스 아님)은 본문 자체작성이 필수다.

**그런데 콘텐츠를 Claude API 로 생성하기로 했으므로 이 제약의 대부분이 사라진다.** 남는 것은 두 가지뿐이다.

- **데이터셋·연습문제**는 여전히 라이선스가 중요하다. 쓸 수 있는 것: SQL Murder Mystery(MIT, `.db` 파일째 번들 가능) · Select Star SQL 데이터(CC0) · Exercism 트랙 리포(전부 MIT) · Rustlings(MIT).
- **참조 문서 링크**는 재배포가 아니므로 자유롭다.

**대신 새 문제가 생긴다** — 생성 콘텐츠의 정확성 검증, 오프라인 불가, API 키 취급. 특히 **"예제 코드가 실제로 컴파일·실행되는가"를 생성 시점에 자동 검증하는 게이트**가 없으면 앱이 틀린 걸 가르치게 된다. 다행히 이 앱은 실행기를 이미 갖고 있으므로, **생성 → 실행기로 검증 → 통과한 것만 캐시**하는 파이프라인이 자연스럽다. 이건 리스크가 아니라 이 앱의 구조적 강점이다.

**커리큘럼 규모** — 10개 트랙 합계 약 228 레슨(Python 24 / Rust 26 / C++ 26 / Go 20 / Java 24 / TS 24 / Next.js 18 / SQL 22 / Swift 24 / Assembly 20). MVP 3종만 해도 70 레슨.

**레슨은 6블록 시퀀스**로 통일한다: 개념 → 실행 예제 → 빈칸 → 테스트 과제 → 퀴즈 → 회고. 언어별 이질성은 레슨 모델이 아니라 **`ResultPresenter`(콘솔 / 표 / 브라우저 / 레지스터)와 `LanguageAdapter`(채점기) 두 곳에만 가둔다.**

**MVP 3종 검증** — 사용자가 고른 Python + SQL + Swift 는 셋 다 이 맥에서 **추가 설치 없이** 동작하고, 서로 다른 백엔드·서로 다른 채점 패러다임·서로 다른 결과 뷰에 걸쳐 있다. 추상화를 검증하는 조합으로 적절하다.

| 언어 | 백엔드 | 채점 패러다임 | 결과 뷰 |
|---|---|---|---|
| SQL | InProcess (SQLite 3.51.1) | 결과셋 비교 | 표 + diff |
| Python | WebView(Pyodide) 또는 Subprocess | pytest 결과 파싱 | 콘솔 |
| Swift | Subprocess (`swiftc`, CLT) | Swift Testing 결과 파싱 | 콘솔 + 인라인 진단 |

---

## 미결 쟁점 — 판단이 필요한 것

### 쟁점 1 — Assembly 에뮬레이터 라이선스 {#issue-asm-license}

리서치 두 갈래가 충돌했다. Unicorn Engine 은 학습앱에 이상적이다 — `uc_emu_start` 가 타임아웃과 **명령어 수 상한을 엔진 차원에서 강제**하고, `UC_HOOK_CODE` 로 명령어 단위 콜백을 받아 레지스터·메모리 스냅샷을 뜰 수 있어 스텝 디버깅 UI 가 사실상 공짜로 나온다. 문제는 **GPL-2.0** 이라는 것. 오픈소스 공개를 택했으므로 치명적이지는 않지만 **앱 전체를 GPL-2.0 호환 라이선스로 강제**한다. 대안은 `jart/blink`(ISC, x86-64 전용) 또는 자체 미니 시뮬레이터(교육적으로는 오히려 우수). Assembly 는 MVP 밖이므로 **지금 결정할 필요는 없고, 다만 앱 라이선스를 고를 때 이 선택지를 남겨둘지 정해야 한다.**

### 쟁점 2 — 에디터 컴포넌트 유지보수 리스크 {#issue-editor-fork}

CodeEditSourceEditor 는 기능·라이선스·참조구현 모두 1순위지만 main 이 9개월 멈춰 있다. 지배적인 커뮤니티 포크도 아직 없다. **버전 핀 고정으로 시작하되, 6개월 안에 업스트림이 안 움직이면 포크를 뜬다**는 정책을 미리 정해두는 게 낫다.

### 쟁점 3 — API 키 취급 {#issue-api-key}

오픈소스 공개 + Claude API 생성 조합에서는 키를 리포에 넣을 수 없다. 사용자가 자기 키를 입력하고 **Keychain 에 저장**하는 구조가 기본. 파생 결정 둘: (a) 키 없는 사용자를 위해 **생성 완료된 레슨 팩을 리포에 커밋해 배포**할 것인가 — 그러면 앱이 오프라인에서도 동작한다. (b) 생성을 앱 런타임에서 할 것인가, **개발자가 CLI 로 미리 생성해 팩으로 굽는** 방식으로 할 것인가.

**(b)를 강하게 권한다.** 생성을 빌드타임으로 밀면 검증 게이트를 CI 에 걸 수 있고, 사용자는 키 없이 오프라인으로 쓰며, 런타임 API 실패 경로가 사라진다. 런타임 생성은 "이 개념 더 연습하기" 같은 **보조 기능**으로만 남긴다.

### 쟁점 4 — AI 생성 콘텐츠의 신뢰 {#issue-content-trust}

생성된 예제가 컴파일되는지, 테스트가 실제로 통과/실패하는지, 퀴즈 정답이 맞는지를 **기계로 검증하지 않으면 안 된다.** `packtool validate` 가 팩의 모든 `ExampleBlock` 을 실행기에 태워 `expectedStdout` 과 대조하고, 모든 `TaskBlock` 의 solution 이 hidden test 를 통과하는지 확인하는 게이트를 CI 필수로 건다. 이 게이트가 없는 팩은 머지하지 않는다.

---

## 권고안

**방안 C(`CodeRunner` 프로토콜 + 백엔드 교체)를 채택**하고, 아래 순서로 만든다. 되돌리기 가장 비싼 것부터, UI 는 마지막.

```
Packages/LearnKit/Sources/
├─ LearnCore/          의존성 0. 값 타입 + 프로토콜 (Lesson, Block, GradeResult)
├─ LearnPersistence/   GRDB. review_log 는 append-only 진실의 원천
├─ LearnScheduling/    FSRS-6 벤더링 + 참조 벡터 테스트
├─ LanguageKit/        CodeRunner / TestRunner / GrammarDescriptor 계약
├─ RunnerKit/          InProcess · WebView · Subprocess · Emulator 백엔드
│  └─ Launcher/        C 런처 헬퍼 (fork + setsid + setrlimit + killpg)
├─ ContentKit/         팩 포맷·검증·설치. swift-markdown BlockDirective
├─ Languages/          LangPython · LangSQL · LangSwift (얇은 어댑터)
├─ Grammars/           tree-sitter 그래머 SPM 번들
├─ EditorUI/           CodeEditSourceEditor + Neon
└─ Features/           .defaultIsolation(MainActor) — 레슨·복습·통계
Tools/
├─ packtool/           validate / build / sign — 생성 콘텐츠 검증 게이트
└─ lessongen/          Claude API 레슨 생성 CLI (빌드타임)
```

**단계** — ① 선행(Xcode·git·라이선스) → ② 코어 골격 + `review_log` 스키마 + FSRS → ③ 실행기 3종 + `RunnerContractTests` + C 런처 → ④ 팩 스키마 + `packtool validate` + `lessongen` → ⑤ UI → ⑥ 공증·공개.

③을 ④보다 먼저 두는 이유는, **콘텐츠 검증 게이트가 실행기를 필요로 하기 때문**이다. 실행기 없이 생성한 레슨은 검증할 방법이 없다.

## 토의 / 메모
<!-- oculpm:discussion-log begin v1 -->
| 시각 | 작성자 | 내용 |
|---|---|---|
| 2026-09-06T12:45:00+09:00 | claude-code | 병렬 리서치 4갈래(실행 런타임·에디터 UI·앱 아키텍처·커리큘럼) 결과를 종합. 방안 C 권고 |
| 2026-09-06T12:45:00+09:00 | claude-code | 리서치 충돌 해소: Runestone 은 iOS 전용이라 macOS 후보에서 제외(Package.swift 확인). Unicorn Engine 은 GPL-2.0 — 쟁점 1 로 분리 |
| 2026-09-06T12:45:00+09:00 | claude-code | 콘텐츠를 Claude API 생성으로 정하면서 본문 재배포 라이선스 제약 대부분이 무효화됨. 대신 생성물 자동 검증 게이트가 필수 요구사항으로 승격 |
| 2026-09-06T13:55:00+09:00 | claude-code | Opus 5 병렬 계획 세션 4갈래(영속화·실행기·콘텐츠·UI) 결과를 polyglot-core / polyglot-surface 두 플랜으로 승격 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — swift-fsrs 최신 태그 v5.0.0 에는 FSRS-6 이 없다(BasicSchedulerV6 와 21-length defaultWv6 는 main 에만). 커밋 SHA 핀 필수, 벤더링 표면도 200줄이 아니라 약 2,600줄 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — SQLiteData 1.12.0 은 swift-tools-version 6.4 라 설치된 Swift 6.3.3 으로 해석 불가. 도입 보류하고 GRDB 자체 ValueObservation 을 AsyncSequence 로 노출 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — CodeEditLanguages 는 CESE 0.15.2 의 exact 전이 의존이라 제거 불가. 대신 CEL 0.1.20 이 python·sql·swift 그래머를 이미 포함해 MVP 그래머 비용이 0 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — 이 문서의 BlockDirective 예시는 파싱되지 않는다. 중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 조용히 버려지고, 인자 값에 콜론·괄호·따옴표를 못 쓴다 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — Textual 의 MarkupParser 는 문서 전체를 AttributedString 으로 렌더해 퀴즈·빈칸 컨트롤을 담을 수 없다. 산문만 태우는 하이브리드로 변경 (플랫폼 하한 macOS 15 이슈 동반) |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — 로그인 셸의 python3 는 /usr/bin 의 3.9.6 이다. 3.13.12 는 miniconda 경로라 PATH 상 뒤. 툴체인 감지는 전수 열거 후 버전 정책으로 선택해야 한다 |
| 2026-09-06T13:55:00+09:00 | claude-code | 정정 — swiftc 에 JSON 진단이 없다(clang 전용). diagnostic-style llvm 텍스트 파싱 + print-diagnostic-groups 로 ruleID 확보 |
| 2026-09-06T13:55:00+09:00 | claude-code | 결정 — Pyodide 를 MVP 에서 제외하고 Python 은 로컬 python3 서브프로세스로. input() 실습 가능 여부와 무한루프 정지 확실성이 결정적 |
<!-- oculpm:discussion-log end -->

## 다음 단계

- [ ] Xcode 설치 후 `xcode-select -s` 로 활성 개발자 디렉터리 전환 {#next-xcode}
- [ ] `git init` + 앱 라이선스 결정 (쟁점 1 의 GPL 선택지를 남길지 함께 판단) {#next-git-license}
- [ ] 쟁점 3 결정 — 레슨 생성을 빌드타임 CLI 로 밀지, 런타임에 둘지 {#next-decide-gen-time}
- [ ] `Packages/LearnKit` 스캐폴딩 + 타깃별 `defaultIsolation` 설정 {#next-scaffold}
- [ ] `LearnPersistence` 마이그레이션 1번 — `review_log` 부터 {#next-schema}
- [ ] `LanguageKit` 의 `CodeRunner` / `GradeResult` 계약 확정 + `RunnerContractTests` 골격 {#next-runner-contract}
- [ ] C 런처 헬퍼 구현 및 rlimit·killpg 동작 실측 검증 {#next-launcher}
- [ ] MVP 3종 어댑터 — SQL(InProcess) · Python · Swift(Subprocess) {#next-mvp-adapters}
- [ ] 팩 스키마 + `packtool validate` (예제 실행 검증 게이트 포함) {#next-packtool}
- [ ] `lessongen` — Claude API 레슨 생성기 {#next-lessongen}
