# 릴리스와 자동 업데이트

Polyglot 은 Sparkle 2.9.6 으로 자동 업데이트한다. 이 문서는 **키를 어디에 두는지**,
**릴리스 한 번이 무엇을 하는지**, **무엇이 아직 안 닫혔는지** 를 적는다.

관련 플래너 항목: `{#sparkle-updates}` · `{#sparkle-eddsa-keys}` · `{#sparkle-appcast}`.

## 한눈에

```bash
# 최초 1회 — EdDSA 키를 로그인 키체인에 만든다
App/.build/artifacts/sparkle/Sparkle/bin/generate_keys

# 릴리스 한 번 = 조립 + 서명 + zip + appcast 갱신
App/Scripts/release.sh --version 0.2.0

# 업데이트 왕복 실측 (사람 없이, 일회용 키로)
App/Scripts/verify-sparkle.sh
```

## 키 — 개인키는 저장소에 없다

`generate_keys` 는 ed25519 키쌍을 만들어 **개인키를 로그인 키체인에만** 넣는다
(서비스 `https://sparkle-project.org`, 계정 `ed25519`). 저장소에 들어가는 것은 공개키
하나뿐이고, 자리는 `App/Resources/Info.plist` 의 `SUPublicEDKey` 다.

```
SUPublicEDKey = HRRXJyBOBY0aer/wNjrtCQppaKr/qYJrg/BSQhI/6b4=
```

개인키를 파일로 내보내지 마라. `generate_keys -x` 는 존재하지만, 키를 다른 맥으로 옮길
때 말고는 쓸 일이 없다. 옮긴 뒤에는 파일을 지운다.

### 키체인 접근 승인 — 한 번은 사람이 눌러야 한다

`generate_appcast` 와 `generate_keys` 는 **서로 다른 실행 파일**이라, appcast 를 처음 굽는
순간 macOS 가 "generate_appcast 가 키체인 항목에 접근하려 한다" 대화상자를 띄운다.
**항상 허용**을 눌러야 한다. 누르기 전까지 `generate_appcast` 는 이렇게 실패한다:

```
Warning: Private key for account ed25519 not found in the Keychain (-128)
Error: could not sign ... due to lack of private EdDSA key
```

`-128` 은 "키가 없다" 가 아니라 `errSecUserCanceled` 다 — 대화상자가 뜨지 못했거나
거부됐다는 뜻이다. 헤드리스 세션(SSH·CI·백그라운드 작업)에서는 이 대화상자를 누를 수
없으므로, 그런 환경에서는 아래 CI 경로를 쓴다.

### CI — 키체인 없이 서명하기

```bash
echo "$SPARKLE_PRIVATE_KEY" | App/Scripts/release.sh --version 0.2.0 --ed-key-file -
```

`--ed-key-file -` 는 표준 입력에서 키를 읽는다. 키가 파일로도, 명령 인자로도(=`ps` 에도),
로그로도 남지 않는다. 시크릿 값은 32바이트 시드의 base64 다.

## 피드 URL — 단일 출처는 Info.plist

`App/Resources/Info.plist` 의 `SUFeedURL` 이 유일한 출처다. `release.sh` 는 여기서
읽어 다운로드 URL 접두사(디렉터리 부분)와 appcast 파일 이름(마지막 경로 요소)을 만든다.
따로 인자로 받지 않는 이유는 앱이 읽는 주소와 appcast 가 광고하는 주소가 어긋나면
업데이트가 "받아지긴 하는데 설치가 안 되는" 형태로 조용히 깨지기 때문이다.

```
SUFeedURL = https://polyglotstudy.github.io/polyglot/appcast.xml
```

> **아직 확인되지 않은 값이다.** 이 저장소에는 git 원격이 없고 GitHub Pages 도 없다.
> 위 주소는 번들 식별자 `com.polyglotstudy.Polyglot` 에서 끌어온 것이지 실재를 확인한
> 것이 아니다. 원격을 붙이는 사람이 실제 Pages 주소로 이 값을 맞춰야 한다.

## 릴리스 한 번이 하는 일

`App/Scripts/release.sh --version X.Y.Z`:

1. `build-app.sh --release` 로 `.app` 조립 — 이때 `CFBundleShortVersionString` 과
   `CFBundleVersion` 을 **서명 전에** 덮어쓴다. Info.plist 는 봉인 대상이라 서명 뒤에
   고치면 그 자리에서 서명이 깨진다.
2. 조립된 번들에 `SUPublicEDKey` 가 있는지 확인. 없으면 거기서 멈춘다 — 공개키 없는
   앱은 피드를 영영 못 읽는데, 그걸 릴리스를 굽고 나서 알면 늦다.
3. `ditto -c -k --sequesterRsrc --keepParent` 로 zip. `/usr/bin/zip` 을 쓰면 안 된다 —
   심볼릭 링크를 따라가 버려 `Sparkle.framework/Versions` 구조가 뭉개지고, 압축을 푼
   앱의 코드 서명이 깨진다.
4. `generate_appcast` 로 `appcast.xml` 갱신 — 새 항목의 `sparkle:edSignature` 와
   `length` 가 이때 채워진다.
5. **단언**: appcast 의 해당 버전 항목에 서명이 비어 있지 않고, `length` 가 실제 zip
   크기와 같은지 확인. 어긋나면 릴리스 실패.

