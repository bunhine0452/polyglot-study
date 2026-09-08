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
SUFeedURL = https://bunhine0452.github.io/polyglot-study/appcast.xml
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
3. `--notarize` 가 있으면 여기서 `Codesign/notarize.sh` 가 앱을 공증·스테이플한다
   ({#notarize-staple-dmg}, 아래 절 참고). 없으면 건너뛴다.
4. `ditto -c -k --sequesterRsrc --keepParent` 로 zip. `/usr/bin/zip` 을 쓰면 안 된다 —
   심볼릭 링크를 따라가 버려 `Sparkle.framework/Versions` 구조가 뭉개지고, 압축을 푼
   앱의 코드 서명이 깨진다.
5. **`--notarize` 가 있을 때만** `Scripts/make-dmg.sh` 로 DMG 조립 + 서명 + 공증 +
   스테이플. 없으면 아예 건너뛴다 — DMG 는 스테이플된 앱을 요구하고, 스테이플은
   공증을 거쳐야 나오므로 공증 없는 DMG 는 배포할 수 없는 물건이다. 실질적으로
   **DMG 는 CI 에서만 만들어진다**. 자세한 내용은 아래 `DMG — 사람이 내려받는 경로`
   절({#dmg-notarize}).
6. `generate_appcast` 로 `appcast.xml` 갱신 — 새 항목의 `sparkle:edSignature` 와
   `length` 가 이때 채워진다.
7. **단언**: appcast 의 해당 버전 항목에 서명이 비어 있지 않고, `length` 가 실제 zip
   크기와 같은지 확인. 어긋나면 릴리스 실패.

산출물(`App/.build/release/`)에서 zip · appcast.xml · index.html 을 GitHub Pages 에
그대로 올리면 된다. `old_updates/` 는 `generate_appcast` 가 밀어낸 옛 아카이브라 올리지
않는다. **DMG 는 gh-pages 로 올리지 않는다** — Sparkle 피드는 zip 만 가리키므로, DMG 는
GitHub Release 자산으로만 올라간다(release 워크플로가 그렇게 배선돼 있다).

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

`build-app.sh` 는 키체인에 **Developer ID Application** 신원이 없으면 ad-hoc(`-`) 으로
떨어진다. 알파 v0.1.0-alpha.1 이 그렇게 나갔고, 아래는 그때 확인한 사실이다.
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

## 서명과 공증 — {#notarize-staple-dmg}

Apple Developer Program 가입은 끝났고(2026-09-07) Developer ID Application 인증서도
발급했다. `build-app.sh` 는 키체인에서 그 신원을 **이름으로** 골라 서명한다 — 목록의
첫 줄을 집지 않는 이유는 Xcode 로 로그인하면 함께 생기는 `Apple Development:` 가 배포에
쓸 수 없는 신원이고, 그걸로 서명하면 실패가 한참 뒤 공증 단계에서야 드러나기 때문이다.

### 순서가 전부다 — {#staple-before-zip}

```
build-app.sh(서명) → notarize.sh(공증·스테이플, 앱) → ditto zip → generate_appcast
                                  │
                                  └→ make-dmg.sh(DMG 조립·서명) → notarize.sh(공증·스테이플, DMG)
```

`stapler` 는 **zip 에 스테이플하지 못한다.** 티켓은 `.app` 번들(또는 DMG) 안/위로
들어간다. 그래서 공증이 아카이브 뒤로 밀리면 appcast 가 광고하는 `edSignature`·`length`
가 실제 배포 파일과 어긋나고, 업데이트는 "받아지긴 하는데 설치가 안 되는" 형태로
조용히 깨진다. `release.sh --notarize` 가 이 순서를 강제한다 — 앱을 먼저 공증·스테이플한
뒤에야 zip 을 묶고 DMG 에 담는다. DMG 는 **그 뒤에** 따로 서명·공증·스테이플한다 — 앱과
DMG 는 Gatekeeper 가 검사하는 시점이 서로 다른 별개의 서명 대상이라, 앱만 하고 DMG
컨테이너를 안 하면 `stapler validate` 가 DMG 단독으로는 통과하지 못한다.

공증은 **옵트인**이다. `verify-sparkle.sh` 가 검증용 릴리스를 `release.sh` 로 굽는데,
공증을 기본값으로 두면 로컬 검증 한 번마다 애플 서버 왕복 몇 분과 자격증명이 필요해진다.
태그를 미는 release 워크플로는 항상 `--notarize` 를 넘긴다.

### 자격증명 — {#notary-credentials}

애플 ID·앱 암호·API 키는 스크립트·인자·로그 어디에도 리터럴로 남지 않는다.

**로컬** — notarytool 키체인 프로파일을 한 번만 저장하고 이후로는 이름만 부른다:

```
xcrun notarytool store-credentials "oculpm-notary" \
  --apple-id "<Apple ID>" --team-id "<TEAM_ID>" --password "<앱 암호>"
```

앱 암호는 appleid.apple.com 에서 만드는 app-specific password 다(계정 비밀번호가 아니다).
셸 히스토리에 남기기 싫으면 인자 없이 돌려 대화형으로 넣어라.

**CI** — Apple ID + 앱 전용 암호를 notarytool 에 직접 넘긴다. 헤드리스 러너에서 막히는
것은 키체인 **프로파일** 경로뿐이다: 분리된 프로세스가 승인 대화상자를 못 띄워
`errSecUserCanceled`(-128) 로 실패한다(EdDSA 키에서 부딪힌 그 벽과 같다). 자격증명을
인자로 주는 경로는 키체인을 아예 타지 않아 멀쩡히 돈다. 저장소 시크릿 다섯:

| 시크릿 | 내용 |
| --- | --- |
| `APPLE_CERTIFICATE` | Developer ID Application 인증서 `.p12` 의 base64 |
| `APPLE_CERTIFICATE_PASSWORD` | 그 `.p12` 를 내보낼 때 건 암호 |
| `APPLE_ID` | 공증에 쓸 Apple ID (이메일) |
| `APPLE_PASSWORD` | 그 계정의 **앱 전용 암호** (계정 비밀번호가 아니다) |
| `APPLE_TEAM_ID` | 10자 팀 식별자 |

`--password` 가 인자로 들어가므로 같은 머신의 `ps` 에 잠깐 보인다. 러너는 이 잡 전용으로
떴다 사라지므로 감수한다 — **로컬에서는 이 경로 대신 키체인 프로파일을 쓴다.**
`notarize.sh` 는 App Store Connect API 키 경로(`NOTARY_API_KEY_P8_BASE64` ·
`NOTARY_API_KEY_ID` · `NOTARY_API_ISSUER_ID`)도 그대로 지원한다 — 셋 중 먼저 발견한 것을 쓴다.

### .p12 는 인증서와 개인 키를 **둘 다** 담아야 한다

키체인 접근에서 인증서와 개인 키는 형제 행으로 보인다. **"개인 키" 행을 내보내면 키만
담긴 `.p12`** 가 나오고, `security import` 는 성공하는데 `find-identity` 에 신원이 안 잡혀
빌드가 조용히 ad-hoc 으로 떨어진다(실측 2026-09-07). 카테고리를 **"내 인증서"** 로 두고
인증서 행을 내보내거나, 두 행을 함께 선택해 내보낸다.

내보낸 파일이 맞는지는 크기와 구조로 판정한다 — 제대로 된 것은 3KB 안팎이고
**`pkcs7-encryptedData` 컨테이너를 하나** 갖는다(인증서가 그 안에 암호화돼 들어간다).
`certBag` OID 를 찾는 검사는 통하지 않는다. 암호화 영역 안이라 평문에 안 보인다.

```
openssl asn1parse -inform DER -in cert.p12 | head    # 구조
xxd -p cert.p12 | tr -d '\n' | grep -c 2a864886f70d010706   # encryptedData = 1 이어야 한다
```

### base64 실패는 조용하다

`base64 -i <경로> | gh secret set <이름>` 에서 경로에 공백이 있는데 따옴표를 빼면 `base64` 가
실패하고 **빈 표준 출력**을 흘린다. `gh secret set` 은 그것을 받아 "✓ Set" 을 찍는다 — 빈
시크릿이 성공으로 보인다(실측 2026-09-07). 파이프 전에 길이를 먼저 확인한다:

```
base64 -i "$HOME/Desktop/cert.p12" | wc -c    # 4000 이상
```

`~` 는 따옴표 안에서 확장되지 않으므로 `$HOME` 을 쓴다.

워크플로는 이것을 러너 전용 임시 키체인에 넣고, `set-key-partition-list` 로 승인
대화상자를 막고, 잡이 끝나면 (`if: always()`) 지운다.

### 검증

`notarize.sh` 는 제출 전에 세 가지를 먼저 막는다 — ad-hoc 대상(Team ID 없음), ad-hoc
전용 `disable-library-validation` 예외 잔존, 보안 타임스탬프 누락. 셋 다 올려 봐야 몇 분
뒤 Invalid 로 돌아온다.

제출 뒤에는 `stapler validate` · `spctl --assess` · `codesign --verify` 를 돌린다. 앱과
DMG 는 평가 방식이 다르다 — 앱은 `--type execute` + `--verify --deep --strict`(번들이라
중첩 코드가 있다), DMG 는 `--type open --context context:primary-signature` +
`--verify --strict`(단일 서명 대상이라 `--deep` 이 필요 없다). `notarize.sh` 는 인자로
받은 것이 디렉터리(`.app`)인지 파일(`.dmg`)인지로 이 둘을 스스로 가른다 — 호출하는
쪽에서 따로 알려줄 필요가 없다.

릴리스 워크플로는 한 발 더 나가 **배포되는 zip 을 실제로 풀어** 같은 검사를 한다 —
랜딩 페이지에 "그냥 열면 됩니다" 라고 적어 놓고 정작 Gatekeeper 가 막는 사태를 막는
게이트다. DMG 도 같은 자리에서 독립적으로 확인한다.

`spctl` 출력으로 상태를 읽는다:

- `rejected` / `source=Unnotarized Developer ID` — 서명은 됐고 공증 전
- `accepted` / `source=Notarized Developer ID` — 공증·스테이플 완료

## DMG — 사람이 내려받는 경로 {#dmg-notarize}

zip 은 Sparkle 자동 업데이트가 쓰는 산출물이다. DMG 는 **사람이 내려받는 경로**로
따로 만든다 — 둘 다 매 릴리스마다 나간다.

**DMG 는 이 기계가 아니라 GitHub 에서 만든다.** 태그를 밀면 release 워크플로가
`release.sh --notarize` 를 돌리고, 그 안에서 DMG 가 조립·서명·공증·스테이플되어
GitHub Release 자산으로 올라간다. 로컬에서 `release.sh` 를 `--notarize` 없이 돌리면
DMG 단계는 그냥 건너뛴다 — 검증용 로컬 실행이 hdiutil 과 애플 서버 왕복을 탈 이유가
없고, 공증 없이 나온 DMG 는 어차피 배포물이 아니다.

```bash
# release.sh --notarize 가 자동으로 부른다 (앱 공증·스테이플 뒤, appcast 생성 전).
# 손으로 부를 일은 스크립트 자체를 고칠 때뿐이다 — 앱이 스테이플되어 있어야 한다.
Codesign/notarize.sh App/.build/bundle/Polyglot.app
Scripts/make-dmg.sh App/.build/bundle/Polyglot.app --version 0.2.0 --notarize
```

`make-dmg.sh` 가 하는 일:

0. **앱에 티켓이 스테이플돼 있는지 먼저 확인하고, 아니면 거기서 멈춘다**
   (`xcrun stapler validate`). 이 검사가 없던 동안 스테이플 안 된 앱으로도 DMG 가
   조용히 만들어졌다(실측 2026-09-08) — 그렇게 나온 DMG 는 컨테이너만 티켓이 있고
   안의 앱은 없어서, `stapler validate` 는 통과하는데 앱을 Applications 로 옮겨
   **오프라인에서 처음 열 때만** 경고가 뜬다. 만든 사람은 온라인이라 못 본다.
1. `hdiutil create -format UDZO` 로 앱 하나와 `/Applications` 심볼릭 링크만 담은 압축
   읽기 전용 DMG 를 만든다. 배경 이미지·아이콘 배치는 범위 밖이다 — 이 항목의 완료
   기준은 "DMG 단독으로 `stapler validate` 통과" 이지 겉모습이 아니다.
2. `codesign --sign "<Developer ID>" --timestamp` 로 **DMG 컨테이너 자체를 서명**한다.
   신원은 `build-app.sh` 와 같은 방식으로 **이름으로** 고른다(목록 순서에 기대지 않는다).
   Developer ID 가 없으면 ad-hoc 으로 떨어지고, 그 DMG 는 공증 대상이 아니라고 표준
   출력에 남긴다.
3. `--notarize` 가 있으면 `Codesign/notarize.sh` 를 그 DMG 에 대해 그대로 부른다.
   `notarize.sh` 는 이제 `.app` 번들과 `.dmg` 파일을 둘 다 받는다 — 자격증명 경로·
   제출 전 검사·스테이플 로직은 공유하고, DMG 일 때만 압축을 건너뛰고(이미 단일
   파일이라 notarytool 이 직접 받는다) 검증 시 `spctl` 평가 타입을 바꾼다.

`release.sh` 는 앱을 공증·스테이플한 뒤(`--notarize` 가 있을 때) `ditto` 로 zip 을 묶고,
그 **직후에** `make-dmg.sh` 를 부른다 — 이미 스테이플된 앱을 그대로 DMG 에 담기 위해서다.
release 워크플로는 zip 과 DMG 를 **둘 다** GitHub Release 자산으로 올린다. DMG 는
gh-pages 에는 올라가지 않는다 — Sparkle 피드가 zip 만 가리키므로 DMG 를 그 이력에 반복해서
쌓을 이유가 없다.

DMG 는 `$OUTPUT`(appcast·zip 이 최종적으로 쌓이는 그 디렉터리)이 **아니라** 별도
스테이징 디렉터리(`.build/release-dmg-stage`)에 먼저 만들어지고, `generate_appcast` 가
다 돈 뒤에야 `$OUTPUT` 으로 옮겨진다. 실측(2026-09-08): `generate_appcast` 는 넘겨받은
디렉터리를 통째로 스캔해서 그 안의 zip·dmg 를 전부 "업데이트 아카이브" 로 취급하고
서명까지 시도한다 — DMG 를 appcast 를 굽기 전에 `$OUTPUT` 에 두면 같은 버전(0.2.0 등)의
zip 과 dmg 가 appcast 에 **항목 두 개**로 잡혀, Sparkle 피드가 어느 쪽을 배포판으로
써야 할지 불분명해진다. 순서를 지키면 DMG 는 appcast 생성 시점에 그 디렉터리에 아예
없으므로 이 문제 자체가 생기지 않는다.

**실제로 확인한 것(2026-09-08)**: 이미 Developer ID 로 서명된 앱 번들로 `make-dmg.sh` 를
돌려 DMG 를 만들고 서명한 뒤, `NOTARY_PROFILE=oculpm-notary Codesign/notarize.sh` 로 그
DMG 를 실제 제출해 공증 받고 스테이플까지 마쳤다. 그 뒤 `stapler validate` 가 **DMG
단독으로** "The validate action worked!" 를 냈고, `spctl --assess --type open
--context context:primary-signature` 가 `accepted / source=Notarized Developer ID` 를
반환했으며, DMG 를 마운트해도 스테이플이 살아 있었다 — 이 항목의 완료 기준을 실측으로
만족했다.

**랜딩 페이지(`App/Pages/index.html`)는 아직 DMG 를 가리키지 않는다** — zip 다운로드
링크만 있다. 이 파일은 이번 작업의 범위 밖(`App/Codesign/`·`App/Scripts/`·release
워크플로·이 문서만 건드리기로 했다)이라 손대지 않았다. DMG 링크를 추가하려면
`render-page.sh` 의 치환 로직(`@VERSION@` 등)과 같은 패턴으로 `Polyglot-@VERSION@.dmg`
자리를 하나 더 만들면 된다.

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
- **공증이 아직 한 번도 실행되지 않았다.** 스크립트·CI 배선과 제출 전 검사는 끝났고
  로컬에서 Developer ID 서명까지 확인했지만(Team ID 가 번들에 박히고 보안 타임스탬프가
  붙는 것), 실제 제출은 자격증명이 들어와야 한다. 위 표의 시크릿과 로컬
  `store-credentials` 가 그 조건이다. **이미 나간 v0.1.0-alpha.1 은 ad-hoc 그대로다** —
  공증본은 다음 태그부터다.
- **DMG 는 만들고 서명·공증·스테이플까지 실측했다** — {#dmg-notarize}. `Scripts/make-dmg.sh`
  가 조립·서명하고, `Codesign/notarize.sh` 가 이제 DMG 도 받는다. `release.sh --notarize`
  가 zip 뒤에 DMG 까지 자동으로 만들고, release 워크플로가 GitHub Release 자산으로
  둘 다 올린다(gh-pages 에는 zip 만). 위 `DMG — 사람이 내려받는 경로` 절({#dmg-notarize})
  참고. **아직 안 된 것**: `App/Pages/index.html` 랜딩 페이지가 DMG 다운로드 링크를
  가리키도록 바꾸는 일 — 범위 밖으로 남겨 뒀다.
- **키체인 승인**을 아직 아무도 누르지 않았다. 배포용 키로 appcast 를 처음 구울 때
  대화상자가 뜬다.
