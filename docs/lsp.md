# sourcekit-lsp 연동

Swift 트랙 에디터의 **완성**과 **실시간 진단**. `{#sourcekit-lsp-swift}` ·
`{#lsp-completion}` · `{#lsp-diagnostics}`.

**Swift 트랙 전용이다.** Python·SQL 트랙은 이 경로를 타지 않는다.

## 타깃과 파일

`Packages/LearnKit/Sources/LSPKit/` — 프로토콜 계층. `LearnCore`·`RunnerKit`·
`Subprocess` 만 본다. AppKit 도 SwiftUI 도 모른다.

| 파일 | 역할 | 프로세스 필요? |
| --- | --- | --- |
| `Protocol/LSPMessageFraming.swift` | `Content-Length` 프레이밍 인코더·증분 디코더 | 없음 |
| `Protocol/JSONRPCMessage.swift` | JSON-RPC 2.0 분류·인코딩 | 없음 |
| `Protocol/LSPTypes.swift` | 실제로 주고받는 메시지 타입만 | 없음 |
| `Mapping/LSPDiagnosticMapping.swift` | LSP 진단 → `LearnCore.Diagnostic` | 없음 |
| `Mapping/LSPCompletionMapping.swift` | LSP 완성 항목 → `CompletionCandidate` | 없음 |
| `Mapping/LSPPositionConversion.swift` | 편집기 좌표 ↔ LSP 좌표 | 없음 |
| `Transport/LSPTransport.swift` | 바이트 통로 프로토콜 | — |
| `Transport/SubprocessLSPTransport.swift` | 진짜 프로세스 통로 | **필요** |
| `Session/LSPSession.swift` | 요청 상관·취소·알림 라우팅 | 없음(가짜 통로) |
| `Session/SourceKitLSPLocator.swift` | `xcrun --find sourcekit-lsp` | **필요** |
| `Session/SwiftLanguageService.swift` | 문서 하나짜리 상위 façade | 없음(가짜 통로) |

`Packages/LearnKit/Sources/Features/EditorFeature/Internal/Completion/` — 화면 배선.

| 파일 | 역할 |
| --- | --- |
| `SwiftCompletionSupport.swift` | 트리거 판정·바꿔 쓸 범위·로컬 필터 (전부 순수) |
| `SwiftSuggestionEntry.swift` | `CompletionCandidate` → `CodeSuggestionEntry` |
| `SwiftLanguageSupport.swift` | 서버 수명 + `CodeSuggestionDelegate` + 진단 수신 |

## 왜 러너를 재사용하지 않는가

`RunnerKit` 의 러너들은 **단발성**이다. 워크스페이스를 만들고 `learn-launcher` 로
rlimit·`sandbox-exec` 를 건 뒤 프로세스가 끝나기를 기다린다. 언어 서버는 그 반대다 —
몇 분씩 살아 있고, 양방향이고, 샌드박스를 씌우면 SDK·모듈 캐시·인덱스를 못 읽어 아무
일도 못 한다.

신뢰 경계도 다르다. 러너가 돌리는 것은 **학습자가 쓴 코드**고, 여기서 돌리는 것은
**Xcode 에 동봉된 애플 바이너리**다. 후자에 rlimit 을 거는 것은 보호가 아니라 고장이다.

공유하는 것은 `swift-subprocess` 라는 수단과 `BoundedCommand`(“절대 매달리지 않는 짧은
신뢰 명령”) 하나뿐이다.

## 동시성 — 이 저장소가 세 번 밟은 함정

이 프로젝트는 “예열해서 재사용하려고 공유한 자원에 동시 접근” 버그를 세 번 밟았다
(`SwiftTestingGrader` 의 공유 템플릿이 마지막). 액터로 감싸는 것만으로는 **부족하다** —
액터 메서드 안에서 `await` 하면 그 지점에서 재진입이 허용된다.

`LSPSession` 에서 그 함정이 나타나는 자리는 둘이다.

1. **바이트 인터리빙** — `id 할당 → 프레임 → await write` 로 쓰면 `await` 지점에서
   다른 호출이 끼어들어 두 메시지의 바이트가 섞인다.
2. **알림 순서 역전** — `didOpen`·`didChange` 는 순서가 곧 의미다. 버전 2 가 버전 1
   보다 먼저 나가면 서버는 문서를 잃는다.

**해법은 락이 아니라 `await` 를 없애는 것이다.** 나가는 모든 메시지는
`AsyncStream.Continuation.yield` 로 큐에 넣는다. `yield` 는 동기라 액터 안에서 중단점을
만들지 않고, 큐를 빼는 작성자 태스크는 **하나뿐**이다. 그래서 “액터 메서드가 호출된
순서 = 바이트가 나가는 순서” 가 구조적으로 보장된다.

공유 범위도 잘라 뒀다. `SwiftLanguageService` 는 **문서 하나**를 맡는다. 두 화면이
동시에 Swift 를 편집하게 되는 날에는 이 타입을 인스턴스마다 서버 하나로 늘려야지,
이 인스턴스를 공유해서는 안 된다.

## 취소

`{#lsp-completion}` 의 완료 기준 절반이 “취소 시 요청이 실제로 취소됨” 이다.
**시간이 아니라 구조로 증명한다.**

취소가 서버까지 가는 경로는 구조적 동시성 하나다.

```
SuggestionViewModel.itemsRequestTask.cancel()   (편집기가 새 완성을 시작)
  → SwiftLanguageSupport.completionSuggestionsRequested
  → SwiftLanguageService.completions            (직접 await — Task {} 로 감싸면 끊긴다)
  → LSPSession.request 의 withTaskCancellationHandler
  → 큐에 $/cancelRequest
```

