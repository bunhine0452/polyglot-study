---
schema_version: 1
type: feature
slug: "notarized-release-alpha3-shipped"
status: done
difficulty: medium
created_at: "2026-09-07T23:19:14+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/release.yml"
    op: update
related:
  - ref: "20260907/Features_to_add/2232_feature_first-notarization-accepted.md"
    kind: "followup"
tags:
  - "release"
  - "notarization"
  - "ci"
  - "gatekeeper"
  - "sparkle"
  - "mcp-tool"
---
[x] 공증된 첫 릴리스 v0.1.0-alpha.3 배포 — 받아서 그냥 열린다

PR #10 을 머지하고 태그를 밀어 CI 가 서명·공증·배포까지 혼자 도는 것을 실측했다.
`{#release-ci}` 의 마지막 한 걸음이었다.

## 추가 기능

배포 경로가 사람 손 없이 닫혔다. 태그를 밀면 러너가 인증서를 임시 키체인에 임포트하고,
Developer ID 로 서명하고, 공증에 제출해 스테이플하고, zip 을 만들어 appcast 를 갱신하고,
gh-pages 와 GitHub Release 로 내보낸다. 잡 시간 **9분 9초**(공증 심사 약 25초).

**v0.1.0-alpha.2 는 공증본이 아니다.** 12:13 에 이미 나갔는데 공증 작업 이전 커밋
(`5a5be23`)을 가리켜 옛 워크플로로 구워졌다. 그래서 alpha.3 으로 갔다. alpha.2 사용자는
appcast 를 통해 alpha.3 으로 올라오면서 공증본을 받는다.

## 동작 흐름

```
git tag v0.1.0-alpha.3 47ab9c1 && git push origin v0.1.0-alpha.3
  → 임시 키체인에 .p12 임포트 → find-identity 가드
  → build-app.sh (Developer ID + --timestamp)
  → notarize.sh (submit --wait → Accepted → staple)
  → ditto zip → generate_appcast → render-page
  → 산출물 확인: 배포될 zip 을 풀어 재검증
  → gh-pages 발행 → GitHub Release
```

## 검증

**CI 안에서** — submission ccf10e40-ee58-4aaa-a32e-442cc70d6807 Accepted,
`산출물 확인` 단계가 배포될 zip 을 풀어 `stapler validate` · `spctl` · `codesign --verify`
전부 통과 (`accepted · source=Notarized Developer ID`).

**밖에서 다시** — CI 를 믿지 않고 GitHub Release 자산(19,687,029 B)을 직접 받아
`com.apple.quarantine` 를 붙인 뒤(실제 다운로드와 같은 경로) 풀어서 확인했다:

- 격리 속성이 앱에 붙은 상태 — `0283;00000000;;9F2A`
- `xcrun stapler validate` → The validate action worked!
- `spctl --assess --type execute -vv` → **accepted · source=Notarized Developer ID ·
  origin=Developer ID Application: Hyunbin Kim (BP57Z7L498)**
- `codesign --verify --deep --strict` 통과, `CFBundleShortVersionString` = 0.1.0-alpha.3
- appcast 에 EdDSA 서명 존재, 랜딩 페이지가 새 "설치" 문구로 갱신됨

## 메모

**첫 시도는 인증서 임포트에서 죽었다** — `SecKeychainItemImport: MAC verification failed
during PKCS12 import (wrong password?)`. `APPLE_CERTIFICATE_PASSWORD` 가 `.p12` 의
내보내기 암호와 달랐다. 이름이 비슷한 시크릿이 둘이라(`APPLE_CERTIFICATE_PASSWORD` =
.p12 암호, `APPLE_PASSWORD` = 앱 전용 암호) 뒤바뀌기 쉽다. 인증서를 다시 내보내
암호를 새로 넣고 **같은 런을 재실행**해 풀었다 — 커밋도 태그도 그대로고 시크릿만
바뀌므로 태그를 다시 밀 필요가 없다.

이 실패가 좋았던 점: 워크플로가 **굽기 전에** 죽어서 gh-pages 도 Release 도 건드리지
않았다. 부분 발행된 상태가 남지 않는다.

남은 것: DMG(`{#dmg-notarize}`) — 배포와 Sparkle 둘 다 zip 이라 별개 항목이다.