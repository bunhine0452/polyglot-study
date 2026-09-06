---
schema_version: 1
type: feature
slug: "first-running-app"
status: done
difficulty: high
created_at: "2026-09-06T21:01:47+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Package.swift"
    op: create
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: create
  - path: "App/Sources/PolyglotApp/Snapshot.swift"
    op: create
  - path: "App/Scripts/build-app.sh"
    op: create
  - path: "App/Resources/Info.plist"
    op: create
  - path: "Packages/LearnKit/Sources/DesignSystem/Tokens.swift"
    op: create
  - path: "Packages/LearnKit/Sources/DesignSystem/Primitives"
    op: create
  - path: "Packages/LearnKit/Sources/DesignSystem/Shell"
    op: create
  - path: "Packages/LearnKit/Sources/Features/OnboardingFeature"
    op: create
  - path: "docs/screenshots/app-onboarding.png"
    op: create
related:
  - ref: "20260906/Refactors/1955_refactor_openrouter-provider-abstraction.md"
    kind: "followup"
tags:
  - "ui"
  - "swiftui"
  - "app"
  - "parallel"
  - "design-system"
  - "mcp-tool"
---
[x] 처음으로 실행되는 앱 — 셸·프리미티브·온보딩 화면

이 저장소에 **처음으로 실행되는 앱**이 생겼다. 창이 뜨고, 툴체인 화면이 목 데이터가 아니라 `ToolchainProbe` 가 이 머신을 실제로 훑은 결과를 그린다. 653 테스트 3회 반복 통과, 양쪽 패키지 빌드 경고 0.

## 추가 기능

- **App 패키지** — `.xcodeproj` 없이 SPM `executableTarget` + `Info.plist` + 번들 조립 스크립트로 `.app` 을 만든다.
- **DesignSystem** — 토큰(색 12·타입 스케일 2종·8px 간격·룰), 프리미티브 6종(`Rule`·`StatusDot`·`SegmentedProgress`·`MonoText`·`FlatButton`·`LabelText`), 232px 사이드바 셸.
- **OnboardingFeature** — 툴체인 진단 10행 표, 4상태 매핑, 설치 명령 클립보드 복사.

## 동작 흐름

셸의 `.toolchain` 목적지가 `OnboardingModel` 을 물고, 그 모델이 `RunnerKit` 의 감지기를 순차로 10번 돌린다. 사이드바 배지도 실제 미해결 수를 낸다.

스크린샷(`docs/screenshots/app-onboarding.png`)이 이 프로젝트의 여러 결정을 한 번에 증명한다 — **Python 이 `/usr/bin` 의 3.9.6 이 아니라 `~/.local/bin` 의 3.14.3(uv)으로 잡힌 것이 화면에 그대로 나온다.** 런처 세션이 "PATH 순서가 아니라 버전 정책으로 선택" 하도록 만든 것이 UI 까지 도달했다는 뜻이다. Java 의 `.stub` 도 실제 실패 메시지와 함께 표시된다.

## `.xcodeproj` 를 만들지 않은 판단

pbxproj 를 손으로 쓰면 Xcode 가 열 때마다 다시 쓴다 — 특히 로컬 SPM 패키지를 `XCLocalSwiftPackageReference` 로 무는 부분. 앱 타깃이 하는 일이 파일 하나 컴파일 + LearnKit 링크뿐이라 그 대가를 치를 이유가 없다.

**잃는 것도 없다.** 공증·폰트·헬퍼 서명은 전부 *번들 구조*에 걸리지 프로젝트 파일에 걸리지 않는다. `codesign -dv` 로 `app bundle with Mach-O thin (arm64)` 을 확인했고 `ATSApplicationFontsPath=Fonts` 를 Info.plist 에 미리 넣어 폰트 번들링 착지점을 만들어 뒀다. Sparkle 프레임워크 임베드 같은 이유로 프로젝트가 정말 필요해지면 그때 만들어 넣으면 된다.

## 검증 수단을 만들어야 했다

