---
schema_version: 1
type: feature
slug: "app-icon-from-app-palette"
status: done
difficulty: low
created_at: "2026-09-07T23:56:43+09:00"
session_id: "20260907-005"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "5779e665-d9d6-4ea1-9713-d9c51aedba59"
language: "ko"
verified_by_user: false
files_touched:
  - path: "App/Icon/make-icon.py"
    op: create
  - path: "App/Resources/Polyglot.icns"
    op: create
  - path: "App/Resources/Info.plist"
    op: update
  - path: ".gitignore"
    op: update
related: []
tags:
  - "icon"
  - "design"
  - "bundle"
  - "mcp-tool"
---
[x] 앱 아이콘 — 앱 팔레트에서 파생한 진도 트랙 세 줄

앱에 아이콘이 **아예 없었다** — `CFBundleIconFile` 키도 `.icns` 도 없어서 alpha.3 까지
기본 아이콘으로 배포됐다.

## 추가 기능

먹 바탕에 트랙 세 줄. 각 줄이 진도만큼 차 있고 맨 위 한 줄만 완료(통과 초록)다.
앱 대시보드가 실제로 보여주는 것(`7 / 24`, `12 / 22`, `1 / 24` — 서로 다른 진도로
나란히 가는 독립 트랙)을 그대로 도형으로 옮겼다.

**팔레트를 앱에서 실측해 가져왔다** — `design/*.dc.html` 에서 뽑으니 먹 `#141414`,
종이 `#F4F4F2`, 회색 계조, 의미색 둘(`#2F8F4E` 통과 · `#C8372D` 실패)이 전부였다.
앱이 의도적으로 준-모노크롬이라 아이콘도 색을 늘리지 않았다. 완료된 한 줄에만 초록을 쓴다.

**그림 파일이 아니라 스크립트로 둔 이유**: 색 하나 바꾸면 10개 크기를 다시 내보내야
하는데 손으로 하면 어느 하나가 뒤처진다. `App/Icon/make-icon.py` 가 상수에서 그려
`iconutil` 로 `.icns` 까지 만든다. 생성물도 커밋해 빌드가 Python·Pillow 에 의존하지 않는다.

`build-app.sh` 는 손대지 않았다 — 이미 `App/Resources/*` 를 통째로 복사하므로 거기
`.icns` 를 놓는 것으로 끝이다.

## 동작 흐름

4배로 그린 뒤 LANCZOS 로 줄여 안티에일리어싱을 얻는다 → 10개 크기 iconset →
`iconutil -c icns` → `App/Resources/Polyglot.icns`.

## 검증

- `build-app.sh --release` 후 번들에 `Contents/Resources/Polyglot.icns` (173,069 B),
  `CFBundleIconFile = Polyglot`, `codesign --verify --deep --strict` 통과
- 16·32·64·128·512 를 밝은 배경과 어두운 배경에 나란히 놓고 눈으로 확인

## 메모

**첫 시안은 토글 스위치로 읽혔다.** 레일 안에 양끝이 둥근 알약을 넣으면 그건 진도가
아니라 iOS 스위치의 형태 그 자체다. 채운 쪽 끝을 각지게 잘라(왼쪽만 둥글게) 고쳤다.

**어두운 Dock 에서 본체가 사라졌다.** 먹 바탕이 어두운 배경과 붙어 윤곽이 죽는다.
앱이 곳곳에 쓰는 헤어라인과 같은 회색(`#5F5F5C`)으로 실선을 둘러 해결했다 —
팔레트를 늘리지 않고.

둘 다 렌더해서 눈으로 보지 않았으면 그대로 나갔을 것들이다.