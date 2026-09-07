---
schema_version: 1
type: feature
slug: "first-notarization-accepted"
status: done
difficulty: medium
created_at: "2026-09-07T22:32:34+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Codesign/notarize.sh"
    op: update
  - path: ".github/workflows/release.yml"
    op: update
  - path: "docs/release.md"
    op: update
related:
  - ref: "20260907/Features_to_add/2134_feature_developer-id-signing-notarize-wiring.md"
    kind: "followup"
tags:
  - "notarization"
  - "codesign"
  - "gatekeeper"
  - "release"
  - "ci"
  - "mcp-tool"
---
[x] 첫 공증 통과 — spctl 이 Notarized Developer ID 로 바뀌었다

배선만 되어 있던 공증을 실제로 한 번 돌려 통과시켰다. `{#notarize-staple-dmg}` 의 판정
기준인 `spctl` 이 `Unnotarized Developer ID` 에서 `Notarized Developer ID` 로 넘어갔다.

## 추가 기능

**자격증명 경로가 셋이 됐다.** 사용자가 App Store Connect API 키가 아니라 **Apple ID +
앱 전용 암호**를 골랐다. 그것도 notarytool 의 정식 경로이고 헤드리스에서 잘 돈다 —
러너에서 막히는 것은 키체인 **프로파일** 경로뿐이다(errSecUserCanceled(-128)). 자격증명을
인자로 직접 주는 경로는 키체인을 아예 타지 않는다. 그래서 `notarize.sh` 는 이제
Apple ID/암호 → API 키 → 키체인 프로파일 순으로 먼저 발견한 것을 쓴다.

`--password` 가 인자로 들어가 같은 머신의 `ps` 에 잠깐 보인다. 러너는 잡 전용으로 떴다
사라지므로 감수하고, 로컬은 기본값을 키체인 프로파일로 둬서 이 경로를 타지 않게 했다.

**저장소 시크릿 이름을 사용자가 쓴 관례에 맞췄다** — `APPLE_CERTIFICATE` ·
`APPLE_CERTIFICATE_PASSWORD` · `APPLE_ID` · `APPLE_PASSWORD` · `APPLE_TEAM_ID`.
`APPLE_SIGNING_IDENTITY` 는 쓰지 않는다: `build-app.sh` 가 키체인에서
`Developer ID Application` 을 이름으로 직접 고르므로 문자열을 시크릿에 박으면 인증서
갱신 때 같이 틀어진다.

로컬 키체인 프로파일 이름은 `oculpm-notary` 다. 스크립트 기본값을 그것으로 바꿨고
`NOTARY_PROFILE` 로 덮을 수 있다.

## 동작 흐름

```
notarize.sh App/.build/bundle/Polyglot.app
  → 제출 전 검사 3종 통과
  → ditto 제출용 zip → notarytool submit --wait → Accepted (약 4분)
  → stapler staple → stapler validate → spctl → codesign --verify
```

## 검증

- `spctl --assess --type execute -vv` → **accepted · source=Notarized Developer ID ·
  origin=Developer ID Application: Hyunbin Kim (BP57Z7L498)**
- `xcrun stapler validate` → The validate action worked!
- `codesign --verify --deep --strict` 통과 — 스테이플이 봉인을 건드리지 않는다는 것을 실측 확인
- submission 2d139486-78a3-4376-9bac-8e93d919c9e4, status Accepted

## 메모

**돌고 있는 셸 스크립트를 편집하면 안 된다.** 공증이 도는 중에 같은 파일의
`NOTARY_PROFILE` 기본값을 고쳤더니 `line 148: -e: command not found` 가 났다. bash 는
스크립트를 실행하며 조금씩 읽는데, 파일이 4바이트 짧아지자 읽기 오프셋이 밀려 `set -e`
중간부터 읽어 `-e` 를 명령으로 봤다. 스크립트 결함이 아니다 — 편집 시점의 문제다.

사용자 쪽에서 걸린 함정 둘도 기록해 둔다(둘 다 `docs/release.md` 에 반영):

1. **키체인의 "개인 키" 행을 내보내면 키만 담긴 `.p12`** 가 나온다. `security import` 는
   성공하는데 `find-identity` 에 신원이 안 잡혀 빌드가 조용히 ad-hoc 으로 떨어진다.
   판정은 `pkcs7-encryptedData` 컨테이너의 유무로 한다 — `certBag` OID 검색은 통하지
   않는다(인증서가 암호화 영역 안이라 평문에 안 보인다). 처음에 그 검사로 정상 파일까지
   "인증서 없음" 으로 잘못 읽을 뻔했다.
2. **빈 시크릿이 성공으로 보인다.** 경로에 공백이 있는데 따옴표를 빼면 `base64` 가 실패해
   빈 표준 출력을 흘리고, `gh secret set` 은 그것을 받아 "✓ Set" 을 찍는다.

남은 것: DMG(`{#dmg-notarize}`)는 손대지 않았다. 태그 푸시로 CI 경로를 아직 증명하지
않았고, 서명·공증 변경이 아직 커밋되지 않았다.