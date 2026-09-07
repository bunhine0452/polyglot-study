# Polyglot Study

Python · Rust · C++ · Go · Java · Next.js · TypeScript · SQL · Swift · Assembly, 10개 언어를
**각각 독립 트랙**으로 학습하는 macOS 네이티브 앱. 문서를 읽는 게 아니라 레슨 안에서 코드를
쓰고, 로컬 툴체인으로 실제로 실행하고, 채점을 받는다. MVP 범위는 **Python · SQL · Swift**
셋이다 — 이 셋이 서로 다른 실행 백엔드(서브프로세스 / 인프로세스 SQLite / 서브프로세스)에
걸쳐 있어 실행 추상화가 세 갈래 모두에서 검증된다.

macOS 14+ · Swift 6.3 / SwiftUI · MIT.

## 지금 어디까지 왔는가

**정직하게 말하면: 앱은 돌고 파이프라인은 닫혔지만, 커리큘럼이 아직 한 트랙뿐이다.**

| 영역 | 상태 |
|---|---|
| 코어 (스케줄러 · 실행 · 영속화) | **완료.** FSRS-6 복습 스케줄러, 6종 언어 백엔드를 아우르는 `CodeRunner` 프로토콜, GRDB 기반 저장소, sandbox-exec 격리 서브프로세스 러너·C 런처. SQL 은 인프로세스 SQLite 를 실행마다 클론해 돌리고 쓰기는 열되 파일 크기를 64MB 로 묶는다. `Packages/LearnKit` 테스트 1058개가 이를 검증한다. |
| 화면 | **7개 중 6개.** 온보딩(툴체인 진단) · 대시보드 · 레슨 · 복습 · 에디터+콘솔 · SQL 결과 diff 가 실제로 뜬다. ARM64 레지스터 패널만 Assembly 트랙 착수까지 후순위다(`docs/milestones/`). |
| 에디터 | **sourcekit-lsp 연동됨.** Swift 트랙에 완성과 진단이 붙는다 — 완성은 워밍 후 중앙값 28ms, 진단은 swiftc 와 **같은 인라인 컴포넌트**로 렌더하고 출처만 라벨로 구분한다. |
| 레슨 콘텐츠 | **MVP 세 트랙 완성 — 파이썬 12편 · SQL 12편 · Swift 12편** (+ 샘플 팩 3편). 36편 전부가 `packtool validate` 의 네 단계를 통과한다 — 예제는 실제로 실행돼 expected 와 바이트 대조되고, 과제는 solution 통과와 starter 실패를 둘 다 확인받는다. 나머지 7개 트랙은 화면상 "준비 중" 으로 뜬다. |
| 콘텐츠 파이프라인 (`packtool`) | **완료.** `validate` 가 구조·문법·의미·실행 네 단계를 돌리고 예제는 expected 와 바이트 대조, 과제는 solution 통과와 **starter 실패**를 둘 다 확인한다. `build` 는 solutions 를 벗겨 결정적 tar 로 굽고(두 번 구우면 바이트 동일), `sign`/`verify` 가 Ed25519 분리 서명과 해시를 함께 본다. |
| 레슨 생성기 (`lessongen`) | **완료.** `outline` · `lesson` · `repair` 가 모두 돈다. 파이썬 12편이 이 루프로 만들어졌고, 실행 게이트가 2편에서 결함을 잡아 `repair` 가 고쳤다 — 재검증 실패 0건. |
| CI | **PR 필수 체크 3게이트.** `swift test`(양쪽 패키지) · 앱 번들 조립 · `packtool validate` 가 PR 마다 돈다. `lessongen` 은 크레딧이 나가므로 `workflow_dispatch` 전용이다. |
| 서명·배포 | **Sparkle 자동 업데이트 왕복 검증됨.** 구버전이 appcast 를 읽어 신버전을 받고 EdDSA 검증 후 설치까지 가는 것과, 서명이 어긋난 업데이트가 거부되는 것을 자동 테스트로 확인한다(`App/Scripts/verify-sparkle.sh`). 공증·DMG 는 **Developer ID 인증서가 없어** 아직 못 한다 — 지금 산출물은 ad-hoc 서명이다. |

