---
schema_version: 1
type: feature
slug: "developer-id-signing-notarize-wiring"
status: in_progress
difficulty: medium
created_at: "2026-09-07T21:34:23+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Scripts/build-app.sh"
    op: update
  - path: "App/Codesign/notarize.sh"
    op: update
  - path: "App/Scripts/release.sh"
    op: update
  - path: ".github/workflows/release.yml"
    op: update
  - path: "App/Pages/index.html"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/release.md"
    op: update
related: []
tags:
  - "codesign"
  - "notarization"
  - "release"
  - "ci"
  - "gatekeeper"
  - "mcp-tool"
---
[x] Developer ID 서명 착지 + 공증·스테이플 배선 — ad-hoc 탈출

사용자가 Apple Developer Program 에 가입하고 Developer ID Application 인증서를 발급했다
(Team ID `BP57Z7L498`). 저장소 전체가 "인증서 없음" 을 전제로 쓰여 있던 것을 실제 인증서
기준으로 옮기고, 스텁이던 공증 경로를 채웠다.

## 추가 기능

**1. 신원을 순서가 아니라 이름으로 고른다** (`build-app.sh`).
기존 코드는 `security find-identity | head -1` 로 **첫 줄**을 집었다. 지금은 신원이 하나뿐이라
우연히 맞지만, Xcode 에 로그인하면 `Apple Development:` 가 함께 생긴다. 그건 배포용이 아니라
공증이 거부하는데, `head -1` 은 그걸 조용히 집고 실패는 한참 뒤 공증 단계에서야 드러난다.
`Developer ID Application` 을 이름으로 고르도록 바꿨고, 신원은 있는데 Developer ID 가 아닐 때는
무엇을 찾았는지 찍고 ad-hoc 으로 떨어진다.

**2. 타임스탬프를 조건부로 켠다.** 공증은 보안 타임스탬프를 요구한다. Developer ID 경로에서는
`--timestamp`, ad-hoc 경로에서는 `--timestamp=none` 그대로 — ad-hoc 빌드를 애플 서버 왕복에
묶지 않아 오프라인에서도 돈다. `TIMESTAMP_FLAG` 한 변수로 codesign 4곳에 흐른다.

**3. `notarize.sh` 스텁을 채웠다.** 스텁은 DMG 를 전제했는데 실제 배포물은 zip 이라 순서가
다르다. 제출 전 3종 검사(Team ID 없음 · ad-hoc 전용 `disable-library-validation` 잔존 ·
타임스탬프 누락)로 "올려 봐야 몇 분 뒤 Invalid" 를 먼저 막고, 제출 → 스테이플 →
`stapler validate` + `spctl` + `codesign --verify` 로 닫는다. 자격증명은 로컬 키체인
프로파일과 CI 용 App Store Connect API 키 두 경로를 지원한다.

**4. `release.sh --notarize`** 를 앱 조립과 아카이브 **사이**에 끼웠다. 옵트인인 이유는
`verify-sparkle.sh` 가 이 스크립트로 검증용 릴리스를 굽기 때문이다 — 기본값으로 두면 로컬 검증
한 번마다 자격증명과 애플 서버 왕복 몇 분이 필요해진다.

**5. CI** 는 인증서를 러너 전용 임시 키체인에 넣고(`set-key-partition-list` 로 승인 대화상자
차단, `if: always()` 로 삭제), 공증 자격증명을 넘기고, 마지막에 **배포되는 zip 을 실제로 풀어**
`stapler validate` · `spctl` · `codesign --verify` 를 돌린다.

## 동작 흐름

```
build-app.sh(Developer ID 서명 + --timestamp)
  → notarize.sh(제출 전 검사 → submit --wait → staple → 검증)
  → ditto zip
  → generate_appcast
```

이 순서여야 하는 이유가 이번 작업의 핵심이다 — `{#staple-before-zip}`. **`stapler` 는 zip 에
스테이플하지 못한다.** 티켓은 `.app` 번들 안으로 들어간다. 공증이 아카이브 뒤로 밀리면 appcast 가
광고하는 `edSignature`·`length` 가 실제 배포 파일과 어긋나고, 업데이트는 "받아지긴 하는데 설치가
안 되는" 형태로 조용히 깨진다. 기존 스텁 주석은 DMG 를 전제해 이 제약을 담고 있지 않았다.

`notarytool` 이 디렉터리를 못 받으므로 제출용 zip 은 `notarize.sh` 가 임시로 하나 만들었다
지운다. 배포용 zip 은 스테이플이 끝난 뒤 `release.sh` 가 따로 만든다.

## 검증

- `build-app.sh --release` 실측: `Authority=Developer ID Application: … (BP57Z7L498)` ·
  `Timestamp=Sep 7, 2026 at 9:25:03 PM` · `flags=0x10000(runtime)` · entitlements 빈 dict
  (ad-hoc 예외 자동 제거됨) · `spctl` → `rejected / source=Unnotarized Developer ID` (공증 전
  정상 상태).
- `notarize.sh` 제출 전 검사 3종 통과 후 자격증명 부재 지점에서 정확히 정지.
- `verify-sparkle.sh` 전체 통과 — Developer ID 서명 번들로 0.1.0 → 0.2.0 설치 성공,
  서명 비튼 사본은 거부되고 0.1.0 유지. 릴리스 경로 회귀 없음.

## 메모

`grep -q` 를 `codesign … | grep -q` 로 쓰면 안 된다는 것을 실측으로 배웠다. `grep -q` 는 매치하는
순간 종료하며 `codesign` 에 SIGPIPE 를 보내고, `set -o pipefail` 이 그것을 파이프라인 실패로 잡는다.
타임스탬프가 **있는데도** 없다고 판정했다. 출력을 먼저 변수에 담아 파이프를 없앴다.

남은 것: 공증이 아직 한 번도 실행되지 않았다. 로컬은 `notarytool store-credentials`,
CI 는 시크릿 다섯(`DEVELOPER_ID_CERT_P12_BASE64` · `DEVELOPER_ID_CERT_PASSWORD` ·
`NOTARY_API_KEY_P8_BASE64` · `NOTARY_API_KEY_ID` · `NOTARY_API_ISSUER_ID`)이 조건이다.
DMG(`{#dmg-notarize}`)는 손대지 않았다 — 배포·Sparkle 둘 다 zip 이라 별개 항목이다.
이미 나간 v0.1.0-alpha.1 은 ad-hoc 그대로이고, 공증본은 다음 태그부터다.