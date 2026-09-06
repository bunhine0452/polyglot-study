---
oculpm_plan: v1
id: polyglot-surface
title: "Polyglot Study 표면 — 콘텐츠·UI·배포"
status: active
created: 2026-09-06
updated: 2026-09-06
owner: claude-code
---

코어(polyglot-core) 위에 올라가는 계층. 콘텐츠 검증 게이트는 CodeRunner 백엔드를 전제하므로 코어 Phase 4 이후에 착수한다. UI 는 design/ 의 스위스 그리드 아트보드 7종을 구현 대상으로 삼는다.

## 콘텐츠 팩 포맷과 ContentKit {#content-pack-format}
- [ ] 팩 디렉터리 레이아웃과 manifest 스키마 v1 확정 — lessons·starters·tests·solutions·expected·assets 6종 — 완료: 스펙 문서와 그대로 만든 샘플 팩 1개가 리포에 존재 {#pack-format-spec}
  - [x] stableID 불변 규칙을 lock 파일로 물리화 — 삭제와 개명은 에러, 추가만 허용, 위반 3종의 기대 에러 메시지를 문서화 {#stableid-lock}
  - [x] 매니페스트 정규 바이트 규칙 — 키 정렬·개행·타임스탬프 출처를 git commit date 로 고정해 두 번 구운 결과가 바이트 동일 {#manifest-canonical-bytes}
- [ ] Example·Blank·Task·Quiz·Reflection 디렉티브 인자 스펙 확정 — 인자는 식별자·열거 토큰·경로만, 자유 텍스트는 전부 본문 하위 디렉티브나 사이드카 파일로 {#directive-syntax-spec}
  - [x] 인자 값에 콜론·중괄호·괄호·쉼표·큰따옴표를 못 쓰고 역슬래시가 값에 그대로 남는 동작을 스펙에 명시 — 정답은 Answer 본문으로, 기대 stdout 은 expected 사이드카로 {#directive-arg-charset}
  - [x] 중괄호 본문을 여러 줄로 강제 — 한 줄 본문은 마지막 중괄호까지 삼키고, 중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 조용히 버려짐 {#directive-multiline-body}
- [x] ContentKit 타깃 추가 + swift-markdown 0.8.0 태그 핀 — 완료: LearnCore 에만 의존하는 타깃에서 Markdown 임포트 성공 {#contentkit-target}
- [ ] PackManifest Codable 모델과 validate 작성 — 완료: 깨진 매니페스트 6종(중복 id·미등록 파일·잘못된 semver·경로 탈출·빈 lessons·미지 언어)이 각각 다른 에러로 실패 {#packmanifest-codable}
  - [x] schemaVersion 과 minAppVersion 게이트 — 앱보다 새 팩은 사용자에게 보여줄 문구와 함께 거부하고 크래시하지 않음 {#schema-version-gate}
- [x] LessonBlock 값 타입 6종을 Sendable 로 정의하고 Markup 트리를 파싱 경계 밖으로 내보내지 않음 — Markup 프로토콜은 Sendable 이 아니라 nonisolated 코어에서 못 씀 {#lessonblock-model}
- [ ] MarkupWalker 로 BlockDirective 를 순회해 레슨을 블록 배열로 변환 — 완료: 레퍼런스 레슨이 6블록 순서로 파싱되고 미지 디렉티브·순서 위반·블록 누락이 전부 throw {#lesson-parser}
  - [x] 디렉티브 인자를 이름으로 조회하는 래퍼를 직접 작성 — 라이브러리에 없고 업스트림 테스트 파일의 fileprivate 헬퍼만 존재 {#directive-args-wrapper}
- [ ] 팩 로더와 원자적 설치·롤백 — 버전 디렉터리와 current 포인터 — 완료: staging 에 풀고 전 파일 sha256 검증 후 교체, 설치 도중 강제 종료해도 current 가 이전 버전을 가리킴 {#pack-installer}
  - [x] 설치 전 상위 경로 탈출·절대경로·심볼릭 링크 거부 — 악성 경로 4종 픽스처가 전부 거부되고 디스크 잔여물 0 {#pack-path-hardening}
- [x] Textual 하이브리드 렌더러 — 산문만 태우고 퀴즈·빈칸·실행 버튼은 네이티브 SwiftUI 형제 뷰로. MarkupParser 가 문서 전체를 AttributedString 으로 렌더하므로 컨트롤을 안에 못 넣음 {#lesson-renderer}
  - [x] Textual 이 macOS 15 를 요구하고 LearnKit 은 macOS 14 — UI 타깃만 올릴지 패키지 전체를 올릴지 결정하고 이유를 Package.swift 주석에 {#platform-bump}

## packtool · lessongen · CI 게이트 {#content-toolchain}
- [x] Tools 를 별도 SPM 패키지로 만들고 LearnKit 을 path 의존으로 — 완료: packtool 과 lessongen 두 실행 파일이 나오고 앱 산출물은 ArgumentParser 를 링크하지 않음 {#tools-package}
- [x] packtool validate 의 구조·문법 단계 — 매니페스트 디코딩·sha256 대조·디렉티브 파싱·참조 파일 존재 — 완료: 툴체인 없는 머신에서도 돌고 망가진 픽스처 8종이 서로 다른 메시지로 실패 {#packtool-structural}
- [x] packtool validate 의 실행 게이트 — MVP 3트랙 샘플 팩의 모든 예제·과제 블록이 실제 CodeRunner 를 타고 통과, 하나라도 어긋나면 non-zero. 통과 못 한 팩은 머지 금지 {#packtool-execution}
  - [x] 예제 블록을 실행해 expected 사이드카와 바이트 단위 대조, 불일치 시 줄 단위 diff 출력, CRLF·후행 개행 정규화 규칙을 스펙에 명시 {#example-stdout-compare}
  - [x] 과제 블록은 solution 이 숨은 테스트를 통과하고 starter 는 실패하는지 둘 다 확인 — starter 가 이미 통과하는 무의미한 과제가 AI 생성물의 가장 흔한 실패 {#task-solution-and-starter}
- [x] 퀴즈·빈칸 의미 검증 — 정답 키가 실제 선택지에 존재하는지, 선택지가 2개 이상인지, 정답 본문이 비어 있지 않은지를 행·열 위치와 함께 보고 {#packtool-semantic}
- [x] packtool 리포트를 JSON 과 JUnit XML 두 형식으로 — CI 어노테이션과 lessongen 재생성 루프가 같은 파일을 읽음, 레슨별 stableID·실패 단계·러너 원문 포함 {#packtool-report}
- [x] packtool build — solutions 를 벗기고 sha256 재계산해 배포용 팩을 결정적으로 굽기 — 완료: 두 번 빌드한 tar 바이트가 동일하고 배포 팩에 solutions 없음 {#packtool-build}
  - [x] packtool sign 과 verify — 정규 매니페스트 바이트에 대한 분리 서명, 키는 환경변수로만 받고 서명 없는 팩과 변조된 팩은 거부 {#packtool-sign}
- [x] lessongen 의 LLM HTTP 클라이언트를 URLSession 으로 작성 — 공급자는 LLMProvider 프로토콜 뒤, 구현은 OpenRouter chat/completions — 완료: 실왕복 1회 성공하고 429·5xx 에 지수 백오프 {#lessongen-http-client}
  - [x] API 키는 OPENROUTER_API_KEY 환경변수(없으면 .env)에서만 읽고 플래그·설정파일·로그 어디에도 싣지 않음 — 실행 로그 전수 grep 에 키 0건 {#api-key-handling}
- [x] lessongen outline — 트랙 개요를 구조화 출력 1회로 뽑아 stableID·학습목표·선수개념을 갖춘 JSON 으로 커밋, 사람이 리뷰한 뒤에만 진행 {#lessongen-outline}
- [!] lessongen lesson — 레슨을 JSON 으로 받아 Swift 코드가 디렉티브 마크다운으로 직렬화. 모델에게 마크다운을 시키지 않음 — 완료: 생성물이 구조·문법 단계를 첫 시도에 통과 {#lessongen-lesson}
  - [x] 트랙 전체 팬아웃은 동시성 제한 병렬 요청으로 — OpenRouter Batch(/api/beta/batches, 통상 50%)는 있으나 현 모델의 :batch 변종이 프로모션가의 2배이고 seed 미지원이라 이득이 없음 {#lessongen-batch-fanout}
  - [!] 고정 시스템 프롬프트를 안정 접두사로 두고 session_id 로 업스트림을 고정 — 현 모델은 자동 캐싱(쓰기 무료·읽기 0.2배)이라 cache_control 이 불필요하고 캐시가 업스트림에 붙어 있어 라우팅 고정이 진짜 조건. 완료: 2회차부터 cached_tokens 가 0 이 아님 {#lessongen-prompt-caching}
- [x] lessongen repair — packtool 리포트를 읽어 실패 레슨만 재생성하고 러너 원문을 프롬프트에 담아 재요청 — 완료: 컴파일 에러·stdout 불일치·테스트 실패 3종이 통과로 수렴 {#lessongen-repair}
  - [x] 3회 실패 시 격리 — 해당 레슨을 팩에서 빼고 명단과 함께 non-zero 종료, 절대 머지시키지 않음 {#lessongen-quarantine}
- [x] 실행 로그와 비용 가드 — 실행별 디렉터리에 요청·응답·usage·cost·검증 리포트를 남기고 최대 지출 초과 시 중단. 임의 모델은 temperature·seed 를 받으므로 재현을 목표로 삼되, 진짜 변수는 시드가 아니라 어느 업스트림이 답했는가라서 모델 id·seed·temperature·upstream provider·generation id 를 함께 기록 {#lessongen-runlog}
- [~] GitHub Actions — macOS 러너에서 packtool validate 를 packs 변경 PR 의 필수 체크로 걸고 lessongen 은 workflow_dispatch 에서만 실행 {#ci-gate}
  - [~] 툴체인 부재 시 스킵이 아니라 실패가 기본 — 명시 플래그를 줄 때만 스킵하고 리포트에 기록, 경량 러너는 구조·문법만 돌고 게이트로 세지 않음 {#toolchain-skip-policy}

## UI 기반 — 타깃·토큰·에디터 {#ui-foundation}
- [ ] Polyglot.xcodeproj 를 앱 타깃 하나만 담는 얇은 셸로 만들고 코드는 전부 로컬 SPM 참조로 — 완료: 앱 타깃 컴파일 소스가 2개 이하이고 xcodebuild build 통과 {#xcode-app-target}
  - [x] Package.swift 에 uiSettings 추가 — MainActor 기본 격리 + 기존 upcoming feature 2종, 코어 타깃은 coreSettings 유지하고 경고 0으로 빌드 {#ui-isolation-settings}
- [ ] DesignSystem 타깃에 색 12종·타입 스케일 2종·룰 2종·8px 그리드를 Swift 상수로 — 완료: 디자인 파일의 모든 색 리터럴이 토큰에 대응되고 뷰 코드에 hex 하드코딩 0건 {#designsystem-tokens}
  - [x] 색 토큰 실측값 그대로 — paper F4F4F2 · ink 141414 · secondary 5F5F5C · faint 9A9A97 · ruleSoft D9D9D6 · cellEmpty C9C9C6 · pass 2F8F4E · fail C8372D · failWash F7E4E2 {#color-tokens}
  - [x] 산스 11/13/15/20/24/28/32 와 모노 11/12/12.5 를 분리한 Typography 열거형 + 전역 monospacedDigit 로 숫자 폭 고정 {#type-scale}
- [x] IBM Plex Sans KR 과 Mono 를 SPM 리소스로 번들하고 CTFontManagerRegisterFontsForURL 로 런타임 등록 — 완료: 네트워크를 끊어도 폴백이 아닌 Plex 로 렌더 {#plex-font-bundling}
  - [x] ATSApplicationFontsPath 는 앱 번들 Resources 에만 먹으므로 Bundle.module 경로에는 쓰지 않고 process 스코프 등록으로 처리 {#font-registration-path}
- [x] 라운딩과 그림자를 타입 차원에서 봉인한 프리미티브 6종 — Rule·StatusDot·SegmentedProgress·MonoText·FlatButton·LabelText, cornerRadius 와 shadow 파라미터를 아예 노출하지 않음 {#ds-primitives}
- [x] 232px 고정 사이드바와 4개 내비를 NavigationSplitView 없이 HStack 과 1px 룰로 구성 — 완료: 시스템 기본 라운딩·머티리얼 배경이 전혀 나타나지 않고 활성 항목이 잉크 반전 {#app-shell-chrome}
- [x] EditorUI 타깃 신설 + CodeEditSourceEditor 를 exact 0.15.2 로 핀하고 Package.resolved 커밋 — 완료: CESE 0.15.2 · CodeEditTextView 0.12.1 · CodeEditLanguages 0.1.20 고정 {#editorui-target-pin}
  - [x] CodeEditLanguages 0.1.20 이 exact 전이 의존이라 제거 불가임을 모듈 주석에 명시 — MVP 3종은 CEL 내장 그래머(python·sql·swift)를 그대로 사용 {#cel-transitive-note}
- [x] EditorTheme 16개 속성을 전부 무채색으로 채운 모노크롬 테마 — 완료: 에디터 안에 유채색 0건이고 키워드·타입·문자열·주석이 굵기와 회색 3단으로만 구분 {#mono-syntax-theme}
  - [x] EditorTheme.Attribute 가 bold 와 italic 만 지원해 디자인의 500 medium 을 표현 못 함 — types 를 ink 레귤러로 근사하고 근사 사실을 주석에 남김 {#theme-weight-limitation}
  - [x] SourceEditorConfiguration 조이기 — 미니맵과 폴딩 리본 끄고 괄호 강조 제거, 12.5pt 폰트에서 행높이가 20px 이 되도록 배수 설정 {#editor-config-tuning}
- [ ] Grammars 타깃을 탈출구로만 세우고 alex-pinkus/tree-sitter-swift 는 0.7.3-with-generated-files 태그를 물기 — main 브랜치에는 src/parser.c 가 없어 빌드가 깨짐 {#grammars-escape-hatch}
  - [ ] MVP 단계에서는 앱에 링크하지 않고 Assembly 트랙 착수 시점에 활성화 — 바이너리 크기 증가 0이고 활성화 조건을 한 줄로 문서화 {#grammars-deferred-link}
- [x] GradeResult.Presenter 4케이스를 SwiftUI 뷰로 분기하는 라우터 — console 과 table 은 실제 뷰로, browser 와 registers 는 준비중 뷰로, switch 는 exhaustive {#presenter-router}
  - [x] 실행 전에도 결과 영역이 같은 크기를 차지하도록 고정 높이 예약 — 레슨 출력 80px, 에디터 우측 패널 520px, 실행 시 상단 y 좌표 불변 {#fixed-height-reservation}

## 화면 7개 구현 {#screens}
- [ ] 온보딩 — 툴체인 진단 10행 표와 3상태 표시 — 완료: ready·missing·stub 이 녹색 채움·1px 빈 사각·적색 채움으로 나오고 상단 집계가 실제 probe 결과와 일치 {#screen-onboarding}
  - [x] unsupported 는 디자인에 없는 4번째 상태 — 미설치 빈 사각에 사유 문구를 붙여 접고, switch 에 default 가 필요 없게 {#unsupported-state-mapping}
  - [x] 설치 명령 복사 버튼 — installHint 문자열을 클립보드에 넣기만 하고 프로세스 실행은 일어나지 않음 {#install-hint-copy}
- [x] 대시보드 — 오늘 헤더와 2단 카드(이어서·오늘의 복습)와 10행 트랙 표 — 완료: 활성 3트랙은 잉크, 준비 중 7트랙은 흐림, 트랙별 진도칸 수가 레슨 총수와 정확히 일치 {#screen-dashboard}
  - [x] 진도 셀 3상태 — 완료는 잉크 채움, 현재는 종이에 잉크 1px, 미래는 종이에 흐린 1px. LazyHGrid 가 아닌 고정 Grid 로 2px 간격 유지 {#progress-cell-states}
- [x] 레슨 — 6블록 스텝바와 완료 블록 40px 접힘 행과 활성 블록 카드 — 완료: 한 화면에 펼쳐진 블록이 항상 1개이고 미도래 블록은 흐려진 40px 행으로 남음 {#screen-lesson}
  - [x] 실행 예제 블록의 출력 영역을 실행 전 빈 상태로 80px 예약하고 RunEvent 스트림을 그 자리에 흘림 — 시작·도착·완료 3시점 모두 카드 높이 불변 {#lesson-output-slot}
- [x] 에디터와 콘솔 — 48px 헤더, 56px 과제 바, 좌우 2단 레이아웃 — 완료: 우측 패널이 출력·테스트 탭과 상태 행과 stderr 원문과 테스트 결과를 담고 폭 520px 고정 {#screen-editor-console}
  - [x] 인라인 진단 행 — 거터 6px 사각과 코드 아래 한국어 설명과 위치·도구·개수 라벨을 Diagnostic 에서 조립, 진단이 붙은 행만 배경 전환 {#inline-diagnostic-row}
  - [x] 빨강 사용을 종료 코드 옆 8px 사각 하나로 제한하는 규칙을 뷰 레벨에서 강제 — 이 화면에서 실패색을 쓰는 지점이 코드상 1곳뿐 {#red-budget-guard}
- [ ] sourcekit-lsp 연동 — Swift 트랙에만 완성과 진단 두 기능. Xcode 26.6 동봉이라 서버 조달·설치 안내 비용이 0 — 완료: initialize 응답 수신 {#sourcekit-lsp-swift}
  - [ ] completion 요청을 CESE 의 트리거 문자와 delegate 에 연결 — 점 입력 후 200ms 안에 후보가 뜨고 취소 시 요청이 실제로 취소됨 {#lsp-completion}
  - [ ] publishDiagnostics 를 LearnCore.Diagnostic 으로 매핑해 인라인 진단 행에 재사용 — swiftc 진단과 같은 컴포넌트로 렌더하고 출처만 라벨로 구분 {#lsp-diagnostics}
- [x] SQL 결과표 diff — 내 결과와 예상 결과 2단 표 — 완료: 누락 행이 실패 틴트 배경에 6px 적색 사각으로 표시되고 하단에 결과셋 비교 캡션이 고정 {#screen-sql-result}
  - [x] 행 수가 다를 때 짧은 쪽에 누락 플레이스홀더 행을 채워 두 표의 높이를 맞춤 — 하단 캡션 y 좌표가 항상 고정 {#sql-row-padding}
- [x] FSRS 복습 — 12칸 진행 헤더와 질문·답 카드와 동일 크기 4버튼 — 완료: 4버튼의 폭·높이·배경·테두리가 완전 동일하고 각 아래 다음 간격이 실제 FSRS-6 계산값 {#screen-review}
  - [x] 어떤 답을 골라도 카드가 사라지지 않는다는 문구를 상수로 두고 좋음 을 시각적으로 유도하지 않는 규칙을 주석으로 고정 {#review-no-nudge}
- [x] ARM64 레지스터 패널을 Assembly 트랙 착수 시점까지 후순위로 분리 — registers 프리젠터는 준비중 뷰로 처리하고 디자인은 별도 마일스톤 문서로만 남김 {#screen-registers-deferred}

## 서명·공증·배포 {#distribution}
- [x] Hardened Runtime 을 켜고 App Sandbox 를 끈 서명 설정 확정 — 완료: entitlements 출력에 app-sandbox 가 없고 codesign 에 runtime 플래그가 찍힐 {#codesign-hardened-runtime}
  - [x] 번들된 C 런처 헬퍼를 앱과 같은 Team ID 로 runtime 옵션과 함께 개별 서명 — deep 옵션은 쓰지 않고 verify strict 가 헬퍼 포함 통과 {#helper-signing}
- [ ] notarytool submit 부터 stapler staple 을 거쳐 DMG 까지 스크립트 하나로 — 완료: 네트워크 격리된 다른 맥에서 Gatekeeper 경고 없이 실행되고 spctl 이 accepted {#notarize-staple-dmg}
  - [ ] 자격증명을 notarytool 키체인 프로파일로 저장하고 앱 암호를 스크립트·로그·인자 어디에도 싣지 않음 — 스크립트 전문 grep 에 0건 {#notary-credentials}
  - [ ] 앱뿐 아니라 DMG 자체도 서명·공증·스테이플 — DMG 파일 단독으로 stapler validate 통과 {#dmg-notarize}
- [ ] Sparkle 2.9.6 자동 업데이트를 EdDSA 서명으로 연결 — 완료: 구버전 앱이 appcast 를 읽어 신버전을 받고 서명 검증 후 설치까지 완료 {#sparkle-updates}
  - [ ] 생성한 공개키를 SUPublicEDKey 에 넣고 개인키는 로그인 키체인에만 보관 — 저장소 전체 grep 에 개인키 0건 {#sparkle-eddsa-keys}
  - [ ] 피드 URL 을 GitHub Pages 의 appcast.xml 로 두고 appcast 생성기를 릴리스 스크립트에 편입 — 릴리스 1회로 서명과 길이가 갱신 {#sparkle-appcast}
- [x] GitHub 공개 준비 — README 와 CONTRIBUTING 작성. LICENSE 는 이미 MIT 로 커밋됨. README 라이선스 절에 Unicorn Engine 도입 시 MIT 선택이 무효화된다는 경고 한 줄 {#github-public-repo}
- [ ] 릴리스 CI — swift test 와 xcodebuild build 와 packtool validate 3게이트를 PR 에 걸고, 공증과 appcast 잡은 태그 푸시에만 Actions secrets 로 실행 {#release-ci}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-06T18:27:23+09:00 | #tools-package | claude-code | ☐→x | .oculpm/journal/20260906/Features_to_add/1826_feature_tools-package-and-lessongen-client.md | 별도 SPM 패키지. nm 확인 packtool 0 / lessongen 15856. ArgumentParser 1.8.2 핀 |
| 2026-09-06T18:27:31+09:00 | #api-key-handling | claude-code | ☐→x | .oculpm/journal/20260906/Features_to_add/1826_feature_tools-package-and-lessongen-client.md | 환경변수 전용·RedactingLog 봉인. 주의: 부모 #lessongen-http-client 의 실왕복 1회는 키 부재로 미검증 |
| 2026-09-06T18:27:38+09:00 | #lessongen-outline | claude-code | ☐→~ | .oculpm/journal/20260906/Features_to_add/1826_feature_tools-package-and-lessongen-client.md | 스키마·프롬프트·조립·검증·파일쓰기 완성. 키가 없어 실제 개요 JSON 은 아직 미생성 |
| 2026-09-06T18:47:00+09:00 | #contentkit-target | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #stableid-lock | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #manifest-canonical-bytes | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #directive-arg-charset | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | @X(id: a:b) 가 에러 없이 :b 를 버리는 것 실측 — 정규형 되짚기로 방어 |
| 2026-09-06T18:47:00+09:00 | #directive-multiline-body | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 한 줄 본문이 마지막 중괄호까지 삼킴 — 렉시컬 사전 검사로 거부 |
| 2026-09-06T18:47:00+09:00 | #schema-version-gate | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #lessonblock-model | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #directive-args-wrapper | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 콘텐츠 파이프라인 기반, 607 테스트 통과 |
| 2026-09-06T18:47:00+09:00 | #pack-path-hardening | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | FileManager.enumerator 가 베이스 심볼릭 링크를 풀어 조용히 0개 반환 — 자체 워커로 교체 |
| 2026-09-06T18:47:00+09:00 | #lessongen-http-client | claude-code | 주의 | journal/20260906/Features_to_add/1847_feature_content-pipeline-foundation.md | 실왕복 미검증 — 루프백 서버로만 확인. 키 보유자가 한 번 태워야 닫힘 |
| 2026-09-06T19:49:00+09:00 | #api-key-handling | claude-code | x→x | .oculpm/journal/20260906/Refactors/1946_refactor_llm-provider-abstraction-openrouter.md | OPENROUTER_API_KEY + .env(환경변수 우선). 부모 #lessongen-http-client 는 실왕복 1회 성공으로 닫힘 — 로그·워크트리 키 grep 0건 |
| 2026-09-06T19:49:09+09:00 | #lessongen-batch-fanout | claude-code | ☐→☐ | .oculpm/journal/20260906/Refactors/1946_refactor_llm-provider-abstraction-openrouter.md | 재판단: 50% 할인 전제 무너짐. 현 모델 :batch 가 프로모션가 2배·seed 미지원 → 동시성 제한 병렬로 전환 |
| 2026-09-06T19:49:20+09:00 | #lessongen-prompt-caching | claude-code | ☐→☐ | .oculpm/journal/20260906/Refactors/1946_refactor_llm-provider-abstraction-openrouter.md | 재판단: 현 모델은 자동 캐싱이라 cache_control 불필요. 진짜 조건은 session_id 로 업스트림 고정 (배선 완료, CLI 미연결) |
| 2026-09-06T19:49:31+09:00 | #lessongen-runlog | claude-code | ☐→☐ | .oculpm/journal/20260906/Refactors/1946_refactor_llm-provider-abstraction-openrouter.md | 재판단: temperature·seed 가 생겨 재현이 목표로 복귀. 단 진짜 변수는 upstream provider — model·seed·temperature·upstream·generation id 를 함께 기록 |
| 2026-09-06T19:55:37+09:00 | #lessongen-outline | claude-code | ~→x | journal/20260906/Refactors/1955_refactor_openrouter-provider-abstraction.md | 실왕복 1회로 검증 — glm-5.3-flash 가 구조화 출력을 첫 시도에 스키마대로 반환, 3레슨 개요 JSON 생성. lessongen-http-client 의 미검증 표시도 이로써 해소됨 |
| 2026-09-06T21:01:00+09:00 | #ui-isolation-settings | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 첫 실행 앱 — 653 테스트 통과, 스크린샷 확인 |
| 2026-09-06T21:01:00+09:00 | #color-tokens | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | monoFallback 을 SF Mono → Menlo 로 정정 (NSFont(name:) 해석 실패 실측), 스케일 12/14/18/11.5 추가 |
| 2026-09-06T21:01:00+09:00 | #type-scale | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 첫 실행 앱 — 653 테스트 통과, 스크린샷 확인 |
| 2026-09-06T21:01:00+09:00 | #ds-primitives | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | cornerRadius·shadow·Material·NavigationSplitView 0건 grep 테스트로 봉인 |
| 2026-09-06T21:01:00+09:00 | #app-shell-chrome | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 첫 실행 앱 — 653 테스트 통과, 스크린샷 확인 |
| 2026-09-06T21:01:00+09:00 | #unsupported-state-mapping | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 첫 실행 앱 — 653 테스트 통과, 스크린샷 확인 |
| 2026-09-06T21:01:00+09:00 | #install-hint-copy | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 클립보드 복사만, 프로세스 실행 0건 |
| 2026-09-06T21:01:00+09:00 | #cel-transitive-note | claude-code | 주의 | journal/20260906/Features_to_add/2101_feature_first-running-app.md | CodeEditLanguages·CodeEditSymbols 에 LICENSE 없음 — 조직 주요 저장소 3종이 MIT 라 누락으로 판단, 우리가 LICENSE 추가 PR 을 올린다 |
| 2026-09-06T22:35:00+09:00 | #cel-transitive-note | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #editor-config-tuning | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #editorui-target-pin | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | CESE 0.15.2 + PR #355 를 Vendor/ 에 벤더링 (165파일). CodeEditLanguages LICENSE 부재는 누락으로 판단 |
| 2026-09-06T22:35:00+09:00 | #fixed-height-reservation | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #lesson-output-slot | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #lesson-renderer | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 인라인은 AttributedString 위임, 블록만 직접. Body.prose 들여쓰기 근본 수정으로 방어 코드 제거 |
| 2026-09-06T22:35:00+09:00 | #mono-syntax-theme | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #platform-bump | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | macOS 14 확정, Textual 제거, ProseRenderer 자체 구현(821줄) |
| 2026-09-06T22:35:00+09:00 | #presenter-router | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #progress-cell-states | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 위협 어휘 11종 0건 grep 봉인 포함 |
| 2026-09-06T22:35:00+09:00 | #review-no-nudge | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | RatingButtonMetrics.shared 단일 상수 — rating 별 분기가 구조적으로 없음 |
| 2026-09-06T22:35:00+09:00 | #screen-dashboard | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #screen-lesson | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #screen-review | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T22:35:00+09:00 | #theme-weight-limitation | claude-code | [ ]→[x] | journal/20260906/Features_to_add/2101_feature_first-running-app.md | 화면 4종 조립 — 870 테스트, 스크린샷 확인 |
| 2026-09-06T23:03:05+09:00 | #font-registration-path | claude-code | ☐→x | .oculpm/journal/20260906/Chores/2302_chore_font-bundling-codesign-public-repo.md | 3웨이트씩 7.6MB 커밋, OFL 1.1 확인, CTFontManagerRegisterFontsForURL(.process) + 스냅샷 픽셀 diff 로 Plex 렌더 실증 |
| 2026-09-06T23:03:12+09:00 | #helper-signing | claude-code | ☐→x | .oculpm/journal/20260906/Chores/2302_chore_font-bundling-codesign-public-repo.md | learn-launcher 를 LearnKit 에서 별도 빌드해 Contents/Helpers 에 개별 서명 (ad-hoc, 인증서 없음), deep 없이 verify --deep --strict 통과 |
| 2026-09-06T23:03:23+09:00 | #github-public-repo | claude-code | ☐→x | .oculpm/journal/20260906/Chores/2302_chore_font-bundling-codesign-public-repo.md | README·CONTRIBUTING·NOTICE 작성, Unicorn Engine GPL 경고, CodeEditLanguages/Symbols LICENSE 부재 기록, 스크린샷 Plex 렌더로 교체 |
| 2026-09-07T06:16:58+09:00 | #packtool-structural | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_packtool-validation-gate.md | 매니페스트 디코딩·잠금 위반·디스크 양방향 대조·참조 파일 존재. 깨뜨린 픽스처 10종이 서로 다른 메시지로 실패 (기준 8종 초과) |
| 2026-09-07T06:17:05+09:00 | #example-stdout-compare | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_packtool-validation-gate.md | BOM·CRLF·후행 개행 셋만 정규화하고 줄 끝 공백은 접지 않는다 — LineDiff 로 줄 단위 증거 |
| 2026-09-07T06:17:12+09:00 | #task-solution-and-starter | claude-code | ☐→x | .oculpm/journal/20260907/Bugs/0616_bug_swift-grading-mutual-exclusion.md | solution 통과·starter 실패 둘 다 단언. 다만 이 게이트가 처음엔 거짓 실패를 냈다 — SwiftPM 템플릿 공유 결함을 SwiftGradingGate 로 고친 뒤에야 신뢰 가능 |
| 2026-09-07T06:17:18+09:00 | #packtool-semantic | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_packtool-validation-gate.md | 파싱을 통과한 값에 퀴즈·빈칸 정합성을 독립적으로 재단언, 전부 line:column 동반 |
| 2026-09-07T06:17:24+09:00 | #packtool-report | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_packtool-validation-gate.md | 별도 PackReport 타깃이 두 실행 파일의 유일한 접점. text/json(canonicalJSON)/JUnit 3형식, stagesRun 으로 스킵을 통과로 못 읽게 |
| 2026-09-07T06:17:31+09:00 | #toolchain-skip-policy | claude-code | ☐→~ | .oculpm/journal/20260907/Features_to_add/0615_feature_packtool-validation-gate.md | 툴 쪽 절반만 완료 — 부재 시 실패가 기본, --allow-missing-toolchain 에서만 스킵하고 stagesRun 에 기록. "경량 러너를 게이트로 세지 않음" 은 #ci-gate 에 얹혀 있어 아직 미검증 |
| 2026-09-07T06:17:37+09:00 | #inline-diagnostic-row | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_editor-console-sql-result-screens.md | EditorDiagnosticPresentation 순수 함수로 분리해 뷰 없이 테스트 — 진단 붙은 행만 배경 전환 |
| 2026-09-07T06:17:44+09:00 | #red-budget-guard | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_editor-console-sql-result-screens.md | RedBudgetTests 가 소스를 훑어 Palette.fail 1곳(종료 코드 배지)임을 단언. SQL diff 화면은 적색 사각이 구조적 필수라 예산 밖으로 명시 제외 |
| 2026-09-07T06:17:50+09:00 | #sql-row-padding | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0615_feature_editor-console-sql-result-screens.md | SQLDiffPresentation 이 짧은 쪽에 누락 플레이스홀더를 채워 두 표 높이를 맞춤 — 하단 캡션 y 고정 |
| 2026-09-07T06:17:57+09:00 | #lessongen-batch-fanout | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md | BoundedFanout 동시성 제한 병렬. Batch 엔드포인트는 쓰지 않음 — 재판단 근거는 1946 리팩터 일지 |
| 2026-09-07T06:18:05+09:00 | #lessongen-prompt-caching | claude-code | ☐→! | .oculpm/journal/20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md | 배선은 끝났으나 완료 기준 미달 — 실왕복 7회에서 session_id 를 보내도 업스트림이 NextBit·Wafer·Reka 로 갈려 cached_tokens 가 계속 0. 다음 수: provider.only/order 로 업스트림 고정 실측 |
| 2026-09-07T06:18:11+09:00 | #lessongen-quarantine | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md | 3회 실패 시 레슨·사이드카를 팩에서 지우고 명단과 함께 non-zero. 시도 장부가 실행을 넘어 이어짐 |
| 2026-09-07T06:18:18+09:00 | #lessongen-runlog | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md | 실행별 디렉터리에 요청·응답·usage·cost·model·seed·temperature·upstream·generation id. --max-usd 초과 시 새 요청 중단. 결산이 캐시 미적중과 갈린 업스트림을 직접 찍음 |
| 2026-09-07T06:42:28+09:00 | #packtool-sign | claude-code | ☐→x | .oculpm/journal/20260907/Features_to_add/0642_feature_packtool-build-and-sign.md | Ed25519 분리 서명, 키는 POLYGLOT_PACK_SIGNING_KEY/PUBLIC_KEY 환경변수 전용. verify 는 서명+해시 둘 다 — 서명만으로는 레슨 본문 변조를 못 잡는다(실증). 미서명·변조·다른 키가 서로 다른 판정 |
| 2026-09-07T06:56:18+09:00 | #lessongen-prompt-caching | claude-code | !→! | .oculpm/journal/20260907/Features_to_add/0656_feature_openrouter-upstream-pin.md | 막힘 유지 — 배선은 끝났다. provider.order + allow_fallbacks(기본 금지)로 고정하는 --provider 를 붙였고 dry-run 으로 요청 본문까지 실증. 결산이 "고정이 새었다"를 갈라 찍는다. 남은 것은 실왕복 측정뿐이며 크레딧이 나가 사용자 승인 대기 |
| 2026-09-07T06:57:56+09:00 | #screen-registers-deferred | claude-code | ☐→x |  | 프리젠터 절반은 이미 서 있었다 — PresenterRoute 가 .registers 를 .preparing 으로 보내고 switch 가 exhaustive 라 케이스를 늘리면 컴파일이 깨진다. 남은 절반을 docs/milestones/assembly-registers.md 로 채웠다 — 착수 조건(에뮬레이터 먼저, Unicorn Engine GPL 판정이 코드보다 먼저)과 화면 규칙 포함 |
<!-- oculpm:plan-log end -->
