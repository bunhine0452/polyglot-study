public import LearnCore
internal import LanguageKit
internal import RunnerKit

/// 언어 → 프리젠터. 화면이 결과를 무엇으로 그릴지 정하는 **유일한 자리**.
///
/// 예전에는 여기에 `GradeResult.Presenter` → `DesignSystem.ResultPresentation` 변환과
/// `LearnCore.ResultSet` → `DesignSystem.ResultTable` 변환(`ResultSetBridge`)이 함께
/// 있었다. `DesignSystem` 이 `LearnCore` 를 볼 수 없어 표시용 사본이 저쪽에 하나씩
/// 있었기 때문이다. 그 의존을 붙이면서 사본도 변환기도 지웠다 — 프리젠터 뷰가 도메인
/// 값을 그대로 받는다.
public enum LessonPresentation {
    /// 언어 → 프리젠터. `LanguageModule` 이 있는 언어는 **그 모듈이 선언한 값**을 쓴다 —
    /// 화면이 따로 정하면 채점기와 갈라진다.
    public static func presenter(for language: LanguageID) -> GradeResult.Presenter {
        switch language {
        case .python: PythonLanguageModule().presenter
        case .swift: SwiftLanguageModule().presenter
        // SQL 에는 아직 `LanguageModule` 이 없다. 인프로세스 러너가 `RunEvent.resultSet` 으로
        // 구조화된 표를 내므로 표 프리젠터다 — 백엔드 능력에서 나온 값이지 취향이 아니다.
        case .sql: .table
        default: .console
        }
    }
}
