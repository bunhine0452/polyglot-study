public import ContentKit
public import LearnCore

public import Foundation
internal import RunnerKit

/// 콘텐츠 팩의 `@Task` 블록 하나를 에디터 화면이 그릴 값으로 옮긴다.
///
/// 이 변환이 **여기** 있는 이유: 언어마다 파일 이름과 채점 재료가 다르고, 그 규칙은
/// `packtool` 의 실행 게이트(`BlockGate`)와 **글자 하나까지 같아야** 한다. 게이트가
/// 통과시킨 과제가 앱에서 다르게 조립되면 게이트는 아무것도 보장하지 못한다. 규칙을
/// 앱 계층에 두면 그 대조를 테스트로 고정할 자리가 없어진다.
extension EditorTask {
    /// - Parameters:
    ///   - pack: 이 과제가 사는 팩. 시작 코드·숨은 테스트를 여기서 읽는다.
    ///   - blockIndex: 6블록 시퀀스 안에서의 0-기반 위치. 헤더와 과제 바 번호가 여기서 나온다.
    ///   - database: SQL 트랙이 대상으로 삼을, 이미 구워진 시드 데이터베이스
    ///     (``PackSQLSeed/materialize(pack:into:)``). 다른 언어는 nil.
    public static func load(
        pack: ContentPack,
        task: TaskBlock,
        trackCaption: String,
        lessonTitle: String,
        blockIndex: Int,
        blockCount: Int,
        database: URL? = nil
    ) throws(ContentPackError) -> EditorTask {
        let starter = try pack.text(at: task.starterPath)
        // `tests/` 는 언어마다 뜻이 다르다 — Swift·Python 은 숨은 테스트, SQL 은 **참조
        // 질의**다. `BlockGate.grade(submission:tests:language:)` 가 SQL 에서만 이 값을
        // `reference` 로 넘기는 것과 같은 규칙이다.
        //
        // SQL 의 참조를 `solutions/` 가 아니라 `tests/` 에서 읽는 것은 취향이 아니다.
        // 배포 팩은 `solutions/` 를 **벗겨 낸다**(`PackLayout.strippedInDistribution`).
        // 정답 파일에 기대면 SQL 채점이 배포본에서만 깨진다.
        let testsSource = try pack.text(at: task.testsPath)

        return EditorTask(
            trackCaption: trackCaption,
            lessonTitle: lessonTitle,
            blockCaption: "블록 \(blockIndex + 1) / \(blockCount) · 테스트 과제",
            taskOrdinalLabel: "\(twoDigits(blockIndex + 1)) 테스트 과제",
            prose: task.prose,
            language: task.language,
            entryFileName: entryFileName(for: task.language),
            starterSource: starter,
            testSource: task.language == .sql ? nil : testsSource,
            solutionSource: task.language == .sql ? testsSource : nil,
            database: task.language == .sql ? database : nil,
            criteria: .unordered,
            testCount: hiddenTestCount(in: testsSource, language: task.language)
        )
    }

    /// 학습자 코드가 워크스페이스에서 갖는 파일 이름.
    ///
    /// **Python 은 `solution.py` 여야 한다.** 팩의 숨은 테스트가 `from solution import …`
    /// 로 모듈을 부르고(`docs/pack-format.md` 의 언어별 규약), `EditorModel.defaultGrade`
    /// 가 이 이름을 그대로 채점기에 넘긴다. 다른 이름을 주면 12편 전부가 ImportError 로
    /// 뒤집힌다.
    ///
    /// Swift 는 `main.swift` 다. 채점은 이 이름을 쓰지 않고(`Solution.swift` 로 다시
    /// 담아 `@testable import Solution` 을 성립시킨다) 실행 버튼만 이 파일을 태운다.
    public static func entryFileName(for language: LanguageID) -> String {
        switch language {
        case .python: "solution.py"
        case .swift: "main.swift"
        case .sql: "query.sql"
        default: "main.txt"
        }
    }

    /// 과제 바의 "테스트 N개 통과 시 완료" 에 들어갈 N.
    ///
    /// 세는 규칙이 언어마다 하나씩이고, 못 세면 **0** 을 준다 — 화면은 0 이면 그 라벨을
    /// 아예 그리지 않는다. 틀린 숫자를 보여주느니 말하지 않는 편이 낫다.
    static func hiddenTestCount(in source: String, language: LanguageID) -> Int {
        switch language {
        case .swift:
            // swift-testing 의 `@Test` 선언. `@Test func`, `@Test("이름")` 둘 다 센다.
            source.split(separator: "\n").count { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("@Test") else { return false }
                let rest = trimmed.dropFirst("@Test".count)
                return rest.isEmpty || rest.first == " " || rest.first == "("
            }
        case .python:
            // unittest 의 `def test…(self)`. 메서드 하나가 테스트 하나다.
            source.split(separator: "\n").count { line in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("def test")
            }
        default:
            0
        }
    }

    private static func twoDigits(_ value: Int) -> String {
        value >= 0 && value < 10 ? "0\(value)" : "\(value)"
    }
}
