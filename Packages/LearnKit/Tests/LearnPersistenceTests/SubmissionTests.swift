import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("submission — 제출 이력과 정규화된 진단")
struct SubmissionTests {
    /// `{#m003-submission}` 의 완료 기준.
    @Test("GradeResult 하나가 submission 1행 + diagnostic N행으로 원자적으로 기록된다",
          arguments: DatabaseFlavor.allCases)
    func gradeResultBecomesOneSubmissionAndNDiagnostics(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let result = GradeResult(
            passed: false,
            tests: [.init(name: "합계가 맞는가", passed: false, message: "3 이 아니라 4")],
            diagnostics: [
                .init(file: "main.py", line: 3, column: 5, severity: .error, message: "NameError: b"),
                .init(severity: .warning, message: "사용하지 않는 import"),
                .init(file: "main.py", line: 9, severity: .note, message: "여기서 정의됨", ruleID: "F821"),
            ],
            stdout: "부분 출력\n",
            stderr: "Traceback...\n",
            exitCode: 1,
            durationMilliseconds: 87,
            presenter: .console
        )
        let record = SubmissionRecord(
            grading: result,
            packID: PackID("pack-python-core"),
            lessonID: LessonID("py-lesson-01"),
            blockIndex: 3,
            languageID: .python,
            submittedAt: Fixture.epoch,
            sourceCode: "print(a + b)",
            runnerBackend: .subprocess,
            toolchainVersion: "python3-3.13.12"
        )

        let id = try await harness.database.submissionStore.record(record)

        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM submission") == 1)
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM diagnostic") == 3)

        let fetched = try #require(await harness.database.submissionStore.submission(id: id))
        #expect(fetched.passed == false)
        #expect(fetched.failureKind == .compileError) // error 진단이 있으므로
        #expect(fetched.exitCode == 1)
        #expect(fetched.presenter == .console)
        #expect(fetched.runnerBackend == .subprocess)
        #expect(fetched.toolchainVersion == "python3-3.13.12")
        // ordinal 이 배열 순서를 보존한다.
        #expect(fetched.diagnostics == result.diagnostics)
    }

