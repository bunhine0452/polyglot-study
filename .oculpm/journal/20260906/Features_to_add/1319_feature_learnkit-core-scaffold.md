---
schema_version: 1
type: feature
slug: "learnkit-core-scaffold"
status: done
difficulty: medium
created_at: "2026-09-06T13:19:10+09:00"
session_id: "20260906-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Packages/LearnKit/Package.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Identifiers.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/Diagnostic.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LearnCore/GradeResult.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LanguageKit/CodeRunner.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LanguageKit/LanguageModule.swift"
    op: create
  - path: "Packages/LearnKit/Sources/LanguageKit/LanguageRegistry.swift"
    op: create
  - path: "Packages/LearnKit/Tests/LearnCoreTests/GradeResultTests.swift"
    op: create
related:
  - ref: "20260906/Chores/1246_chore_mac-polyglot-app-design-discussion.md"
    kind: "followup"
tags:
  - "swift"
  - "spm"
  - "architecture"
  - "scaffold"
  - "mcp-tool"
---
[x] LearnKit 코어 골격 — LearnCore·LanguageKit 타깃과 CodeRunner 계약 수립

Xcode 26.6 설치로 선행 조건이 풀려, 설계 논의에서 정한 순서대로 가장 되돌리기 비싼 계층인 코어 골격부터 세웠다.

## 추가 기능

로컬 SPM 패키지 `Packages/LearnKit` 에 타깃 두 개를 만들었다.

- **LearnCore** (의존성 0) — `LanguageID`/`PackID`/`LessonID`/`CardID` 식별자, 언어 중립 `Diagnostic`, 그리고 채점 결과 `GradeResult`
- **LanguageKit** (LearnCore 만 의존) — `CodeRunner` 프로토콜과 그 주변 타입(`RunRequest`/`RunEvent`/`ResourceLimits`/`RunnerCapabilities`), `LanguageModule`, `LanguageRegistry`

`swift-tools-version: 6.2`, platforms `.macOS(.v14)`. 코어 타깃에는 upcoming feature `InternalImportsByDefault` 와 `MemberImportVisibility` 를 켜 전이 의존성 누출을 막았다 — 그래서 LanguageKit 의 소스는 `public import LearnCore` 를 명시한다.

## 동작 흐름

`GradeResult` 가 언어 어댑터가 넘는 마지막 경계다. SQL 은 결과셋 비교, Python 은 pytest 출력 파싱, Swift 는 Swift Testing 실행 — 하는 일은 전부 다르지만 결과는 이 타입 하나로 모인다. 이질성은 `GradeResult.Presenter`(console / table / browser / registers)에만 가둔다.

`ModuleAvailability` 에 `.stub` 케이스를 따로 뒀다. 이번 조사에서 실측한 함정 때문인데, `/usr/bin/java` 는 파일로 존재하지만 실행하면 `Unable to locate a Java Runtime` 을 낸다. `command -v` 판정은 오탐하므로 감지는 `--version` 을 실제 실행해 종료코드까지 봐야 하고, 그 결과를 UI 가 구분해 보여줄 수 있어야 한다.

`ResourceLimits` 에는 macOS 제약을 주석으로 못박았다 — `RLIMIT_AS`/`RLIMIT_DATA` 가 EINVAL 로 거부되므로 메모리 상한만은 rlimit 이 아니라 `proc_pid_rusage()` 폴링으로 강제해야 한다.

## 검증

`swift build` 성공(2.98s), `swift test` 로 Swift Testing 스위트 2건 통과 — 실패 테스트 필터링과 warning/error 구분. 타깃 플랫폼 arm64e-apple-macos14.0 확인.

## 메모

`git init` 으로 저장소를 초기화했다(브랜치 main). 커밋은 아직 하지 않았다 — 라이선스 선택이 미결이라 LICENSE 파일이 없다.