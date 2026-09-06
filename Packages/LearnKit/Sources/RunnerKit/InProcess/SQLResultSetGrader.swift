public import Foundation
public import LearnCore
public import LanguageKit

/// 채점 한 번의 전부. `GradeResult` 는 UI 계약이고, 나머지는 표 프리젠터가 쓰는 원자재다.
public struct SQLGrading: Sendable {
    public var result: GradeResult
    public var comparison: SQLComparison?
    public var expected: ResultSet?
    public var actual: ResultSet?

    public var passed: Bool { result.passed }
}

/// SQL 결과셋 비교 채점기.
///
/// 참조 해답과 사용자 제출을 **각각 다른 클론에서** 돌린다. `InProcessRunner.execute` 가
/// 호출마다 워크스페이스와 DB 클론을 새로 만들기 때문에 그냥 두 번 부르면 된다 —
/// 참조 해답이 만든 임시 상태가 사용자 쿼리에 보이지 않는다는 뜻이다.
public struct SQLResultSetGrader: Sendable {
    public var runner: InProcessRunner
    /// 이 레슨의 원본 `.db`. 러너가 아니라 채점기가 들고 있다 — 러너는 레슨을 모르는
    /// 재사용 가능한 값이고, 레슨마다 달라지는 것은 대상 자원이다.
    public var database: URL?
    public var criteria: SQLGradingCriteria

    public init(
        runner: InProcessRunner,
        database: URL? = nil,
        criteria: SQLGradingCriteria = .unordered
    ) {
        self.runner = runner
        self.database = database
        self.criteria = criteria
    }

    public func grade(
        submission: String,
        reference: String,
        limits: ResourceLimits = .lesson
    ) async throws -> SQLGrading {
        // ① 참조 해답. 여기서 실패하면 레슨 콘텐츠가 잘못된 것이지 학습자 잘못이 아니다.
        let referenceRun = try await runner.execute(
            sql: reference, database: database, limits: limits, fileName: "reference.sql"
        )
        guard let expected = referenceRun.resultSet, !referenceRun.failed else {
            let detail = referenceRun.diagnostics.first?.message ?? "결과셋이 없습니다"
            throw RunFailure.backend("참조 해답 실행 실패: \(detail)")
        }

        // ② 사용자 제출. 완전히 다른 클론.
        let submissionRun: SQLExecutionResult
        do {
            submissionRun = try await runner.execute(
                sql: submission, database: database, limits: limits, fileName: "answer.sql"
            )
        } catch let failure as RunFailure {
            return SQLGrading(
                result: GradeResult(
                    passed: false,
                    tests: [.init(name: "결과셋 일치", passed: false, message: Self.describe(failure))],
                    diagnostics: [],
                    durationMilliseconds: 0,
                    presenter: .table
                ),
                comparison: nil,
                expected: expected,
                actual: nil
            )
        }

        guard let actual = submissionRun.resultSet, !submissionRun.failed else {
            let message = submissionRun.diagnostics.first?.message ?? "결과를 내는 SELECT 가 없습니다"
            return SQLGrading(
                result: GradeResult(
                    passed: false,
                    tests: [.init(name: "결과셋 일치", passed: false, message: message)],
                    diagnostics: submissionRun.diagnostics,
                    stdout: "",
                    // 인프로세스 실행에는 종료 코드가 없다. 예전에는 여기서 1 을
                    // 지어냈는데, 그러면 "종료코드 1"이 서브프로세스의 진짜 1 과
                    // 구별되지 않는다 — 실패 여부는 `passed`·진단이 이미 말한다.
                    exitCode: nil,
                    durationMilliseconds: submissionRun.durationMilliseconds,
                    presenter: .table
                ),
                comparison: nil,
                expected: expected,
                actual: submissionRun.resultSet
            )
        }

        let comparison = SQLResultComparator(criteria: criteria).compare(expected: expected, actual: actual)
        let outcome = GradeResult.TestOutcome(
            name: "결과셋 일치",
            passed: comparison.matches,
            message: comparison.matches ? nil : comparison.summary + " — " + comparison.diff.summary,
            durationMilliseconds: submissionRun.durationMilliseconds
        )

        return SQLGrading(
            result: GradeResult(
                passed: comparison.matches,
                tests: [outcome],
                diagnostics: submissionRun.diagnostics,
                stdout: SQLTextRenderer.render(actual),
                exitCode: nil,
                durationMilliseconds: submissionRun.durationMilliseconds,
                presenter: .table
            ),
            comparison: comparison,
            expected: expected,
            actual: actual
        )
    }

    private static func describe(_ failure: RunFailure) -> String {
        switch failure {
        case .toolchainMissing(let hint): "툴체인 없음: \(hint)"
        case .wallClockExceeded(let seconds): "\(seconds)초 안에 끝나지 않았습니다"
        case .cpuExceeded(let seconds): "CPU 시간 \(seconds)초를 다 썼습니다 — 쿼리가 너무 무겁습니다"
        case .memoryExceeded(let megabytes): "메모리 상한 \(megabytes)MB 초과"
        case .fileSizeExceeded(let bytes): "파일 크기 상한 \(bytes)바이트 초과 — 무엇을 쓰고 있는지 확인하세요"
        case .cancelled: "실행이 취소되었습니다"
        case .backend(let message): message
        }
    }
}
