import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// `{#core-contracts}` `{#repo-protocols}` — DTO·프로토콜은 LearnCore 에 있고 GRDB 를 모른다.
@Suite("LearnCore 영속화 계약")
struct CoreContractTests {
    @Test("리포지토리 프로토콜 5종을 GRDB 구현과 인메모리 페이크가 모두 만족한다")
    func bothImplementationsSatisfyTheProtocols() throws {
        let harness = try TestDatabase(.inMemory)
        let fakes = InMemoryStores()

        // 프로토콜 타입으로만 담긴다는 것 자체가 계약 충족의 증거다.
        let real: [Any] = [
            harness.database.reviewLogStore as any ReviewLogStore,
            harness.database.cardStateStore as any CardStateStore,
            harness.database.submissionStore as any SubmissionStore,
            harness.database.mistakeNoteStore as any MistakeNoteStore,
            harness.database.lessonProgressStore as any LessonProgressStore,
        ]
        let fake: [Any] = [
            fakes.reviewLog as any ReviewLogStore,
            fakes.cardState as any CardStateStore,
            fakes.submissions as any SubmissionStore,
            fakes.mistakeNotes as any MistakeNoteStore,
            fakes.lessonProgress as any LessonProgressStore,
        ]
        #expect(real.count == 5)
        #expect(fake.count == 5)
    }

    /// 두 구현이 **같은 시나리오에서 같은 답**을 내야 한다. 다르면 스케줄링 세션이
    /// 페이크로 짠 로직이 실제 DB 에서 다르게 도는 것이고, 그건 늦게 발견될수록 비싸다.
    @Test("페이크와 GRDB 구현이 같은 시나리오에서 같은 결과를 낸다")
    func fakeAndRealAgree() async throws {
        let harness = try TestDatabase(.inMemory)
        let fakes = InMemoryStores()

        let entries = [
            Fixture.reviewEntry(at: 0, rating: .again, stateBefore: .new),
            Fixture.reviewEntry(at: 1, rating: .good, stateBefore: .learning),
            Fixture.reviewEntry(card: "sql-001", at: 2, rating: .easy, stateBefore: .review),
        ]
        for entry in entries {
            try await harness.database.reviewLogStore.append(entry)
            try await fakes.reviewLog.append(entry)
        }

        #expect(try await harness.database.reviewLogStore.count()
            == fakes.reviewLog.count())

        let realHistory = try await harness.database.reviewLogStore.entries(forCard: CardID("py-001"))
        let fakeHistory = try await fakes.reviewLog.entries(forCard: CardID("py-001"))
        #expect(realHistory == fakeHistory)

