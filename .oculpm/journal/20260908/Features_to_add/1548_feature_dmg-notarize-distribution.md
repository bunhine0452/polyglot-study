---
schema_version: 1
type: feature
slug: "dmg-notarize-distribution"
status: done
difficulty: medium
created_at: "2026-09-08T15:48:29+09:00"
session_id: "20260908-004"
agent:
  id: "claude-code"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Scripts/make-dmg.sh"
    op: create
  - path: "App/Codesign/notarize.sh"
    op: update
  - path: "App/Scripts/release.sh"
    op: update
  - path: ".github/workflows/release.yml"
    op: update
  - path: "docs/release.md"
    op: update
related: []
tags:
  - "dmg"
  - "notarization"
  - "codesign"
  - "release"
  - "sparkle"
  - "mcp-tool"
---
[x] DMG 배포 경로 추가 — 조립·서명·공증·스테이플, GitHub Release 자산으로 배선

## 추가 기능

`{#dmg-notarize}` — zip(Sparkle 자동 업데이트용)과 별개로 사람이 내려받는 DMG 경로를 추가했다.

- `App/Scripts/make-dmg.sh` (신규): `hdiutil create -format UDZO` 로 앱 하나와 `/Applications`
  심볼릭 링크만 담은 DMG 를 조립하고, `codesign --sign "<Developer ID>" --timestamp` 로
  DMG 컨테이너 자체를 서명한다. 신원 선택은 `build-app.sh` 와 동일하게 이름으로 고른다.
  `--notarize` 를 주면 서명 직후 `notarize.sh` 를 그 DMG 에 대해 그대로 부른다.
- `App/Codesign/notarize.sh` 를 일반화했다 — `.app` 번들과 `.dmg` 파일을 둘 다 받는다.
  자격증명 경로·제출 전 검사·스테이플 로직은 공유하고, DMG 일 때만 (a) 압축을 건너뛰고
  (이미 단일 파일이라 notarytool 이 직접 받는다) (b) `spctl` 평가 타입을
  `--type open --context context:primary-signature` 로 바꾸고 `codesign --verify` 에서
  `--deep` 을 뺀다(DMG 는 번들이 아니라 중첩 코드가 없다).
- `App/Scripts/release.sh` 에 "2.5 DMG" · "5. DMG 를 산출물 디렉터리로" 두 단계를 추가했다.
  DMG 는 **별도 스테이징 디렉터리**(`.build/release-dmg-stage`)에 먼저 만들고,
  `generate_appcast` 가 다 돈 **뒤에** `$OUTPUT` 으로 옮긴다 — 아래 실측 참고.
- `.github/workflows/release.yml`: "산출물 확인" 단계에서 DMG 도 zip 과 같은 수준으로
  검증(`stapler validate` · `codesign --verify --strict` · `spctl --type open`)하고,
  gh-pages 커밋 대상에서 뺀 뒤 `$RUNNER_TEMP/dist` 로 옮긴다. "GitHub Release" 단계가
  zip 과 DMG 를 **둘 다** 자산으로 올린다. 새 시크릿은 필요 없다 — 기존 Developer ID
  인증서·notarytool 자격증명을 그대로 재사용한다.
- `docs/release.md` 에 `## DMG — 사람이 내려받는 경로 {#dmg-notarize}` 절을 추가하고
  "순서가 전부다" 다이어그램·"릴리스 한 번이 하는 일" 번호 목록·"검증" 절을 갱신했다.

## 동작 흐름

```
build-app.sh(서명) → notarize.sh(공증·스테이플, 앱) → ditto zip
                                  └→ make-dmg.sh(조립·서명, 스테이징 디렉터리)
                                       └→ notarize.sh(공증·스테이플, DMG)
→ generate_appcast(스테이징에 DMG 가 없는 상태로 스캔) → DMG 를 $OUTPUT 으로 이동
```

## 실측으로 잡은 함정

1. **BSD sed 의 `\|` 는 GNU 확장이다.** `make-dmg.sh` 초안에서
   `sed -n 's/^\(TeamIdentifier\|Timestamp\)=.*/  &/p'` 를 썼더니 macOS 기본 sed 에서
   아무 줄도 안 뽑히고 조용히 넘어갔다(에러 없음). `-E` 를 붙여 확장 정규식으로 바꿔 고쳤다.
2. **`generate_appcast` 는 넘겨받은 디렉터리를 통째로 스캔해서 그 안의 zip·dmg 를 전부
   "업데이트 아카이브" 로 취급하고 서명까지 시도한다** (`--help` 예시에 zip+dmg 혼재
   디렉터리가 나오고, 실제로 무관한 버전 문자열을 가진 임시 dmg 하나만 놓고 돌려봐도
   서명을 시도하다 키 없음으로 실패하는 것으로 확인). DMG 를 appcast 생성 시점에
   `$OUTPUT` 에 두면 같은 버전이 appcast 항목 두 개로 잡힌다 — 그래서 DMG 를 별도
   스테이징 디렉터리에서 만들고 appcast 생성 후에 옮기도록 순서를 바꿨다.

## 검증

- `make-dmg.sh` 로 이미 Developer ID 서명된 기존 앱 번들(`App/.build/bundle/Polyglot.app`)에서
  DMG 를 조립·서명 — 실제로 돌려 `TeamIdentifier=BP57Z7L498` · `Timestamp=` 있는 서명을 확인.
- `NOTARY_PROFILE=oculpm-notary Codesign/notarize.sh <dmg>` 로 **실제 공증 제출** —
  `status: Accepted`, `The staple and validate action worked!`, 이후
  `xcrun stapler validate` 가 **DMG 단독으로** "The validate action worked!" 를 냈고
  `spctl --assess --type open --context context:primary-signature` 가
  `accepted / source=Notarized Developer ID` 를 반환 — 이 항목의 완료 기준
  ("DMG 파일 단독으로 stapler validate 통과") 을 실측으로 만족.
- `hdiutil attach` 로 마운트해 `Polyglot.app` + `Applications` 심볼릭 링크 레이아웃과
  스테이플 생존을 확인, `hdiutil detach` 로 정리.
- `release.sh` 자체는 빌드 격리(공유 `.build` 동시 사용 시 SIGSEGV 위험, 이 워킹트리에서
  다른 세션이 `App/.build` 를 사용 중인 정황을 실측으로 확인)를 지키기 위해
  `build-app.sh`(swift build 호출)를 다시 돌리지 않았다 — 즉 `release.sh` 전체 파이프라인은
  end-to-end 로 실행하지 않았다. `bash -n` 구문 검사와 코드 리뷰로 배선을 확인했고,
  핵심 신규 로직(DMG 조립·서명·공증·스테이플, appcast 스캔 순서 문제)은 위와 같이
  개별적으로 실제 실행해 검증했다.
- `.github/workflows/release.yml` 은 `python3 -c "import yaml..."` 로 문법만 확인했다 —
  실제 워크플로 실행(태그 푸시)은 하지 않았다.