진행 상황의 항목별 근거는 `.oculpm/planner/polyglot-surface.md` 에 있고, 각 판단의 경위와
실측은 `.oculpm/journal/` 에 남아 있다.

## 스크린샷

실제로 빌드해 띄운 창을 찍은 것이다(합성 아님) — `App/Sources/PolyglotApp/Snapshot.swift`
가 `POLYGLOT_SNAPSHOT_PATH` 환경변수로 자기 창을 PNG 로 굽는다.

| 오늘(대시보드) | 툴체인 진단 | 복습 |
|---|---|---|
| ![대시보드](docs/screenshots/app-today.png) | ![툴체인](docs/screenshots/app-toolchain.png) | ![복습](docs/screenshots/app-review.png) |

## 빌드 · 실행

Xcode 프로젝트가 없다 — 이유는 `App/Package.swift` 상단 주석에 적어 뒀다(요약: 앱 타깃이
파일 하나뿐이라 pbxproj 를 들고 다닐 이유가 없고, 서명·번들 레이아웃은 SPM 산출물로도 완전히
재현된다).

```bash
# 코어 라이브러리 테스트 — 870개, 경고 0
swift test --package-path Packages/LearnKit

# packtool·lessongen CLI 테스트 — 139개
swift test --package-path Tools

# 앱 번들을 만들고 실행 (서명까지 자동으로 됨 — 아래 참고)
App/Scripts/build-app.sh --run

# release 구성으로 빌드만
App/Scripts/build-app.sh --release
```

레슨 생성기(`lessongen`)를 쓰려면 OpenRouter API 키가 필요하다:

```bash
cp .env.example .env
# .env 에 OPENROUTER_API_KEY, OPENROUTER_MODEL 채우기
swift run --package-path Tools lessongen outline --language python --lessons 3
```

`.env` 는 `.gitignore` 로 막혀 있다 — 커밋되는 건 `.env.example` 뿐이다.

## 구조

```
App/                SwiftUI 앱 타깃. 화면은 전부 LearnKit 안에 있고 여기는 조립·번들링·서명만.
Packages/LearnKit/  코어 라이브러리 12개 타깃(LearnCore·RunnerKit·ContentKit·DesignSystem…).
Tools/               packtool·lessongen CLI. ArgumentParser 를 링크하는 산출물은 이쪽뿐 —
                     앱 바이너리는 링크하지 않는다.
Content/packs/       콘텐츠 팩. 포맷 스펙은 docs/pack-format.md.
Vendor/              벤더링한 서드파티 소스(라이선스는 아래 참고).
design/              스위스 그리드 아트보드 — 화면 디자인의 근거.
docs/                포맷 스펙, 스크린샷.
.oculpm/             작업 계획·일지(ocul-pm). 사람 기여자가 직접 건드릴 필요는 없다 — 이
                     저장소가 AI 에이전트 세션으로 개발된 이력을 투명하게 남겨 둔 것이다.
```

## 서명·배포

`App/Scripts/build-app.sh` 가 매 빌드마다 서명까지 한다 — Hardened Runtime 을 켜고
(`codesign --options runtime`) App Sandbox 는 켜지 않는다(`App/Codesign/Polyglot.entitlements`
에 `com.apple.security.app-sandbox` 키 자체가 없다 — 로컬 툴체인을 서브프로세스로 실행해야
해서 샌드박스와는 애초에 안 맞는다. Mac App Store 배포는 이 때문에 포기했다).

번들에 들어가는 C 런처 헬퍼(`learn-launcher`, 서브프로세스에 rlimit 을 거는 실행 파일)는
`Contents/Helpers/` 에 앱과 **같은 신원으로 개별 서명**된다 — `--deep` 옵션 없이, 헬퍼를 먼저
서명하고 컨테이너를 나중에 서명하는 순서로. `codesign --verify --deep --strict` 가 헬퍼를
포함해 통과한다.