**`Task { }` 로 감싸면 안 된다.** 새 태스크는 부모의 취소를 물려받지 않아, 편집기가
취소해도 안쪽 LSP 요청이 살아남고 `$/cancelRequest` 가 영영 나가지 않는다.

늦게 도착한 응답은 `pending` 에서 이미 빠져 조용히 버려진다 — continuation 이중 재개가
구조적으로 불가능하다.

## 서버가 없는 머신

`SourceKitLSPLocator.locate()` 가 던지고 `SwiftLanguageSupport.status` 가
`.unavailable(이유)` 이 된다. 그러면 완성과 실시간 진단만 없고 **편집·실행·채점·
`swiftc` 진단은 그대로 동작한다.** 실패를 삼키지 않는 이유는 “완성이 안 뜨는데 아무도
이유를 모르는” 상태를 만들지 않기 위해서다.

테스트도 같은 방식으로 갈린다. 프레이밍·JSON-RPC·매핑·좌표·세션(취소 포함)은 **가짜
통로 위에서 서버 없이** 전부 검증되고, 실제 서버를 띄우는 스위트만
`.enabled(if: available)` 로 건너뛴다. `LEARNKIT_SKIP_LSP` 를 세우면 서버가 있어도
건너뛴다.

## 실측으로 확인된 것 (macOS 26.6.2 / Xcode 26.6)

```
$ xcrun --find sourcekit-lsp
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp
```

- **initialize 응답 38~50ms.** `completionProvider.triggerCharacters` 는 `[".", "("]`,
  `resolveProvider: true`.
- **파일이 디스크에 없어도 된다.** 존재하지 않는 `file:` URI 로 `didOpen` 해도 진단과
  완성이 정상이다(200개). 그래서 **학습자 코드를 디스크에 쓰지 않는다** — 빈 임시
  디렉터리 하나만 `rootUri` 로 준다.
- **첫 `publishDiagnostics` 는 didOpen 뒤 1.2~1.4초.** 서버가 모듈을 여는 시간이다.
  `didChange` 뒤로는 ~1.07초.
- **완성 지연**: 첫 요청 88ms, 예열 뒤 27~30ms (n=5, 중앙값 28ms). 진단이 한 번 도는
  중에 겹쳐 부르면 270ms 로 늘어난다 — 그래서 완성 예산 측정은 첫 진단 뒤에 한다.
- **취소는 `-32800` 으로 답한다**: `{"code": -32800, "message": "request cancelled by client"}`.
- 진단 `source` 는 `"SourceKit"` 이고 `code`(규칙 id)는 **보내지 않는다.** 그래서
  `Diagnostic.ruleID` 는 nil 이고, 출처는 인라인 행의 **라벨**로 간다.
- 완성 항목의 `label` 은 사람이 읽는 시그니처
  (`split(separator: Collection, maxSplits: Int, ...)`)이고 실제로 넣어야 하는 것은
  `textEdit.newText`(`split(separator: , maxSplits: , ...)`)다. **바꿔 쓰면 타입 이름이
  코드에 박힌다.**
- `sortText` 는 알파벳순이 아니라 관련도 점수가 앞에 붙은 문자열이다
  (`"4998.78379906-split(...)"`). 우리가 label 로 다시 정렬하면 서버가 아는 문맥이
  통째로 버려진다.

## 진단이 화면에 붙는 방식

`{#lsp-diagnostics}` 의 완료 기준은 “swiftc 진단과 **같은 컴포넌트**로 렌더하고
**출처만 라벨로** 구분” 이다.

`EditorDiagnosticPresentation.rows(groups:)` 가 출처별 묶음을 받아 한 목록으로 접는다.
새 뷰는 없다 — `InlineDiagnosticRowView` 그대로다.

```
4행 9열 · swiftc · 1개
4행 9열 · sourcekit-lsp · 1개
4행 9열 · sourcekit-lsp/swiftc · 2개      (같은 줄에 둘 다 있을 때)
```

스냅샷을 출처마다 따로 드는 이유: `swiftc` 진단은 마지막으로 **실행한** 코드 기준이고
언어 서버 진단은 **지금 편집 중인** 코드 기준이다. 인라인 행은 그 줄의 소스 텍스트를
같이 그리므로 어느 쪽 스냅샷인지가 눈에 보인다. 코드 줄은 **먼저 온 그룹**에서
가져오고, `EditorModel` 은 언어 서버 쪽을 앞에 놓는다(더 신선하다).

## 좌표계 셋

| 표현 | 줄 | 열 |
| --- | --- | --- |
| LSP `Position` | 0-기반 | 그 줄의 **UTF-16 코드 단위** 오프셋, 0-기반 |
| `LearnCore.Diagnostic` | 1-기반 | 1-기반 **표시** 칼럼 |
| `CursorPosition.range.location` | — | 문서 전체의 UTF-16 오프셋 |

ASCII 에서는 셋이 다 같은 값이라 눈대중으로 넘어가고, 이모지·조합형이 섞이는 순간
조용히 어긋난다. `"let 🇰🇷 = 1"` 에서 태극기는 Character 하나지만 UTF-16 으로 **네
단위**다 — LSP 의 `character: 8` 을 그대로 +1 하면 라벨이 “9열” 이라고 하는데 눈으로
세면 6열이다. 변환은 `LSPPositionConversion` 과 `LSPDiagnosticMapping.displayColumn`
한 곳에만 있다.

`"\r\n"` 은 Swift 에서 **Character 하나**이고 UTF-16 으로는 둘이다. 줄바꿈으로 세되
폭은 2 로 세야 CRLF 문서에서 오프셋이 밀리지 않는다. 같은 이유로 줄 나누기는 전부
`components(separatedBy:)` 다 — `split(separator: "\n")` 은 CRLF 를 뭉친다.
