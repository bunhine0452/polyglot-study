---
schema_version: 1
type: bug
slug: "pack-version-not-bumped-stale-packs"
status: done
difficulty: medium
created_at: "2026-09-07T20:29:36+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "ba0d427a-9898-445d-86dd-7a33d01b4b02"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Content/packs/polyglot-python/manifest.json"
    op: correct
  - path: "Content/packs/polyglot-sql/manifest.json"
    op: correct
  - path: "Content/packs/polyglot-swift/manifest.json"
    op: correct
  - path: "Packages/LearnKit/Tests/ContentKitTests/PackLibraryTests.swift"
    op: update
related:
  - ref: "20260907/Features_to_add/1914_feature_fill-mvp-tracks-to-catalog-totals.md"
    kind: "followup"
tags:
  - "content"
  - "release"
  - "packstore"
  - "regression"
  - "mcp-tool"
---
[x] 팩 버전을 안 올려 앱이 옛 12편을 계속 읽었다 — 릴리스 직전에 잡았다

알파 릴리스를 구우려고 조립한 `.app` 을 띄웠더니 대시보드가 `0 / 24` 가 아니라
**`0 / 12`** 를 그렸다. 앱 조립·서명 검증·zip·appcast 서명까지 전부 통과한 뒤였다.

## 발생 원인

70편으로 늘린 팩이 매니페스트의 `version` 을 `0.1.0` 그대로 들고 있었다.
`PackLibrary.provision` 은 **같은 버전이면 다시 설치하지 않는다**:

```swift
if store.installedVersions(packID).contains(manifest.version) {
    if store.currentVersion(packID) != manifest.version { … }   // 포인터만 세운다
} else {
    try installer.install(from: seed, …)                         // 여기로 안 온다
}
```

버전 디렉터리를 불변으로 보기 때문이고 그 자체는 옳은 설계다 — 앱을 열 때마다 수십 MB 를
다시 쓰지 않는다. 문제는 콘텐츠를 바꾸면서 버전을 안 올린 쪽이다. 이미 `0.1.0` 을 설치해 둔
스토어는 새 씨앗을 건너뛰고 `current` 가 옛 12편을 계속 가리켰다.

이건 내 누락이다. 70편 확장 작업 중에 "콘텐츠가 12→24 로 늘었으니 0.2.0 으로 올리는 게
맞다" 고 판단해 놓고 "나중에 정하자" 로 미룬 뒤 돌아가지 않았다.

## 왜 게이트가 못 잡았나

- `packtool validate` 는 **소스 트리**(`Content/packs/<id>/`)를 연다.
- `PackLibraryTests` 의 리포 팩 테스트도 같은 소스 트리를 직접 연다.
- 둘 다 설치 경로(`provision` → `PackStore` → `current`)를 지나지 않는다.

그래서 PR #3 의 CI 5게이트가 전부 초록이었다. **조립된 앱을 띄워야만 보이는 자리다.**

`PackLibraryTests` 에는 "같은 버전은 다시 설치하지 않는다" 는 있었지만 그 **짝**인
"버전이 오르면 설치한다" 가 없었다.

## 해결 방법

세 매니페스트의 `version` 을 `0.2.0` 으로 올렸다(diff 는 그 세 줄뿐).

회귀 가드로 `provisionInstallsNewerSeedVersion` 을 넣었다 — 2편짜리 1.0.0 을 설치한 뒤 같은
자리에 5편짜리 1.1.0 씨앗을 놓고 다시 provision 하면 `installedVersions` 에 둘 다 남고
`current` 가 1.1.0 으로 옮겨지며 열린 팩이 5편이어야 한다.

**다만 정직하게 적자면** 이 테스트가 고정하는 것은 업그레이드 *기제*이고, 이번 결함(내용은
바뀌었는데 버전을 안 올림)을 잡은 것은 조립된 앱을 띄운 것이다. 콘텐츠 변경과 버전 증가의
동기화는 코드로 강제되지 않으므로 **릴리스 전 실행 확인이 대체 불가능한 게이트**다.

## 검증

`0.1.0` 이 설치된 상태에서 새 번들을 띄웠다 — 실제 사용자의 업그레이드 경로 그대로다.

```
polyglot-python: 0.1.0 0.2.0 current | current=0.2.0
polyglot-sql:    0.1.0 0.2.0 current | current=0.2.0
polyglot-swift:  0.1.0 0.2.0 current | current=0.2.0
```

대시보드가 `0/24 · 0/22 · 0/24` 로 바뀌고 진도 칸 수도 그만큼 늘었다. 트랙 화면에서 Python
24편이 전부 나열되는 것도 스냅샷으로 확인했다. `packtool validate` 세 팩 실패 0,
`ContentKitTests` 137개 통과, CI 5게이트 통과(PR #6).

## 메모

**`generate_appcast` 는 포그라운드에서 돌려야 한다.** 분리된 백그라운드 프로세스에서는
키체인 승인 대화상자(`SecurityAgent`)를 띄우지 못해 `errSecUserCanceled(-128)` 로 실패하는데,
Sparkle 은 그것을 `Private key ... not found in the Keychain` 으로 찍는다 — 키는 멀쩡히 있다.
HANDOFF 에 적힌 함정("첫 appcast 생성 때 대화상자가 뜬다")의 변종이고, 이번에는 **매 릴리스마다**
뜬다(키체인 ACL 에서 "항상 허용" 을 누르기 전까지).