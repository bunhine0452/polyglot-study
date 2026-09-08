---
schema_version: 1
type: refactor
slug: "dmg-built-on-ci-only"
status: done
difficulty: low
created_at: "2026-09-08T15:55:52+09:00"
session_id: "20260908-004"
agent:
  id: "claude-code"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Scripts/make-dmg.sh"
    op: update
  - path: "App/Scripts/release.sh"
    op: update
  - path: "docs/release.md"
    op: update
related:
  - ref: "20260908/Features_to_add/1548_feature_dmg-notarize-distribution.md"
    kind: "followup"
tags:
  - "release"
  - "dmg"
  - "notarize"
  - "ci"
  - "mcp-tool"
---
[x] DMG 는 CI 에서만 만든다 — 스테이플 가정을 가드로 바꿨다

## 동기

DMG 를 로컬에서 만들지 말고 GitHub 에서 만들라는 요구. 그리고 그 직전에 드러난 구멍
하나 — `make-dmg.sh` 헤더가 "이미 공증·스테이플된 앱을 받는다고 가정한다" 고 적어 놓고
**강제하지 않았다.** 실측(2026-09-08): 스테이플 안 된 번들
(`Polyglot.app does not have a ticket stapled to it`)을 그대로 넘겨도 DMG 가 조용히
만들어졌다.

그렇게 나온 DMG 가 특히 나쁜 이유는 **겉으로는 멀쩡해 보인다**는 것이다. 컨테이너에는
티켓이 있으니 `stapler validate <dmg>` 는 통과한다. 안의 앱만 티켓이 없어서, 그 앱을
응용 프로그램 폴더로 옮겨 **오프라인에서 처음 열 때만** 경고가 뜬다. 만든 사람은
온라인이라 끝까지 못 본다.

## 변경 요약

두 축으로 갈랐다 — 만들 수 있는 조건과, 만드는 장소.

1. `make-dmg.sh`: 스테이징 전에 `xcrun stapler validate "$APP_BUNDLE"` 로 막는다.
   실패하면 stapler 출력을 그대로 들여쓰고 `notarize.sh` 를 먼저 부르라는 한 줄을
   덧붙인 뒤 exit 1 — 출력 디렉터리도 만들지 않는다. 예외 플래그는 두지 않았다.
   배포물이 아닌 DMG 를 만들 이유가 없고, 로컬에서 앱만 확인할 거면 `build-app.sh` 의
   번들을 그대로 열면 된다.

2. `release.sh`: DMG 단계(2.5 조립 · 5 산출물로 이동)를 `--notarize` 안으로 넣었다.
   `DMG_STAGE` 가 빈 문자열이면 5 단계와 마지막 안내문이 통째로 빠진다. 이유는 1번의
   따름정리다 — DMG 는 스테이플된 앱을 요구하고, 스테이플은 공증을 거쳐야 나오므로
   `--notarize` 없이 만들 수 있는 DMG 는 애초에 없다. 조건을 두 군데에 따로 적는 대신
   이미 있던 플래그에 얹었다.

결과적으로 DMG 가 나오는 경로는 태그를 밀었을 때 도는 release 워크플로 하나뿐이다
(`release.sh ... --notarize`). `verify-sparkle.sh` 같은 로컬 검증은 hdiutil 왕복도,
애플 서버 왕복도 타지 않는다.

3. `docs/release.md`: 5번 단계 서술을 조건부로 고치고, {#dmg-notarize} 절 머리에
   "DMG 는 이 기계가 아니라 GitHub 에서 만든다" 를 박았다. `make-dmg.sh` 가 하는 일
   목록에 0번(스테이플 확인)을 추가하고, 왜 이 검사가 없으면 오프라인 첫 실행에서만
   깨지는지를 같이 적었다.

## 검증

- 스테이플 안 된 `App/.build/bundle/Polyglot.app` 으로 `make-dmg.sh` 실행 → exit 1,
  stapler 출력이 그대로 찍히고 출력 디렉터리조차 생기지 않음(가드가 mkdir 앞에 있다).
- `bash -n` 통과: `release.sh` · `make-dmg.sh` · `notarize.sh`.
- `.github/workflows/release.yml` YAML 파싱 통과. 워크플로는 `--notarize` 로 부르므로
  DMG 는 그대로 나오고, 산출물 확인 단계의 `test -f site/...dmg` 도 유효하다.