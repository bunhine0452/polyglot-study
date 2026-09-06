---
schema_version: 1
type: feature
slug: "sparkle-auto-update"
status: done
difficulty: high
created_at: "2026-09-07T07:33:01+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (병렬 워크트리 세션)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Package.swift"
    op: update
  - path: "App/Resources/Info.plist"
    op: update
  - path: "App/Scripts/build-app.sh"
    op: update
  - path: "App/Scripts/release.sh"
    op: create
  - path: "App/Scripts/verify-sparkle.sh"
    op: create
  - path: "App/Sources/PolyglotApp/Updates.swift"
    op: create
  - path: "App/Sources/PolyglotApp/SparkleProbe.swift"
    op: create
  - path: "App/Codesign/notarize.sh"
    op: update
  - path: "docs/release.md"
    op: create
related:
  - ref: "20260906/Chores/2302_chore_font-bundling-codesign-public-repo.md"
    kind: "followup"
tags:
  - "sparkle"
  - "codesign"
  - "release"
  - "security"
  - "parallel"
  - "mcp-tool"
---
[x] Sparkle 자동 업데이트 — ad-hoc 서명으로도 설치까지 왕복한다

병렬 워크트리 세션(Opus)이 구현하고 부모 세션이 병합·재검증한 뒤 릴리스 게이트를 하나 더 걸었다.

## 추가 기능

Sparkle 2.9.6 을 `exact` 로 핀해 앱에 임베드하고, EdDSA 서명으로 업데이트를 검증한다. `release.sh` 가 조립 → zip → `generate_appcast` → 서명·길이 단언까지 한 번에 하고, `verify-sparkle.sh` 가 로컬 피드로 **정상 왕복과 거부 왕복을 사람 없이** 검증한다.

## 동작 흐름

**내 지시가 틀렸다 — ad-hoc 서명은 Sparkle 을 막지 않는다.** 세션에 "Developer ID 가 없어 설치까지 못 갈 수 있다"고 미리 적어 보냈는데, `SUUpdateValidator.m` 의 판정은 `passedDSACheck || passedCodeSigning` 이라 **둘 중 하나만** 유효하면 통과한다(키 회전을 깨지 않으려는 설계). Sparkle 자신의 오류 문구가 "adhoc signing can be used at minimum" 이라고 적고 있다.

**실제로 막은 것은 Sparkle 이 아니라 dyld 였다.**

```
Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
... mapping process and mapped file (non-platform) have different Team IDs
```

Hardened Runtime 이 라이브러리 검증을 함께 켜는데 **ad-hoc 서명에는 Team ID 가 없다.** 앱과 프레임워크를 같은 명령으로 ad-hoc 서명해도 로드가 거부된다. `com.apple.security.cs.disable-library-validation` 으로 풀되 **ad-hoc 일 때만** 붙인다 — 기본 `Polyglot.entitlements` 는 손대지 않고 빌드 시 복사본에만 넣고, "Team ID 가 없는데 예외도 없으면" 빌드를 실패시키는 사후 단언까지 있다. Developer ID 에서는 두 신원이 같아져 예외 자체가 사라진다.

부수 실측: `generate_keys` 와 `generate_appcast` 는 서로 다른 실행 파일이라 첫 appcast 생성 때 키체인 승인 대화상자가 뜬다. 헤드리스에서는 못 눌러 `errSecUserCanceled(-128)` 로 실패하는데 Sparkle 은 이를 "not found in the Keychain" 으로 찍는다 — 키는 멀쩡히 있다.

## 부모가 하나 더 걸었다 — 확보되지 않은 피드 호스트

`SUFeedURL` 이 `polyglotstudy.github.io` 를 가리키는데 **아무도 소유하지 않은 추정 주소**다(원격도 Pages 도 없다). 세션은 이것을 Info.plist 주석과 `docs/release.md` 에 경고로 남겼는데, 문서 경고는 지켜지지 않는다.

이 상태로 배포물을 구우면 나중에 그 호스트를 가로챈 사람이 업데이트 피드를 쥔다. EdDSA 검증이 임의 코드는 막지만 **우리가 서명한 구버전으로의 다운그레이드와 업데이트 차단은 막지 못한다.**

그래서 `release.sh` 에 게이트를 넣었다 — 확보되지 않은 호스트 목록에 걸리면 릴리스가 멈춘다. 주소를 실제로 확보한 사람이 목록에서 지우거나 `POLYGLOT_FEED_HOST_VERIFIED=1` 로 명시해야 한다. `--feed-url` 오버라이드 경로(검증용)는 게이트 앞에서 갈라져 영향받지 않는다.

## 검증

세션 보고를 그대로 받지 않고 병합 후 부모가 다시 돌렸다.

- `App/Scripts/verify-sparkle.sh` → **전부 통과**. 구버전 0.1.0 이 appcast 를 읽어 0.2.0 을 받고 서명 검증 후 설치까지 갔고(설치된 번들의 `CFBundleShortVersionString` 이 0.2.0), 서명을 한 글자 비튼 사본은 `SUSparkleErrorDomain 3002` 로 거부되며 버전이 0.1.0 그대로였다. 게이트를 추가한 뒤 다시 돌려도 같다.
- 기본 `Polyglot.entitlements` 에 `disable-library-validation` **0건** — 예외는 ad-hoc 빌드의 복사본에만 붙는다.
- 저장소 전체에 개인키 0건 (`BEGIN … PRIVATE KEY` 0건, `*.pem`/`*.der`/`*.key` 0건). 공개키만 Info.plist 와 문서에 있다.
- 새 게이트: `--feed-url` 없이 `release.sh` 를 부르면 종료 코드 1 로 멈춘다.

## 메모

실제 Pages 주소로는 왕복한 적이 없다 — 전송이 `127.0.0.1` HTTP 이고 검증용 키는 일회용이다. 검증되는 **코드 경로**는 같지만 그 사실을 `{#sparkle-appcast}` 의 미완 사유로 남긴다.