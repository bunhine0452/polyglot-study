---
schema_version: 1
type: chore
slug: "font-bundling-codesign-public-repo"
status: done
difficulty: medium
created_at: "2026-09-06T23:02:49+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Resources/Fonts/IBMPlexSansKR-Regular.ttf"
    op: create
  - path: "App/Resources/Fonts/IBMPlexSansKR-Medium.ttf"
    op: create
  - path: "App/Resources/Fonts/IBMPlexSansKR-SemiBold.ttf"
    op: create
  - path: "App/Resources/Fonts/IBMPlexMono-Regular.ttf"
    op: create
  - path: "App/Resources/Fonts/IBMPlexMono-Medium.ttf"
    op: create
  - path: "App/Resources/Fonts/IBMPlexMono-SemiBold.ttf"
    op: create
  - path: "App/Resources/Fonts/LICENSE.txt"
    op: create
  - path: "App/Sources/PolyglotApp/FontRegistration.swift"
    op: create
  - path: "App/Sources/PolyglotApp/PolyglotApp.swift"
    op: update
  - path: "App/Codesign/Polyglot.entitlements"
    op: create
  - path: "App/Codesign/notarize.sh"
    op: create
  - path: "App/Scripts/build-app.sh"
    op: update
  - path: "docs/screenshots/app-today.png"
    op: update
  - path: "docs/screenshots/app-review.png"
    op: update
  - path: "docs/screenshots/app-toolchain.png"
    op: update
  - path: "README.md"
    op: create
  - path: "CONTRIBUTING.md"
    op: create
  - path: "NOTICE"
    op: create
related: []
tags:
  - "fonts"
  - "codesign"
  - "distribution"
  - "docs"
  - "mcp-tool"
---
[x] IBM Plex 폰트 번들링, Hardened Runtime 서명, GitHub 공개 준비

## 추가 기능

1. **폰트 번들링** (`{#plex-font-bundling}` `{#font-registration-path}`) — IBM Plex Sans KR ·
   IBM Plex Mono 를 각 3웨이트(Regular·Medium·SemiBold, 실제 코드에서 쓰는 웨이트만)로
   `App/Resources/Fonts/`에 커밋(7.6MB). `FontRegistration.swift`가
   `CTFontManagerRegisterFontsForURL(_:.process,_:)`로 앱 init 초반에 등록한다.
2. **서명** (`{#codesign-hardened-runtime}` `{#helper-signing}`) — `build-app.sh`가 매 빌드
   `learn-launcher`를 LearnKit에서 별도로 빌드해 `Contents/Helpers/`에 넣고 개별 서명한 뒤,
   `App/Codesign/Polyglot.entitlements`(app-sandbox 키 없음)로 앱 본체를 Hardened Runtime
   켠 채 서명한다. 서명 신원은 `security find-identity`로 탐지하고 없으면 ad-hoc.
3. **공개 준비** (`{#github-public-repo}`) — README·CONTRIBUTING·NOTICE 작성, 화면 스크린샷을
   Plex 렌더 결과로 교체.

## 동작 흐름

**폰트 라이선스 확인** — 웹 검색 + `github.com/IBM/plex`의 `LICENSE.txt` 원문 대조로 SIL OFL
1.1(Reserved Font Name "Plex") 확정. OFL 조건 2(라이선스 동봉)를 만족시키려고 폰트 파일
옆에 `LICENSE.txt`를 그대로 두고, 저장소 루트 `NOTICE`에도 전문을 실었다.

**폰트 파일 출처와 용량 판단** — `github.com/IBM/plex` 공식 저장소 git tree API로 필요한
파일만(전체 zip 다운로드 없이) 커밋 SHA `1da12f0...`(태그 `@ibm/plex-sans-kr@1.1.0` /
`@ibm/plex-mono@2.5.0`)에서 직접 받았다. 전체 8웨이트×hinted/unhinted를 다 담으면 Sans KR
하나만 70MB를 넘어 과했다 — `grep`으로 실제 코드에서 쓰는 weight(`AppFont.sans/mono`
호출부의 `.medium`/`.semibold`, 나머지는 기본 regular)만 추려 3웨이트씩, 합계 7.6MB로
줄였다.

