/// `CodeEditSourceEditor` 위에 이 앱의 무채색 규칙을 얹는 얇은 층.
///
/// 화면 코드(향후 `LessonFeature` 등)는 `CodeEditSourceEditor` 를 직접 구성하지 않는다 —
/// `EditorUIConfiguration.make()` 가 만든 값(이미 `MonochromeEditorTheme.make()` 를 품고
/// 있다)을 `SourceEditor(_:language:configuration:state:)` 의 `configuration:` 에 그대로
/// 넘기면 된다. 언어 선택은 그 생성자의 `language:` 인자가 따로 받는다.
///
/// ## 의존 그래프 메모
///
/// - `CodeEditSourceEditor` 는 이 리포에서 `Vendor/CodeEditSourceEditor` 로 벤더링됐다.
///   0.15.2 에 업스트림 PR #355(머지 대기)를 적용해 죽은 `CodeEditSymbols` 의존을 뺐다 —
///   그 의존의 `Package.swift` 가 리소스를 선언하지 않아 `Bundle.module` 이 생성되지 않고
///   `swift build`/`swift test` 가 실패했다(`xcodebuild` 경로는 원래도 통과했다). 경위는
///   `Vendor/CodeEditSourceEditor/VENDORING.md`.
/// - `CodeEditLanguages` 는 `CodeEditSourceEditor` 의 **`exact` 전이 의존**(`0.1.20`)이라
///   이쪽에서 버전을 옮기거나 뺄 수 없다 — python·sql·swift tree-sitter 그래머가 이미
///   거기 들어있어서 그대로 받는다. 그리고 **이 저장소 최상위에 LICENSE 파일이 없다.**
///   CodeEdit 조직의 주요 저장소(CodeEdit·CodeEditSourceEditor·CodeEditTextView) 는 전부
///   MIT 이고 README 태그라인이 "Open source, free forever" 라 정책적 결정이 아니라
///   단순 누락으로 판단한다 — 라이선스 리스크로 보되 상류 이슈로 제기할 사안이지, 이
///   앱이 코드를 손대는 문제는 아니다.
public enum EditorUI {}
