public import DesignSystem
public import LearnCore
internal import LanguageKit
internal import RunnerKit

/// 도메인의 `GradeResult.Presenter` 를 디자인 시스템의 ``ResultPresentation`` 으로 옮기는
/// **유일한 자리**.
///
/// `DesignSystem` 은 `LearnCore` 를 의존하지 않으므로(패키지 선언에 dependencies 가 없다)
/// 프리젠터 열거형이 양쪽에 하나씩 있다. 그 둘이 어긋나지 않는다는 보장은 여기 있는
/// `switch` 가 exhaustive 하다는 사실과, 네 케이스를 전부 도는 테스트가 함께 만든다.
public enum LessonPresentation {
    public static func presentation(for presenter: GradeResult.Presenter) -> ResultPresentation {
        switch presenter {
        case .console: .console
        case .table: .table
        case .browser: .browser
        case .registers: .registers
        }
    }

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

    public static func presentation(for language: LanguageID) -> ResultPresentation {
        presentation(for: presenter(for: language))
    }
}

/// `LearnCore.ResultSet` → ``ResultTable``. 표시용 문자열로만 옮긴다.
enum ResultSetBridge {
    static func table(from resultSet: ResultSet) -> ResultTable {
        ResultTable(
            columns: resultSet.columns.map {
                ResultTable.Column(name: $0.name, declaredType: $0.declaredType)
            },
            rows: resultSet.rows.enumerated().map { index, row in
                ResultTable.Row(
                    id: index,
                    cells: row.map { ResultTable.Cell(text: $0.displayText, isNull: $0.isNull) }
                )
            },
            isTruncated: resultSet.isTruncated
        )
    }
}