**패밀리명 실측** (`AppFont.resolve(_:)`) — 등록 후 CoreText로 직접 조회한 결과:
PostScript 이름은 `IBMPlexSansKR`/`IBMPlexMono`(공백 없음), 표시 패밀리는
`IBM Plex Sans KR`/`IBM Plex Mono`(공백 있음). `Typography.sansFamily`/`monoFamily`
토큰은 이미 PostScript 형으로 적혀 있어 `AppFont.resolve`의 **2단계**
(`NSFont(name:)`이 PostScript 이름을 직접 푸는 경로)에서 잡힌다 — 1단계(전체 패밀리 정확
일치)는 표시 패밀리만 담고 있어 실패. 토큰 값은 고칠 필요가 없었다.

**렌더 검증(스크린샷 기반)** — 서명된 `.app` 번들 실행과 `swift run`류 raw 실행 둘 다에서
`POLYGLOT_SNAPSHOT_PATH`로 스냅샷을 떠 비교했다: (1) 정상 등록 상태의 두 실행 경로는
픽셀 단위로 완전히 동일 — 번들 실행에서는 `Info.plist`의 `ATSApplicationFontsPath`가,
raw 실행에서는 `FontRegistration`이 각각 커버한다. (2) `POLYGLOT_FONTS_PATH`를 존재하지
않는 경로로 강제해 raw 실행의 등록을 의도적으로 깨뜨리자 렌더가 확연히 달라짐(픽셀 diff
bbox가 이미지 전체를 덮음, Apple SD Gothic Neo 폴백으로 확인) — 이로써 정상 상태는
폴백이 아니라 실제 Plex로 렌더된다는 것과 `FontRegistration`이 raw 실행 경로에서 실제로
필요하다는 것 둘 다 증명됐다.

**서명** — `security find-identity -v -p codesigning` 결과 0건(이 머신에 Developer ID
인증서 없음) → ad-hoc(`-`)으로 앱과 헬퍼를 **같은 신원**으로 서명. 순서는 헬퍼(leaf)
먼저, 컨테이너(app) 나중 — `--deep` 미사용. `codesign -dv`에 `flags=...(adhoc,runtime)`
확인, `codesign -d --entitlements -`에 `app-sandbox` 키 없음(빈 dict) 확인,
`codesign --verify --deep --strict`가 헬퍼 포함 통과 확인. `--release` 빌드도 동일하게
서명되고 `open -n`으로 실제 창이 뜬 뒤 정상 종료됨을 확인.

**엔타이틀먼츠 XML 함정** — 처음 작성한 `Polyglot.entitlements` 주석에 `--options runtime`
같은 flag 표기를 그대로 썼다가 `AMFIUnserializeXML: syntax error`로 서명이 실패했다 —
XML 주석 안에는 `--`(연속 하이픈)를 쓸 수 없다는 규칙 때문. 주석 문구를 풀어 써서 해결.

**README 정직성** — packtool이 `validate`/`build`/`sign` 세 하위 명령 정의만 있고 미구현
스텁(`swift run --package-path Tools packtool --help`로 실측)이라는 것, lessongen이
`outline`만 있고 `lesson`/`repair`는 없다는 것, 레슨 콘텐츠가 3편(언어당 1편)뿐이고 7개
트랙이 완전히 미착수라는 것을 표로 명시했다. Unicorn Engine(GPL-2.0) 경고 한 줄과
CodeEditLanguages/CodeEditSymbols의 LICENSE 부재(누락으로 판단한 근거 포함)도 담았다.

## 검증

- `swift test --package-path Packages/LearnKit` — 870개 전부 통과, 경고 0 (건드리지 않았음을 재확인).
- `swift test --package-path Tools` — 139개 전부 통과.
- `swift build --package-path App -c debug`(clean) — 경고 0.
- `App/Scripts/build-app.sh --debug`와 `--release` 둘 다: 빌드→헬퍼 빌드→서명→
  `codesign --verify --deep --strict` 통과까지 성공.
- `open -n Polyglot.app` 실행 후 프로세스 생존 확인, 정상 종료.
- 스크린샷 3장(오늘·복습·툴체인)을 실제 서명된 번들에서 재촬영해 `docs/screenshots/`에
  반영(이전 스크린샷은 폴백 폰트 상태였음을 픽셀 diff로 확인).

## 메모

`{#notarize-staple-dmg}`와 하위 항목은 지시대로 스크립트 자리(`App/Codesign/notarize.sh`)만
만들고 실행하지 않았다 — Apple Developer 계정이 없다. `{#release-ci}`, Sparkle 관련 항목은
이번 범위 밖.