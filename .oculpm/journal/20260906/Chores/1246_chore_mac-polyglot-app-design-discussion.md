---
schema_version: 1
type: chore
slug: "mac-polyglot-app-design-discussion"
status: done
difficulty: medium
created_at: "2026-09-06T12:46:33+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".oculpm/discussion/mac-polyglot-learning-app/discussion.md"
    op: create
related: []
tags:
  - "design"
  - "discussion"
  - "swift"
  - "macos"
  - "research"
  - "mcp-tool"
---
[x] macOS 다국어 학습 앱 설계 논의 문서 작성 (병렬 리서치 4갈래 종합)

10개 언어(Python·Rust·C++·Go·Java·Next.js·TypeScript·SQL·Swift·Assembly)를 개별 트랙으로 학습하는 macOS 네이티브 앱의 설계 논의 문서를 작성했다.

## 한 일

병렬 서브에이전트 4개로 리서치를 나눠 돌리고 결과를 종합했다.

1. 실행 런타임 — 언어별 컴파일/실행 전략, 샌드박스, WASM, 원격 실행
2. 에디터 UI 스택 — 코드 에디터 컴포넌트, tree-sitter, LSP, 마크다운 렌더링
3. 앱 아키텍처 — 모듈 구조, 영속화, 복습 알고리즘, 콘텐츠 팩 포맷, 배포
4. 커리큘럼 — 언어별 트랙 구성, OSS 자료 라이선스 판정, 레슨 데이터 모델

사용자가 확정한 전제 4가지(로컬 툴체인 실행 / Claude API 콘텐츠 생성 / MVP = Python+SQL+Swift / 오픈소스 공개)를 축으로, `CodeRunner` 프로토콜 + 백엔드 교체 방식(방안 C)을 권고안으로 정리했다.

## 리서치 간 충돌 해소

- 커리큘럼 갈래가 에디터로 Runestone(MIT)을 제안했으나, UI 갈래가 `Package.swift` 를 확인해 **iOS 전용**임을 밝혀 macOS 후보에서 제외했다.
- 실행 갈래는 Assembly 에 Unicorn Engine 을 권했으나 커리큘럼 갈래가 **GPL-2.0** 임을 확인. 오픈소스 공개라 치명적이진 않지만 앱 전체 라이선스를 강제하므로 미결 쟁점으로 분리했다.

## 로컬 실측으로 확인한 선행 조건

- macOS 26.6.2 / arm64 → Assembly 트랙은 ARM64(AAPCS64)가 정규, x86-64 는 Rosetta 만료(2027) 때문에 실행 의존 금지
- **Xcode 미설치**(CommandLineTools 만) → SwiftUI 앱 빌드 불가, 선행 작업 0번
- git 저장소 아님 → 오픈소스 공개 전 `git init` 필요
- MVP 3종(Python 3.13.12 / sqlite3 3.51.1 / swift 6.3.3)은 추가 설치 없이 전부 동작

## 검증

작성한 문서를 discussion-spec.md 규격과 대조해 확인했다 — YAML frontmatter 필드(`oculpm_discussion: v1`, id/title/status/created/updated/owner), `## 문제 정의` 최상단 배치, 후보안의 `{#opt-*}` 및 다음 단계의 `{#next-*}` id 가 모두 한 줄 끝에 위치, discussion-log managed block 경계 보존, 진척 추적 없음. 230줄.