`osascript` 는 보조 접근 권한이, `screencapture` 는 화면 녹화 권한이 없어 둘 다 막혔다(실측). 권한이 필요 없는 두 경로로 대체했다 — `CGWindowListCopyWindowInfo` 로 창 존재를 직접 조회하고(`layer=0`, `1440x900`), **앱이 자기 뷰 계층을 스스로 굽는** 디버그 경로(`POLYGLOT_SNAPSHOT_PATH`)로 PNG 를 남긴다. 자기 창 캐시 렌더라 권한 밖이다.

## 내가 만든 토큰이 두 군데 틀렸다

**`monoFallback = "SF Mono"` 가 죽은 문자열이었다.** `NSFont(name:)` 으로 `"SF Mono"` 도 `"SFMono-Regular"` 도 해석되지 않는다. 화면은 `.system(design: .monospaced)` 로 떨어져 **우연히 맞았지만** 토큰이 거짓말을 하고 있었다. `Menlo` 로 바꾸고 **폴백 이름이 실제로 해석되는지 검사하는 테스트**를 붙였다.

스케일도 3종을 빠뜨려 두 세션이 각각 근사로 때웠다 — 산스 12/14/18, 모노 11.5(레지스터 표에서 38회). 추가했다.

## 디자인 실측값을 그대로 쓰면 안 되는 경우

온보딩 표의 두 넓은 열이 480/352 인데 그건 **아트보드 폭 기준**이다. 사이드바 232 와 여백을 더하면 1440 창을 넘겨 표가 잘렸다(첫 스크린샷에서 실측 확인). 고정 폭 → 최소 폭 + 신축으로 바꿨다.

## 봉인 패턴이 전파됐다

프리미티브가 `cornerRadius`·`shadow` 파라미터를 노출하지 않는 것만으로는 *안쪽* 사용을 못 막아서, 소스를 직접 읽어 `cornerRadius`·`.shadow(`·`RoundedRectangle`·`Material`·`NavigationSplitView`·`glassEffect` 가 0건인지 세는 테스트를 붙였다. 색 리터럴도 `Tokens.swift` 밖 0건으로 고정했다. 코어의 `public import GRDB` 0건 grep 과 같은 방식이고, 내가 지시하지 않았는데 세션이 스스로 복제했다.

## 검증

`swift test` 653개 3회 반복 무실패. 앱 실행은 창 조회 + 20초 생존 확인 + 스냅샷 육안 확인. 스냅샷 지연을 `POLYGLOT_SNAPSHOT_DELAY` 로 뺀 이유는 툴체인 스캔이 도구당 2초 상한 × 10개 순차라 기본 2초로는 "확인 중…" 만 찍혔기 때문이다.

## 메모

Swift 6.3 함정 하나를 보고받았다 — **async `@Sendable` 클로저를 `@MainActor` 격리 `public init` 의 기본 인자로 주고 다른 모듈에서 그 파라미터를 생략해 호출하면** `freed pointer was not the last allocation` 으로 프로세스가 죽는다(100% 재현). `nil` 기본값 + 내부 폴백 분기로 우회했다. 같은 DI 패턴을 쓰는 다른 화면이 밟을 수 있다.

에디터 조사 결과 `xcodebuild` 로는 애초에 빌드가 되고 막힌 것은 `swift build` CLI 경로뿐이며, 원인은 CESE 안의 **죽은 `import CodeEditSymbols` 한 줄**이다. 그것을 제거하는 업스트림 PR #355 가 이미 있고 cherry-pick 후 전체 빌드 성공을 실측했다. `CodeEditLanguages`·`CodeEditSymbols` 에 LICENSE 가 없는 것은 정책이 아니라 누락으로 판단한다 — 조직의 주요 저장소 셋(CodeEdit·CodeEditSourceEditor·CodeEditTextView)이 전부 MIT 이고 태그라인이 "Open source, free forever" 다. 우리가 LICENSE 추가 PR 을 올리는 것으로 대응한다.