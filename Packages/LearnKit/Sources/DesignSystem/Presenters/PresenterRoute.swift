public import LearnCore

/// 프리젠터 라우터가 실제로 고르는 뷰. `GradeResult.Presenter` 네 케이스가 세 갈래로 접힌다.
public enum PresenterRoute: String, Hashable, Sendable, CaseIterable {
    case console
    case table
    case preparing
}

/// 도메인의 프리젠터 선택을 **화면 표현**으로 잇는다.
///
/// 여기 있던 `ResultPresentation` — `GradeResult.Presenter` 네 케이스를 그대로 옮겨 적은
/// 열거형 — 은 지웠다. 있던 이유는 하나뿐이었다: `DesignSystem` 타깃에 dependencies 가
/// 없어서 `LearnCore` 를 볼 수 없었다. 그래서 화면 계층
/// (`LessonFeature.LessonPresentation`)에 두 열거형을 1:1로 잇는 `switch` 가 있었고,
/// 그 대응이 어긋나지 않는지 확인하는 테스트가 또 있었다. `LearnCore` 의존을 붙이면서
/// 셋 다 사라졌다 — 옮겨 담지 않으면 어긋날 것도 없다.
///
/// `PresenterRoute` 는 남는다. 저건 미러가 아니라 **뷰가 셋뿐이라는 사실**이고,
/// 도메인에는 있을 이유가 없는 정보다.
extension GradeResult.Presenter {
    /// 라우터가 고르는 세 갈래. 뷰를 렌더하지 않고 분기만 단언하기 위한 창구다.
    public var route: PresenterRoute {
        switch self {
        case .console: .console
        case .table: .table
        case .browser, .registers: .preparing
        }
    }

    public var title: String {
        switch self {
        case .console: "출력"
        case .table: "결과"
        case .browser: "미리보기"
        case .registers: "레지스터"
        }
    }

    /// 준비중 뷰에 적히는 한 줄. 실제 뷰가 있는 두 케이스는 nil 이다.
    public var pendingReason: String? {
        switch self {
        case .console, .table: nil
        case .browser: "Next.js 트랙은 dev 서버와 웹뷰가 붙은 뒤에 열립니다."
        case .registers: "Assembly 트랙은 에뮬레이터가 붙은 뒤에 열립니다."
        }
    }
}
