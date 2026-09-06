public import LearnCore

/// 레슨 생성이 아는 트랙 언어.
///
/// `LanguageID` 는 문자열 래퍼라 무엇이든 담긴다. 여기서 열거형으로 좁히는 이유는 이
/// 단계가 언어마다 **다른 사실**을 알아야 하기 때문이다 — 파일 확장자, 코드펜스 info
/// 문자열, 그리고 무엇보다 **채점 하네스의 계약**. 하네스 계약이 틀리면 solution 이
/// 아무리 옳아도 테스트가 컴파일조차 되지 않는다.
///
/// MVP 3종만 있다. 새 트랙은 여기에 한 케이스를 더하는 것으로 시작한다 — 그러면
/// 프롬프트·경로·직렬화가 한꺼번에 따라온다.
public enum LessonLanguage: String, CaseIterable, Sendable, Hashable {
    case python
    case sql
    case swift

    public init?(_ id: LanguageID) {
        self.init(rawValue: id.rawValue)
    }

    public var id: LanguageID { LanguageID(rawValue) }

    /// starter·tests·solution 파일 확장자.
    public var fileExtension: String {
        switch self {
        case .python: "py"
        case .sql: "sql"
        case .swift: "swift"
        }
    }

    /// 코드펜스 info 문자열. 파서가 `codeFenceLanguage` 로 담아 두고 에디터가 읽는다.
    public var fenceInfo: String { rawValue }

    /// 채점 하네스 계약. **프롬프트에 그대로 실린다.**
    ///
    /// 실측한 계약이다 — `PythonUnittestGrader` 는 제출을 `solution.py` 로 놓고 테스트
    /// 모듈을 따로 임포트하며, `SwiftTestingGrader` 는 `Sources/Solution` 과
    /// `Tests/SolutionTests` 두 타깃으로 나눈 SwiftPM 패키지를 굽는다. SQL 은 결과셋
    /// 비교라 "테스트"가 기대 결과를 만드는 질의다.
    public var harnessContract: String {
        switch self {
        case .python:
            """
            - starter·solution 은 채점기가 `solution.py` 로 놓는다. 최상위에서 실행되는 \
            코드를 두지 말고 함수·클래스 정의만 둬라.
            - tests 는 `unittest` 모듈이다. 첫 줄은 `import unittest` 이고, 검사 대상은 \
            `from solution import <이름>` 으로 가져온다.
            - `unittest.main()` 을 호출하지 마라 — 하네스가 직접 로드한다.
            - 테스트 케이스는 3개 이상이고, 그중 최소 하나는 경계값(빈 입력·0·음수 같은 것)이다.
            """
        case .sql:
            """
            - starter·solution 은 **질의 하나**다. 채점기는 학습자 질의의 결과셋과 tests \
            질의의 결과셋을 행 단위로 비교한다.
            - tests 는 기대 결과셋을 그대로 만들어 내는 질의다 (`SELECT … UNION ALL SELECT …`). \
            열 이름과 순서가 solution 과 정확히 같아야 하고, 정렬이 필요하면 `ORDER BY` 를 붙인다.
            - 테이블은 `assets/` 의 시드가 만든 것만 쓸 수 있다. 이 레슨에 시드가 없으면 \
            질의 안에서 `WITH` 절로 데이터를 직접 만들어라.
            """
        case .swift:
            """
            - starter·solution 은 `Sources/Solution` 타깃에 놓인다. 최상위 실행 코드를 \
            두지 말고 선언만 둬라. `@main` 을 쓰지 마라.
            - tests 는 `Tests/SolutionTests` 타깃이다. 첫 두 줄은 `import Testing` 과 \
            `@testable import Solution` 이고, swift-testing 의 `@Test` 함수와 `#expect` 를 쓴다. \
            XCTest 를 쓰지 마라.
            - 테스트 함수는 3개 이상이고, 그중 최소 하나는 경계값이다.
            """
        }
    }

    /// 실행 예제 코드에 요구하는 것. 예제는 stdout 을 기대 파일과 **바이트로** 대조한다.
    public var exampleContract: String {
        switch self {
        case .python:
            """
            - 예제는 그 자체로 실행되는 스크립트다. `print` 로 stdout 에 쓴다.
            - 입력을 읽지 않는다. 난수·시각·경로처럼 실행마다 달라지는 것을 출력하지 않는다.
            """
        case .sql:
            """
            - 예제는 질의 하나이고, 출력은 결과셋을 표로 찍은 것이다.
            - 테이블은 `assets/` 시드가 만든 것만 쓴다. 시드가 없으면 `WITH` 절로 데이터를 \
            직접 만들어라. `ORDER BY` 로 행 순서를 못박아라 — 순서가 흔들리면 대조가 깨진다.
            """
        case .swift:
            """
            - 예제는 최상위 실행 코드다 (스크립트 모드). `print` 로 stdout 에 쓴다.
            - 입력을 읽지 않는다. 난수·시각·주소처럼 실행마다 달라지는 것을 출력하지 않는다.
            """
        }
    }
}
