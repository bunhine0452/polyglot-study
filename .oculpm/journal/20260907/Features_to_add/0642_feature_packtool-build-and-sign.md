---
schema_version: 1
type: feature
slug: "packtool-build-and-sign"
status: done
difficulty: high
created_at: "2026-09-07T06:42:19+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/PackBuild/TarWriter.swift"
    op: create
  - path: "Tools/Sources/PackBuild/DistributionBuilder.swift"
    op: create
  - path: "Tools/Sources/PackBuild/SigningEnvironment.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackSignature.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackSigning.swift"
    op: create
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackManifest.swift"
    op: update
  - path: "Packages/LearnKit/Sources/ContentKit/Manifest/PackLayout.swift"
    op: update
  - path: "Tools/Sources/packtool/BuildCommand.swift"
    op: create
  - path: "Tools/Sources/packtool/SignCommand.swift"
    op: create
  - path: "Tools/Sources/PackValidate/SyntaxStage.swift"
    op: update
  - path: "Tools/Sources/PackValidate/PackValidator.swift"
    op: update
  - path: "Tools/Tests/PackBuildTests"
    op: create
  - path: "Tools/Tests/PackValidateTests/DistributionPackTests.swift"
    op: create
  - path: "docs/pack-format.md"
    op: update
related:
  - ref: "20260907/Features_to_add/0615_feature_packtool-validation-gate.md"
    kind: "followup"
tags:
  - "packtool"
  - "content-pack"
  - "reproducible-build"
  - "signing"
  - "cryptokit"
  - "tar"
  - "mcp-tool"
---
[x] 배포 팩 굽기와 서명 — 결정적 tar 와 분리 Ed25519 서명

## 추가 기능

`packtool` 에 서브커맨드 넷이 붙어 파이프라인이 끝까지 이어졌다 — `validate` → `build` → `sign` → `verify` (+ `keygen`).

- **build** — solutions 를 벗기고 sha256 을 다시 세어 tar 하나로 굽는다. 굽기 전에 구조·문법·의미 세 단계를 스스로 돌리고 하나라도 실패하면 굽지 않는다.
- **sign / verify** — 정규 매니페스트 바이트에 대한 분리 Ed25519 서명(`manifest.json.sig`).
- **keygen** — 개인키는 0600 파일로만, stdout 에는 공개키만.

## 동작 흐름

**tar 를 직접 썼다.** `/usr/bin/tar` 는 결정적이지 않다 — mtime·uid·gid·uname·gname 을 파일 시스템에서 읽어 헤더에 싣기 때문에 같은 팩을 두 머신에서 구우면 다른 바이트가 나온다. 그 필드를 우리가 정해야 하는 이상 헤더를 직접 쓰는 것과 같은 일이라, 512바이트 블록 두 종류인 ustar 를 그냥 구현했다. mtime 은 `manifest.generatedAt`(빌드 시각이 아니다), 소유자는 0, 순서는 경로 사전순, 최상위는 `<packID>-<version>/` 하나. gzip 을 걸지 않는 것도 같은 이유다 — gzip 헤더에 압축 시각이 들어간다.

**배포 팩이 자기 자신을 검증할 수 있어야 한다.** solutions 를 벗기면 레슨의 `@Task(solution:)` 이 없는 파일을 가리키게 되고 검증기의 참조 검사가 배포 팩을 통째로 거부한다. 매니페스트에 `distribution: true` 를 두어 갈랐다 — **명령행 플래그가 아니라 매니페스트인 이유는 서명**이다. 서명이 정규 매니페스트 바이트에 걸리므로 "solutions 가 없는 것이 정상" 이라는 사실도 함께 서명된다. 플래그였다면 검증기를 부르는 쪽이 게이트를 끌 수 있었다. optional 필드라 소스 팩의 정규 바이트는 한 글자도 바뀌지 않는다(nil 은 인코딩되지 않는다).

그리고 검사를 **끄지 않고 뒤집었다** — 배포 팩에서 벗겨진 경로는 files 에도 디스크에도 없어야 하고, 남아 있으면 그게 실패다. 실행 게이트는 아예 돌리지 않고 `stagesRun` 에서 execution 을 뺀다. 그래서 순서가 validate → build 이지 그 반대가 될 수 없다.

**서명 하나로는 부족하다.** 대상이 `manifest.json` 한 파일이라, 레슨 본문을 바꿔도 매니페스트는 그대로여서 서명이 그대로 통과한다(테스트로 실증). `verify` 는 서명과 `files[].sha256` 대조를 **둘 다** 본다 — 서명이 보증하는 것은 해시표이고, 내용물은 그 표와 대조해야 한다.

## 틀렸던 것 — Ed25519 가 결정적일 거라고 적었다

"서명이 붙어도 재현성은 그대로"라고 주석·문서·테스트 이름에 썼는데 테스트가 잡았다. **Apple 의 CryptoKit 은 Ed25519 논스에 난수를 섞는다** — 같은 키로 같은 바이트에 두 번 서명하면 서로 다른 64바이트가 나오고 둘 다 유효하다(별도 프로그램으로 실측 확인). RFC 8032 의 순수 Ed25519 를 기대한 것이 틀렸다.

재현성 계약을 "서명 파일을 뺀 트리 전부"로 좁히고 그 경계를 테스트로 고정했다 — 두 빌드의 모든 파일이 바이트 동일하고, 서명 파일만 다르고, 둘 다 유효하다.

## 검증

Tools 267 → 300 테스트, LearnKit 912 무변, 빌드 경고 0.

리포의 샘플 팩으로 실측 — 두 번 구운 tar 의 sha256 동일, `tar tf` 에 solutions 0건, `/usr/bin/tar` 로 푼 것이 그대로 `ContentPack` 으로 열리고 해시 전부 일치. sign → verify 통과, 레슨 본문 한 줄 추가 → 거부(1), 다른 공개키 → 거부(1), 서명 없는 팩 → 거부(1), 배포 팩 재굽기 → 거부(2).

## 메모

`PackSourceScan` 이 `manifest.json.sig` 를 건너뛰므로 **설치된 팩에는 서명이 따라가지 않는다.** 설치 시점 서명 검증은 `{#pack-installer}` 의 몫이라 그때 잇는다.