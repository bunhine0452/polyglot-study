public import ContentKit
public import LearnCore

/// 레슨 하나가 팩 안에서 차지하는 경로 다섯.
///
/// **전부 stableID 에서 유도한다 — 모델은 경로를 한 글자도 만들지 않는다.** 디렉티브
/// 인자에 실리는 값 중 경로가 가장 깨지기 쉽고(슬래시·점·확장자), 깨져도 조용하기
/// 때문이다. 유도해 두면 `starter:` 인자가 `starters/` 아래라는 것이 구조적으로 참이다.
public struct LessonPaths: Hashable, Sendable {
    public let lesson: PackRelativePath
    public let expected: PackRelativePath
    public let starter: PackRelativePath
    public let tests: PackRelativePath
    public let solution: PackRelativePath

    public init(stableID: LessonID, language: LessonLanguage) throws(PackPathError) {
        let stem = stableID.rawValue
        let ext = language.fileExtension
        self.lesson = try PackRelativePath(validating: "\(PackLayout.lessonsDirectory)/\(stem).md")
        self.expected = try PackRelativePath(
            validating: "\(PackLayout.expectedDirectory)/\(stem).txt")
        self.starter = try PackRelativePath(
            validating: "\(PackLayout.startersDirectory)/\(stem).\(ext)")
        self.tests = try PackRelativePath(validating: "\(PackLayout.testsDirectory)/\(stem).\(ext)")
        self.solution = try PackRelativePath(
            validating: "\(PackLayout.solutionsDirectory)/\(stem).\(ext)")
    }

    /// 레슨 마크다운을 뺀 사이드카 넷. 격리가 지울 대상이기도 하다.
    public var sidecars: [PackRelativePath] { [expected, starter, tests, solution] }

    public var all: [PackRelativePath] { [lesson] + sidecars }
}

/// 개요의 `LessonID` 를 팩 매니페스트가 받아 주는 `stableID` 로 옮긴다.
///
/// ## 왜 변환이 필요한가
///
/// 두 계층이 같은 이름의 서로 다른 문법을 쓴다. ``OutlineAssembler/stableID(language:slug:)``
/// 는 `python.hello-stdout` 을 만드는데, `PackManifest` 의 `stableID` 는 **슬러그
/// 문법**(소문자·숫자·하이픈)이라 점을 거부한다. 개요를 그대로 팩에 넣으면
/// `.invalidStableID` 로 떨어진다.
///
/// 개요 쪽 형식을 바꾸지 않는 이유는, 이미 커밋된 개요 파일과 사람이 리뷰한 diff 가
/// 그 형식으로 존재하기 때문이다. 대신 변환을 **한 군데에 못박고** 점 하나만 하이픈으로
/// 바꾼다 — 순번을 넣지 않으므로 레슨을 중간에 끼워 넣어도 뒤쪽 id 가 흔들리지 않는다는
/// 개요의 규율은 그대로 살아 있다.
public enum PackLessonID {
    /// `python.hello-stdout` → `python-hello-stdout`.
    public static func fromOutline(_ id: LessonID) -> LessonID {
        LessonID(String(id.rawValue.map { $0 == "." ? "-" : $0 }))
    }

    /// 매니페스트가 받아 주는 형태인가. `PackManifest` 의 슬러그 규칙과 같은 판정이다.
    public static func isPackSlug(_ raw: String) -> Bool {
        guard (1...64).contains(raw.count) else { return false }
        guard raw.first != "-", raw.last != "-" else { return false }
        return raw.allSatisfy { character in
            character.isASCII
                && ((character.isLowercase && character.isLetter) || character.isNumber
                    || character == "-")
        }
    }
}