스크립트는 서명 신원을 `security find-identity -v -p codesigning` 으로 찾는다. **이
저장소를 만드는 데 쓰인 머신에는 Developer ID 인증서가 없다** — 그 결과 앱과 헬퍼 둘 다
**ad-hoc(`-`) 서명**으로 떨어진다. 인증서가 있는 머신에서 같은 스크립트를 돌리면 그 신원으로
서명된다. 공증(`notarytool`)·스테이플·DMG 서명·Sparkle 자동 업데이트는 Apple Developer
계정이 있어야 의미가 있어서 `App/Codesign/notarize.sh` 에 순서만 문서화해 두고 실행하지
않는다.

## 폰트

본문은 IBM Plex Sans KR, 코드·수치는 IBM Plex Mono 를 쓴다. `App/Resources/Fonts/` 에
정적 웨이트 3종(Regular·Medium·SemiBold) 씩 바이너리로 커밋돼 있다 — 두 폰트 합쳐 약 7.6MB.
전체 웨이트(8종 × hinted/unhinted)를 다 담으면 IBM Plex Sans KR 하나만 70MB 를 넘어가서,
실제 코드에서 쓰는 세 웨이트로 줄였다. 라이선스는 [폰트](#라이선스) 항목 참고.

앱은 `CTFontManagerRegisterFontsForURL` 로 프로세스 스코프 런타임 등록을 하고
(`App/Sources/PolyglotApp/FontRegistration.swift`), 배포용 번들에서는 `Info.plist` 의
`ATSApplicationFontsPath` 도 같은 파일을 가리켜 이중으로 동작한다 — 이유는 그 파일 안
주석에 있다(요약: `ATSApplicationFontsPath` 는 `.app` 으로 등록·실행됐을 때만 먹어서, `swift
run` 같은 비-번들 실행 경로는 런타임 등록이 없으면 폴백 폰트로 떨어진다).

## 라이선스

이 저장소 자체는 [MIT](LICENSE) 다.

**⚠ Unicorn Engine(GPL-2.0)을 실행 백엔드로 도입하면 이 MIT 선택은 무효화된다.** 아직
도입하지 않았고 지금 트리에 그 의존은 0건이지만, Assembly 트랙 에뮬레이션 백엔드 후보로
논의된 적이 있어(`.oculpm/discussion/mac-polyglot-learning-app/discussion.md`) 여기 경고를
남겨 둔다 — 붙이는 순간 배포 전체를 GPL-2.0 조건 아래로 옮기게 된다.

서드파티 고지는 [NOTICE](NOTICE) 에 모아 뒀다. 요약:

- **IBM Plex Sans KR / IBM Plex Mono** — SIL Open Font License 1.1 (Reserved Font Name
  "Plex"). `App/Resources/Fonts/LICENSE.txt` 에 전문이 있다.
- **CodeEditSourceEditor** — MIT. `Vendor/CodeEditSourceEditor` 에 로컬 벤더링(업스트림
  0.15.2 + 병합 대기 중인 PR #355 를 재현). 전문은 `Vendor/CodeEditSourceEditor/LICENSE`.
- **swift-fsrs** — MIT. `Packages/LearnKit/Sources/LearnScheduling/Vendor/FSRS` 에 커밋
  SHA 고정으로 벤더링(FSRS-6 이 릴리스 태그에는 없어서). 벤더링 경위는 같은 디렉터리의
  `VENDORING.md`.
- **CodeEditLanguages · CodeEditSymbols**(CodeEditSourceEditor 의 전이 의존) — 저장소에
  `LICENSE` 파일이 없다. CodeEdit 조직의 주요 저장소(CodeEdit·CodeEditSourceEditor·
  CodeEditTextView)는 전부 MIT 이고 README 태그라인이 "Open source, free forever" 라 정책이
  아니라 누락으로 판단하고 그대로 쓰고 있다 — 조직 쪽에 명시적 라이선스 확인을 구하는 것이
  안전한 다음 단계다.

기여 방법은 [CONTRIBUTING.md](CONTRIBUTING.md) 참고.
