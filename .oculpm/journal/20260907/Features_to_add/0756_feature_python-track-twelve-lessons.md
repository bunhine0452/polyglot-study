---
schema_version: 1
type: feature
slug: "python-track-twelve-lessons"
status: done
difficulty: medium
created_at: "2026-09-07T07:56:23+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Content/packs/polyglot-python"
    op: create
  - path: "tracks/python.outline.json"
    op: create
related:
  - ref: "20260907/Features_to_add/0616_feature_lessongen-lesson-and-repair-loop.md"
    kind: "followup"
  - ref: "20260907/Errors/0752_error_prompt-cache-verdict-corrected.md"
    kind: "followup"
tags:
  - "content"
  - "lessongen"
  - "packtool"
  - "python-track"
  - "mcp-tool"
---
[x] 파이썬 트랙 12레슨 — 생성·검증·수리 루프를 실제 규모로 처음 돌렸다

## 추가 기능

레슨 3편짜리 샘플 팩만 있던 저장소에 처음으로 **트랙 하나**가 들어왔다. `print` 한 줄에서 시작해 변수·문자열·조건·반복·리스트·함수·딕셔너리를 거쳐 예외 처리와 파일 입출력까지 12편이고, 선수 관계가 완전한 DAG 를 이룬다.

## 동작 흐름

**별도 팩으로 갈랐다.** 생성기는 stableID 에 `<언어>.` 접두사를 강제하는데 기존 샘플 팩의 시드 3편은 `py-0001-fstring` 형태다. `stableids.lock` 이 개명을 금지하므로 한 팩에 섞으면 두 규칙이 **영구히** 공존한다. 트랙별 팩이면 배포 단위가 트랙이라 사용자가 배우는 트랙만 받고, `PackStore` 가 이미 packID 별 버전 디렉터리를 관리해 앱 쪽 변경이 0이다. `polyglot-mvp` 는 3언어를 한 팩에 담은 파이프라인 픽스처로 남는다.

**게이트가 실제로 일했다.** 12편 중 2편에서 실행 게이트가 결함을 잡았다.

| 레슨 | 결함 |
|---|---|
| `python-for-loop-and-range` | solution 이 숨은 테스트를 통과하지 못함 |
| `python-file-input-output` | 빈칸 정답을 채운 코드가 실행되지 않음 |

`lessongen repair` 가 리포트를 읽어 **그 둘만** 재생성했고 재검증에서 12편 실패 0건. 생성 → 검증 → 수리 → 통과가 처음으로 실제 규모에서 닫혔다.

생성 단계에서도 직렬화가 두 번 거부했다(`@Choice`·`@Hint` 본문 비어 있음). 디스크에 쓰이기 전에 잡혀 재시도로 해결됐다 — `serializeChecked` 가 의도대로 동작한다. 다만 기본 재시도 1회로는 한 편이 끝내 실패해 `--serialization-retries 3` 으로 따로 채워야 했다. **값싼 모델에서 이 실패는 예외가 아니라 상시다.**

한 번 걸린 함정: 실패한 레슨을 빼고 팩을 쓰면 그 레슨을 가리키던 **선수 관계가 조용히 떼어진다**(경고는 나온다). 빠진 레슨을 채운 뒤 그 뒤 레슨도 다시 생성해야 관계가 복원된다.

## 검증

`packtool validate Content/packs/polyglot-python` — 4단계(structural → syntax → semantic → execution) 전부, **레슨 12개 실패 0건**. 실행 게이트가 모든 예제·빈칸·과제를 실제 `CodeRunner` 에 태운 결과다.

`packtool build --sign` 으로 solutions 12개를 벗겨 145,408B tar 를 굽고 `packtool verify` 가 서명·해시 모두 통과.

산문도 표본으로 읽었다. 게이트는 코드가 도는 것만 보증하고 설명의 정확성은 보증하지 않기 때문이다 — 딕셔너리 레슨이 리스트 인덱스와 키 접근을 나란히 대조하고 `KeyError` 와 `get()` 의 차이를 실제 예로 가른다. 게시 가능한 품질이다.

비용: 저장소 실행 로그 기준 호출 18건 **$0.042034**.

## 메모

레슨당 실측 약 $0.0023, 벽시계로는 동시성 4에서 약 1분. 남은 MVP 두 트랙(SQL·Swift)을 같은 규모로 채우면 $0.09 안팎이다. Swift 트랙은 채점이 SwiftPM 템플릿을 공유해 직렬화되므로(`SwiftGradingGate`) 검증 시간이 파이썬보다 훨씬 길 것이다.