산출물(`App/.build/release/`)을 GitHub Pages 에 그대로 올리면 된다. `old_updates/` 는
`generate_appcast` 가 밀어낸 옛 아카이브라 올리지 않는다.

## 앱 쪽 배선

| 자리 | 내용 |
| --- | --- |
| `App/Package.swift` | Sparkle `exact: "2.9.6"`, 실행 파일에 `@executable_path/../Frameworks` rpath |
| `App/Scripts/build-app.sh` | `Sparkle.framework` 를 `Contents/Frameworks/` 로 복사하고 **안쪽부터** 서명 |
| `App/Sources/PolyglotApp/Updates.swift` | `SPUStandardUpdaterController` + 애플 메뉴의 "업데이트 확인…" |
| `App/Sources/PolyglotApp/SparkleProbe.swift` | 헤드리스 검증용 `SPUUserDriver`(환경 변수로만 켜진다) |

Sparkle 은 SPM 바이너리 타깃이라 `swift build` 가 링크만 하고 번들에 넣어주지 않는다
(SPM 에 "앱 번들" 개념이 없다). 프레임워크 안에 실행 파일이 넷 더 있고
(`Autoupdate`, `Updater.app`, `XPCServices/Downloader.xpc`, `XPCServices/Installer.xpc`)
전부 개별 서명해야 한다. `Autoupdate` 는 `com.apple.application-identifier` entitlement 를
달고 오므로 재서명할 때 `--preserve-metadata=entitlements` 가 필요하다.

## 검증

`App/Scripts/verify-sparkle.sh` 가 두 가지를 증명한다.

1. **정상 왕복** — 구버전 앱이 appcast 를 읽고, 신버전을 받고, EdDSA 서명을 검증하고,
   자기 자신을 교체한다. 판정은 설치된 번들의 `CFBundleShortVersionString` 이 바뀌었는지다.
2. **거부** — appcast 의 `sparkle:edSignature` 를 한 글자 비틀면 앱이 교체되지 **않는다**.
   (1)만 통과하는 것은 증거가 아니다. 검증을 통째로 끄면 (1)은 항상 통과한다.

로컬 HTTP 서버(127.0.0.1)와 **일회용 키**를 쓴다. 배포용 개인키는 키체인 승인 대화상자를
요구해서 자동 검증에 넣을 수 없고, 검증 대상은 "이 특정 키" 가 아니라 배선이기 때문이다.

## ad-hoc 서명과 Sparkle — 실측

이 저장소에는 Developer ID 인증서가 없어서 `build-app.sh` 가 ad-hoc(`-`) 으로 서명한다.
"Sparkle 이 코드 서명 동일성을 검사하니 ad-hoc 으로는 설치까지 못 간다" 는 흔한 오해다.
`Sparkle/SUUpdateValidator.m` 의 규칙은 이렇다.

- **정책**: 구버전이 코드 서명돼 있으면 신버전도 코드 서명돼 있어야 한다. ad-hoc 이면
  충분하다 — Sparkle 의 오류 메시지가 직접 그렇게 적고 있다("If no Apple Code Signing
  certificate is available, adhoc signing can be used at minimum").
- **보안**: `passedDSACheck || passedCodeSigning` — **둘 중 하나만** 유효하면 통과한다.
  키 회전 때문에 일부러 이렇게 돼 있다. 즉 EdDSA 서명이 맞으면 코드 서명 신원이 달라도
  된다.

그래서 ad-hoc + EdDSA 조합으로 설치까지 간다. Developer ID 가 필요한 것은 Sparkle 이
아니라 **Gatekeeper/공증**이다 — 남의 맥에서 앱이 처음 열릴 때. `Codesign/notarize.sh` 참고.

## 아직 안 닫힌 것

- **git 원격과 GitHub Pages 가 없다.** 실제 피드 주소로 왕복한 적이 없다. `SUFeedURL` 이
  실재하는 주소인지 확인해야 한다.

  이건 문서의 경고로만 두지 않았다 — `release.sh` 가 **확보되지 않은 호스트로는 릴리스를
  거부한다**(`UNVERIFIED_FEED_HOSTS`). 이 상태로 배포물을 구우면 나중에 그 호스트를
  가로챈 사람이 업데이트 피드를 쥐기 때문이다. EdDSA 검증이 임의 코드는 막지만, 우리가
  서명한 **구버전으로의 다운그레이드**와 업데이트 차단은 막지 못한다.

  주소를 실제로 확보했다면 `Info.plist` 의 `SUFeedURL` 을 그 주소로 바꾸고
  `release.sh` 의 `UNVERIFIED_FEED_HOSTS` 에서 호스트를 지워라. 검증 목적이면
  `--feed-url` 로 덮어쓰거나 `POLYGLOT_FEED_HOST_VERIFIED=1` 을 줘라.
- **Developer ID 인증서가 없다.** 배포본은 ad-hoc 서명이라 다른 맥에서 Gatekeeper 에
  막힌다. 업데이트 경로 자체와는 별개 문제다.
- **키체인 승인**을 아직 아무도 누르지 않았다. 배포용 키로 appcast 를 처음 구울 때
  대화상자가 뜬다.
