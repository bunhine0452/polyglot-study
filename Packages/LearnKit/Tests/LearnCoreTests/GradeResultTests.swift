import Testing
@testable import LearnCore

@Suite("GradeResult")
struct GradeResultTests {
    @Test("실패한 테스트만 골라낸다")
    func failedTestsFiltersOutPasses() {
        let result = GradeResult(
            passed: false,
            tests: [
                .init(name: "값 타입은 복사된다", passed: true),
                .init(name: "참조 타입은 공유된다", passed: false, message: "b.x 가 1 이 아니라 99"),
            ],
            durationMilliseconds: 42,
            presenter: .console
        )

        #expect(result.failedTests.map(\.name) == ["참조 타입은 공유된다"])
    }

    @Test("error 진단이 하나라도 있으면 hasErrors")
    func hasErrorsIgnoresWarnings() {
        let warningOnly = GradeResult(
            passed: true,
            diagnostics: [.init(severity: .warning, message: "사용하지 않는 변수 a")],
            durationMilliseconds: 8,
            presenter: .console
        )
        #expect(warningOnly.hasErrors == false)

        let withError = GradeResult(
            passed: false,
            diagnostics: [
                .init(severity: .warning, message: "사용하지 않는 변수 a"),
                .init(file: "main.swift", line: 3, severity: .error, message: "cannot find 'b' in scope"),
            ],
            durationMilliseconds: 8,
            presenter: .console
        )
        #expect(withError.hasErrors)
    }
}
