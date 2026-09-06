# 벤더링 기록 — CodeEditSourceEditor

`{#cese-fork-drop-codeeditsymbols}`

| 항목 | 값 |
|---|---|
| Upstream | <https://github.com/CodeEditApp/CodeEditSourceEditor> |
| 베이스 태그 | `0.15.2` (커밋 `424453d2232c9912933a3b5a1f3d3df669404ed0`) |
| 적용한 업스트림 패치 | PR #355 “Remove CodeEditSymbols dependency” — 작성자 rodionovd, 커밋 `d7140f0610e04bd97a7447b0554b5388c7b813af`. **머지되지 않고 open 상태**(base `4a3cb13`, `mergeable: clean`). 코드가 정확하고 CI 도 통과하지만 유지보수자가 아직 처리하지 않은 PR이라 판단해 그 변경만 우리 베이스(0.15.2)에 재현했다. |
| 라이선스 | MIT (`LICENSE`, 원본 `LICENSE.md` 그대로 복사) |
| 벤더링 날짜 | 2026-09-06 |
| 복사 파일 | `Sources/CodeEditSourceEditor/` 전체 — Swift 157개(14,596줄) + `Documentation.docc` 자료 5개(md 3 + png 2) |

## 왜 포크가 아니라 로컬 벤더링인가

이 항목의 지시대로 GitHub 에 포크·푸시 등 외부 동작을 하지 않았다. 문제의 범위가 딱 한 파일의
죽은 `import` 한 줄이고 고칠 지점이 이미 병합 대기 중인 PR로 존재하므로, 그 diff를 로컬에
재현해 `.package(path:)` 로 무는 것이 새 원격 저장소를 만드는 것보다 관리 비용이 낮다.

## 원인

`CodeEditSourceEditor` 0.15.2 는 `CodeEditSymbols` 0.2.3 을 전이 의존한다. `CodeEditSymbols`
의 `Package.swift` 가 `Symbols.xcassets` 를 타깃의 `resources:` 에 선언하지 않아 SPM 이
`Bundle.module` 을 생성하지 않는데, `xcodebuild` 는 Xcode 프로젝트 통합 처리 경로에서 이를
관대하게 넘기지만 **`swift build`/`swift test` CLI 경로는 실패한다.** 이 저장소의 앱은 CLI
경로로 빌드되므로 막힌다.

`CodeEditSourceEditor` 소스 전체에서 `CodeEditSymbols` 사용처는
`Sources/CodeEditSourceEditor/Find/PanelView/FindPanelView.swift` 의 `import CodeEditSymbols`
단 한 줄이고, 실제 심볼 참조가 0건이다(그 파일 어디에도 `CodeEditSymbols.` 접두 호출이 없다).
즉 이 의존은 애초에 불필요했다.

## 로컬 수정 사항

1. **`Package.swift` — `CodeEditSymbols` 의존 제거** (PR #355 그대로)
   - `dependencies:` 에서 `CodeEditSymbols` 패키지 선언 삭제.
   - `CodeEditSourceEditor` 타깃의 `dependencies:` 배열에서 `"CodeEditSymbols"` 삭제.
   - 업스트림 PR 요약과 동일하게 순변경은 `Package.swift` -6줄, `FindPanelView.swift` -1줄,
     추가 0줄이다.

2. **`Sources/CodeEditSourceEditor/Find/PanelView/FindPanelView.swift` — `import CodeEditSymbols` 삭제**
   (PR #355 그대로) 나머지 8개 import 와 본문은 한 글자도 바꾸지 않았다.

3. **`Tests/` 미포함, `swift-custom-dump` 의존 미포함** (PR #355 범위 밖의 추가 트리밍)
   이 리포는 `CodeEditSourceEditor` 를 라이브러리로만 소비하고 그 자체 테스트 스위트를
   실행하지 않는다 — SPM 은 의존 패키지의 테스트 타깃을 소비자 빌드에 포함시키지 않으므로
   가져와도 죽은 무게만 늘어난다. `LearnScheduling/Vendor/FSRS` 벤더링에서도 같은 이유로
   업스트림 `Tests/` 를 뺐다(그 문서 참고). 원본 테스트 타깃이 요구하는
   `swift-custom-dump` 의존도 함께 뺐다.

4. **`Example/`, `README.md`, `.github/`, `.swiftlint.yml`, `.spi.yml` 미포함**
   빌드에 필요 없는 문서·CI·예제 자산. 라이선스 고지는 `LICENSE` 파일로 충분하다.

5. **`SwiftLintPlugin` 의존과 플러그인 선언 제거** (PR #355 범위 밖의 추가 트리밍)
   처음엔 diff 최소화를 위해 그대로 뒀으나, 실제로 `swift build` 를 돌려보니 플러그인이
   `.swiftlint.yml`(벤더링에서 제외한 설정 파일)을 찾지 못해 빌드가 죽었다. 설정 파일을
   추가로 벤더링하는 대신 플러그인 자체를 뺐다 — **얼어붙은 벤더 소스에 린터를 매 빌드마다
   돌리는 것 자체가 우리가 통제할 수 없는 경고/실패의 원천**이라 판단해서다. 이 저장소가
   가져온 건 CodeEditSourceEditor 의 컴파일된 동작이지 그 코드 스타일 감시가 아니다.
   `CodeEditTextView`(벤더링 대상 아님, 원격 의존 그대로)는 자기 자신의 `.swiftlint.yml`
   을 가진 온전한 체크아웃이라 이 결정과 무관하게 그대로 작동한다.

## 벤더링하지 않은 것 — CodeEditTextView·CodeEditLanguages·TextFormation

이 세 패키지는 버그가 없다(`Bundle.module` 문제는 `CodeEditSymbols` 에 국한). `Package.swift`
의 `dependencies:` 에서 여전히 원격 `.package(url:)` 로 그대로 문다. 전체 그래프를 벤더링하는
건 과했다 — tree-sitter 그래머 소스까지 끌고 와야 해서 이 한 파일짜리 죽은 import 를 고치는
비용과 균형이 맞지 않는다. `CodeEditLanguages` 는 `exact` 핀이라 애초에 벤더링해도 버전을
옮길 수 없고(모듈 주석 참고), LICENSE 파일 자체가 없다는 별도 문제만 있을 뿐 리소스 매니페스트
버그는 없다.

## 검증

이 패치를 얹은 뒤 `swift build --package-path Packages/LearnKit` 가 `EditorUI` 타깃을 포함해
경고 0으로 통과하는 것으로 확인했다(같은 커밋의 빌드 로그 참고). 업스트림이 언젠가 PR #355 를
머지해 새 버전을 태그하면 이 벤더 디렉터리를 통째로 지우고 원격 의존으로 되돌릴 수 있다 —
그때까지 `CodeEditSymbols` 를 향한 어떤 코드 경로도 이 트리에 없다.