    @Test("진단 삽입이 실패하면 제출 행도 남지 않는다 (원자성)", arguments: DatabaseFlavor.allCases)
    func failedDiagnosticRollsBackSubmission(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        // line 은 1-기반이어야 한다 — CHECK 가 0 을 거부한다.
        let broken = Fixture.submission(
            diagnostics: [.init(file: "main.py", line: 0, severity: .error, message: "잘못된 위치")]
        )
        await #expect(throws: StoreError.self) {
            try await harness.database.submissionStore.record(broken)
        }
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM submission") == 0)
        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM diagnostic") == 0)
    }

    // MARK: - {#submission-columns}

    @Test("presenter CHECK 도메인이 GradeResult.Presenter rawValue 4종과 정확히 일치한다")
    func presenterDomainMatchesEnum() throws {
        let harness = try TestDatabase(.inMemory)
        let domain = try Self.checkDomain(named: "chk_submission_presenter", in: harness.database)

        // GradeResult.Presenter 는 CaseIterable 이 아니라 여기서 손으로 나열한다.
        // (이 목록이 낡으면 아래 "저장/조회" 테스트가 잡아준다.)
        let presenters: [GradeResult.Presenter] = [.console, .table, .browser, .registers]
        #expect(domain == Set(presenters.map(\.rawValue)))
        #expect(domain.count == 4)
    }

    @Test("runner_backend / failure_kind CHECK 도메인이 열거형 allCases 와 일치한다")
    func backendAndFailureDomainsMatchEnums() throws {
        let harness = try TestDatabase(.inMemory)
        #expect(
            try Self.checkDomain(named: "chk_submission_runner_backend", in: harness.database)
                == Set(RunnerBackend.allCases.map(\.rawValue))
        )
        #expect(
            try Self.checkDomain(named: "chk_submission_failure_kind", in: harness.database)
                == Set(SubmissionFailureKind.allCases.map(\.rawValue))
        )
    }

    @Test("네 프리젠터 전부 저장·조회된다", arguments: DatabaseFlavor.allCases)
    func allPresentersRoundTrip(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let presenters: [GradeResult.Presenter] = [.console, .table, .browser, .registers]
        for (index, presenter) in presenters.enumerated() {
            var record = Fixture.submission(block: index, passed: true)
            record.presenter = presenter
            let id = try await harness.database.submissionStore.record(record)
            #expect(try await harness.database.submissionStore.submission(id: id)?.presenter == presenter)
        }
    }

    @Test("통과한 제출은 failure_kind 가 반드시 nil 이다")
    func passedSubmissionCannotCarryFailureKind() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO submission
                    (pack_id, lesson_id, block_index, language_id, submitted_at, passed,
                     source_code, stdout, stderr, duration_ms, presenter, runner_backend, failure_kind)
                VALUES ('p', 'l', 0, 'python', 1, 1, '', '', '', 0, 'console', 'subprocess', 'testFailure')
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    // MARK: - {#submission-retention}

    @Test("stdout·stderr 는 쓰기 시점에 64KB 로 잘린다", arguments: DatabaseFlavor.allCases)
    func outputIsTruncatedAt64KB(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        // 한글은 UTF-8 3바이트라 문자 수와 바이트 수가 다르다 — 절단이 바이트 기준인지 확인된다.
        let flood = String(repeating: "가", count: 60_000) // 180,000 바이트
        let record = Fixture.submission(stdout: flood, stderr: flood)

        let id = try await harness.database.submissionStore.record(record)
        let fetched = try #require(await harness.database.submissionStore.submission(id: id))

        #expect(fetched.stdout.utf8.count <= PersistenceLimits.submissionOutputBytes)
        #expect(fetched.stderr.utf8.count <= PersistenceLimits.submissionOutputBytes)
        // 64KB 는 3바이트 문자 21845개 + 1바이트 — 문자 경계에서 잘리므로 21845자.
        #expect(fetched.stdout.count == 21_845)
        #expect(flood.hasPrefix(fetched.stdout), "잘린 값이 원본의 접두사가 아니다")

        // 실행 상한(1MiB)과 저장 상한(64KiB)은 다른 값이다.
        #expect(PersistenceLimits.submissionOutputBytes == 64 * 1024)
        #expect(PersistenceLimits.submissionOutputBytes != 1 << 20)
    }

    @Test("64KB 미만 출력은 손대지 않는다", arguments: DatabaseFlavor.allCases)
    func shortOutputIsUntouched(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let text = "hello\nworld\n"
        let id = try await harness.database.submissionStore.record(
            Fixture.submission(stdout: text)
        )
        #expect(try await harness.database.submissionStore.submission(id: id)?.stdout == text)
    }

    @Test("실패 제출은 레슨·블록당 최근 20건만 남는다", arguments: DatabaseFlavor.allCases)
    func failedSubmissionsAreCappedAt20(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.submissionStore

        var ids: [SubmissionID] = []
        for attempt in 0..<25 {
            ids.append(try await store.record(
                Fixture.submission(passed: false, stdout: "attempt \(attempt)")
            ))
        }

        let remaining = try await store.recent(
            packID: PackID("pack-python-core"),
            lessonID: LessonID("py-lesson-01"),
            blockIndex: 3,
            limit: 100
        )
        #expect(remaining.count == PersistenceLimits.failedSubmissionRetention)
        // 남은 것은 **최근** 20건이어야 한다.
        #expect(remaining.first?.stdout == "attempt 24")
        #expect(remaining.last?.stdout == "attempt 5")
        // 잘려나간 제출의 진단도 CASCADE 로 사라진다.
        #expect(try await store.submission(id: ids[0]) == nil)
    }

    @Test("보존 정리는 다른 레슨·블록을 건드리지 않는다", arguments: DatabaseFlavor.allCases)
    func retentionIsScopedToLessonBlock(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.submissionStore

        let otherBlock = try await store.record(Fixture.submission(block: 4, passed: false))
        let otherLesson = try await store.record(
            Fixture.submission(lesson: "py-lesson-02", passed: false)
        )
        for _ in 0..<25 { try await store.record(Fixture.submission(passed: false)) }

        #expect(try await store.submission(id: otherBlock) != nil)
        #expect(try await store.submission(id: otherLesson) != nil)
    }

    @Test("통과 제출은 20건 상한에서 제외된다", arguments: DatabaseFlavor.allCases)
    func passedSubmissionsAreNotPruned(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.submissionStore

        var passedIDs: [SubmissionID] = []
        for _ in 0..<5 { passedIDs.append(try await store.record(Fixture.submission(passed: true))) }
        for _ in 0..<25 { try await store.record(Fixture.submission(passed: false)) }

        for id in passedIDs {
            #expect(try await store.submission(id: id) != nil, "통과 제출이 정리에 휩쓸렸다")
        }
        let all = try await store.recent(
            packID: PackID("pack-python-core"),
            lessonID: LessonID("py-lesson-01"),
            blockIndex: 3,
            limit: 100
        )
        #expect(all.count == 25) // 실패 20 + 통과 5
    }

    @Test("시도 횟수는 submission 집계로 나온다", arguments: DatabaseFlavor.allCases)
    func attemptCountAggregatesSubmissions(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.submissionStore
        for _ in 0..<3 { try await store.record(Fixture.submission(passed: false)) }
        try await store.record(Fixture.submission(passed: true))

        #expect(try await store.attemptCount(
            packID: PackID("pack-python-core"),
            lessonID: LessonID("py-lesson-01"),
            blockIndex: 3
        ) == 4)
        #expect(try await store.attemptCount(
            packID: PackID("pack-python-core"),
            lessonID: LessonID("py-lesson-01"),
            blockIndex: 0
        ) == 0)
    }

    @Test("제출 조회가 인덱스를 타고 SCAN 이 없다", arguments: DatabaseFlavor.allCases)
    func recentQueryUsesIndex(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.queryPlan(for: """
            SELECT * FROM submission
            WHERE pack_id = 'p' AND lesson_id = 'l' AND block_index = 0
            ORDER BY id DESC LIMIT 20
            """)
        #expect(plan.contains { $0.contains("idx_submission_lesson_block") }, "\(plan)")
        #expect(!plan.contains { $0.contains("SCAN") }, "\(plan)")
    }

    // MARK: - 도우미

    /// 골든 스키마에서 CHECK 제약의 문자열 리터럴 집합을 뽑는다.
    private static func checkDomain(named name: String, in database: LearnDatabase) throws -> Set<String> {
        let schema = try database.schemaDump()
        guard let start = schema.range(of: "CONSTRAINT \(name)") else {
            Issue.record("\(name) 제약을 찾지 못했다")
            return []
        }
        // 다음 CONSTRAINT 또는 테이블 끝까지가 이 제약의 본문이다.
        let rest = schema[start.upperBound...]
        let end = rest.range(of: "CONSTRAINT ")?.lowerBound
            ?? rest.range(of: ") STRICT;")?.lowerBound
            ?? rest.endIndex
        let body = String(rest[..<end])

        var literals: Set<String> = []
        var iterator = body.split(separator: "'", omittingEmptySubsequences: false).enumerated()
            .makeIterator()
        while let (index, piece) = iterator.next() {
            // 홀수 번째 조각이 따옴표 안이다.
            if index % 2 == 1 { literals.insert(String(piece)) }
        }
        return literals
    }
}