        #expect(try await harness.database.reviewLogStore.lastEntryID(forCard: CardID("py-001"))
            == fakes.reviewLog.lastEntryID(forCard: CardID("py-001")))
        #expect(try await harness.database.reviewLogStore.activeParameterSet()
            == fakes.reviewLog.activeParameterSet())

        // 진도 전이도 같은 순수 함수를 쓰므로 같아야 한다.
        for block in 0..<6 {
            let real = try await harness.database.lessonProgressStore.completeBlock(
                packID: PackID("p"), lessonID: LessonID("l"), languageID: .python,
                blockIndex: block, at: Fixture.epoch + Int64(block)
            )
            let fake = try await fakes.lessonProgress.completeBlock(
                packID: PackID("p"), lessonID: LessonID("l"), languageID: .python,
                blockIndex: block, at: Fixture.epoch + Int64(block)
            )
            #expect(real == fake)
        }
    }

    @Test("페이크도 append-only 다 — 수정·삭제 메서드가 아예 없다")
    func fakeIsAppendOnlyByConstruction() async throws {
        let fakes = InMemoryStores()
        try await fakes.reviewLog.append(Fixture.reviewEntry())
        #expect(try await fakes.reviewLog.count() == 1)
        // `ReviewLogStore` 프로토콜에 update/delete 가 없으므로 컴파일 타임에 이미 봉인돼 있다.
        // 여기서 확인하는 것은 append 가 기존 행을 덮지 않는다는 것.
        try await fakes.reviewLog.append(Fixture.reviewEntry(at: 1))
        #expect(try await fakes.reviewLog.count() == 2)
    }

    @Test("페이크도 CHECK 와 같은 이유로 거부한다")
    func fakeRejectsSameInputs() async throws {
        let fakes = InMemoryStores()
        var bad = Fixture.reviewEntry()
        bad.reviewedAt = 0
        await #expect(throws: StoreError.self) { try await fakes.reviewLog.append(bad) }

        var negative = Fixture.reviewEntry()
        negative.elapsedDays = -1
        await #expect(throws: StoreError.self) { try await fakes.reviewLog.append(negative) }

        var unknownSet = Fixture.reviewEntry()
        unknownSet.parameterSetID = ParameterSetID("nope")
        await #expect(throws: StoreError.self) { try await fakes.reviewLog.append(unknownSet) }
    }

    // MARK: - {#submission-retention} 절단 규칙

    @Test("저장 상한은 64KiB 이고 실행 상한(1MiB)과 다르다")
    func storageLimitDiffersFromRuntimeLimit() {
        #expect(PersistenceLimits.submissionOutputBytes == 65_536)
        // LanguageKit.ResourceLimits.outputBytes 는 1 << 20. 여기서 직접 참조할 수 없으므로
        // (LearnCore 는 LanguageKit 을 의존하지 않는다) 값으로 못박는다.
        #expect(PersistenceLimits.submissionOutputBytes * 16 == 1 << 20)
    }

    @Test("절단은 UTF-8 바이트 기준이되 문자 경계를 지킨다")
    func truncationRespectsCharacterBoundaries() {
        // 3바이트 문자.
        let korean = String(repeating: "한", count: 100)
        let cut = PersistenceLimits.truncateForStorage(korean, maxBytes: 10)
        #expect(cut == "한한한")        // 9 바이트. 10 번째 바이트에서 자르면 문자가 깨진다.
        #expect(cut.utf8.count == 9)

        // 4바이트 이모지 + 결합 문자.
        let emoji = String(repeating: "👩‍💻", count: 10)
        let cutEmoji = PersistenceLimits.truncateForStorage(emoji, maxBytes: 12)
        #expect(cutEmoji.utf8.count <= 12)
        #expect(emoji.hasPrefix(cutEmoji))

        // 상한 이하면 그대로.
        #expect(PersistenceLimits.truncateForStorage("short", maxBytes: 64) == "short")
        #expect(PersistenceLimits.truncateForStorage("", maxBytes: 64) == "")
        #expect(PersistenceLimits.truncateForStorage("x", maxBytes: 0) == "")
    }

    @Test("정규화는 stdout·stderr 만 건드린다")
    func normalizationOnlyTouchesOutput() {
        let record = Fixture.submission(
            stdout: String(repeating: "a", count: 100_000),
            stderr: "short"
        )
        let normalized = record.normalizedForStorage()
        #expect(normalized.stdout.utf8.count == PersistenceLimits.submissionOutputBytes)
        #expect(normalized.stderr == "short")
        #expect(normalized.sourceCode == record.sourceCode)
        #expect(normalized.diagnostics == record.diagnostics)
    }

    // MARK: - DTO 계약

    @Test("GradeResult 에서 만든 제출이 채점 결과를 그대로 옮긴다")
    func submissionMirrorsGradeResult() {
        let result = GradeResult(
            passed: true,
            tests: [.init(name: "t", passed: true)],
            stdout: "out",
            stderr: "err",
            exitCode: 0,
            durationMilliseconds: 42,
            presenter: .table
        )
        let record = SubmissionRecord(
            grading: result,
            packID: PackID("p"), lessonID: LessonID("l"), blockIndex: 1,
            languageID: .sql, submittedAt: Fixture.epoch,
            sourceCode: "SELECT 1", runnerBackend: .inProcess
        )
        #expect(record.passed)
        #expect(record.failureKind == nil, "통과한 제출에 실패 종류가 붙었다")
        #expect(record.presenter == .table)
        #expect(record.stdout == "out")
        #expect(record.durationMilliseconds == 42)
    }

    @Test("실패 종류를 명시하면 추론을 덮어쓴다")
    func explicitFailureKindWins() {
        let result = GradeResult(
            passed: false,
            diagnostics: [.init(severity: .error, message: "boom")],
            durationMilliseconds: 1,
            presenter: .console
        )
        let inferred = SubmissionRecord(
            grading: result,
            packID: PackID("p"), lessonID: LessonID("l"), blockIndex: 1,
            languageID: .python, submittedAt: Fixture.epoch,
            sourceCode: "", runnerBackend: .subprocess
        )
        #expect(inferred.failureKind == .compileError)

        let explicit = SubmissionRecord(
            grading: result,
            packID: PackID("p"), lessonID: LessonID("l"), blockIndex: 1,
            languageID: .python, submittedAt: Fixture.epoch,
            sourceCode: "", runnerBackend: .subprocess,
            failureKind: .cpuExceeded
        )
        #expect(explicit.failureKind == .cpuExceeded)
    }

    @Test("완료 블록은 항상 정렬·중복 제거된 상태로 유지된다")
    func completedBlocksStayNormalized() {
        let progress = LessonProgress(
            packID: PackID("p"), lessonID: LessonID("l"), languageID: .swift,
            completedBlocks: [4, 1, 0]
        )
        #expect(progress.completedBlocks == [0, 1, 4])
        #expect(progress.completing(block: 1, at: 1).completedBlocks == [0, 1, 4])
    }

    @Test("stale 판정은 두 원인을 따로 센다")
    func stalenessSeparatesCauses() {
        #expect(!CardStaleness(
            cardID: CardID("c"), languageID: .python, parameterDrift: false, logDrift: false
        ).isStale)
        #expect(CardStaleness(
            cardID: CardID("c"), languageID: .python, parameterDrift: true, logDrift: false
        ).isStale)
        #expect(CardStaleness(
            cardID: CardID("c"), languageID: .python, parameterDrift: false, logDrift: true
        ).isStale)
    }
}
