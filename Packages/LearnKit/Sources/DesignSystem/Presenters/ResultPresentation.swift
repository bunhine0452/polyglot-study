/// 결과를 무엇으로 보여줄지. `LearnCore.GradeResult.Presenter` 네 케이스를 그대로 옮긴 것.
///
/// **왜 옮겨 적는가.** `DesignSystem` 은 `LearnCore` 에 의존하지 않는다(`Package.swift`
/// 의 `.target(name: "DesignSystem")` 에 dependencies 가 없다). 디자인 시스템이 도메인
/// 타입을 알기 시작하면 그 방향은 되돌리기 어렵고, 반대로 여기서 표시용 열거형을 두면
/// 화면 계층이 한 번만 옮겨 담으면 된다. 옮기는 자리는 화면 계층에 하나뿐이고
/// (`LessonFeature.LessonPresentation`), 네 케이스가 빠짐없이 대응되는지는 그쪽
/// 테스트가 `GradeResult.Presenter.allCases` 로 고정한다.
public enum ResultPresentation: String, Hashable, Sendable, CaseIterable {
    /// stdout/stderr 를 흘려보내는 콘솔 — Python·Swift·C++·Rust·Go·Java.
    case console
    /// 행·열 diff 가 있는 결과 그리드 — SQL.
    case table
    /// localhost dev 서버를 띄우는 웹뷰 — Next.js.
    case browser
    /// 레지스터·스택·메모리 패널 — Assembly.
    case registers

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

/// 프리젠터 라우터가 실제로 고르는 뷰. 네 케이스가 세 갈래로 접힌다.
public enum PresenterRoute: String, Hashable, Sendable, CaseIterable {
    case console
    case table
    case preparing
}
