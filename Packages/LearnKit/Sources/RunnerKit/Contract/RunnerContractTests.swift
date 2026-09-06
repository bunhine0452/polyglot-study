public import Foundation
public import LanguageKit
public import LearnCore

/// 실행 한 번에서 관측한 것 전부.
public struct ContractObservation: Sendable {
    public var stdout = Data()
    public var stderr = Data()
    public var diagnostics: [Diagnostic] = []
    public var phases: [RunPhase] = []
    public var truncated = false
    /// `RunEvent.resultSet` 으로 흘러온 구조화된 표들.
    public var resultSets: [ResultSet] = []
    public var termination: RunTermination?
    public var failureKind: ContractFailureKind?
    public var failureDescription: String?
    public var elapsedMilliseconds = 0
    /// 취소를 건 뒤 실제로 끝날 때까지 걸린 시간.
    public var cancellationReactionMilliseconds: Int?

    public init() {}

    /// 개행으로 끊기지 않은 가장 긴 구간의 바이트 수.
    public var longestLineBytes: Int {
        var longest = 0
        var current = 0
        for byte in stdout {
            if byte == 0x0A {
                longest = max(longest, current)
                current = 0
            } else {
                current += 1
            }
        }
        return max(longest, current)
    }

    public var stdoutIsValidUTF8: Bool { String(data: stdout, encoding: .utf8) != nil }
}

public enum ContractOutcome: Hashable, Sendable {
    case passed
    case skipped(String)
    case failed(String)

    public var isFailure: Bool { if case .failed = self { true } else { false } }
    public var isSkipped: Bool { if case .skipped = self { true } else { false } }
}

public struct ContractCaseResult: Hashable, Sendable {
    public var id: ContractCaseID
    public var title: String
    public var outcome: ContractOutcome
    public var durationMilliseconds: Int
}

public struct ContractReport: Hashable, Sendable {
    public var backend: String
    public var language: LanguageID
    public var results: [ContractCaseResult]

    public var failures: [ContractCaseResult] { results.filter { $0.outcome.isFailure } }
    public var skipped: [ContractCaseResult] { results.filter { $0.outcome.isSkipped } }
    public var passed: [ContractCaseResult] { results.filter { $0.outcome == .passed } }
    public var isSatisfied: Bool { failures.isEmpty }

    public var summary: String {
        var lines = ["\(backend) / \(language.rawValue): "
            + "통과 \(passed.count) · 실패 \(failures.count) · skip \(skipped.count)"]
        for result in results {
            switch result.outcome {
            case .passed: lines.append("  ✓ \(result.id) — \(result.title) (\(result.durationMilliseconds)ms)")
            case .skipped(let reason): lines.append("  – \(result.id) — skip: \(reason)")
            case .failed(let reason): lines.append("  ✗ \(result.id) — \(reason)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// 모든 `CodeRunner` 백엔드가 통과해야 하는 공용 계약 스위트.
///
/// 테스트 프레임워크를 모른다 — 결과를 `ContractReport` 로 돌려주고, 단언은 호출하는
/// 테스트 타깃이 한다. 그래야 인프로세스·서브프로세스·에뮬레이터가 각자 다른 테스트
/// 타깃에 있어도 **같은 스위트 한 벌**을 공유할 수 있다.
///
/// 지원하지 않는다고 선언한 케이스(`ContractSupport`)와 그 언어의 픽스처가 없는 케이스는
/// 실패가 아니라 skip 이다 — 인프로세스 SQL 러너에 stdin 을 요구하면 계약이 아니라 잡음이다.
public struct RunnerContractTests: Sendable {
    public let runner: any CodeRunner
    public let language: LanguageID
    public let support: ContractSupport
    public let catalog: ContractFixtureCatalog
    public let backendName: String
    /// 백엔드가 아예 멈춰버려도 스위트가 끝나도록 거는 상한.
    public var safetyMarginSeconds: Int = 20

    public init(
        runner: any CodeRunner,
        language: LanguageID,
        support: ContractSupport? = nil,
        catalog: ContractFixtureCatalog = .standard,
        backendName: String? = nil
    ) {
        self.runner = runner
        self.language = language
        self.support = support ?? ContractSupport.inferred(from: runner)
        self.catalog = catalog
        self.backendName = backendName ?? String(describing: type(of: runner))
    }

    public static let allCases: [ContractCase] = [
        ContractCase(id: .timeout, title: "벽시계 타임아웃", requires: .wallClockTimeout),
        ContractCase(id: .infiniteLoop, title: "무한 루프 정지", requires: .infiniteLoopTermination),
        ContractCase(id: .outputFlood, title: "출력 폭주 절단", requires: .outputTruncation),
        ContractCase(id: .hugeSingleLine, title: "거대 단일행 전달", requires: .hugeSingleLine),
        ContractCase(id: .nonUTF8Output, title: "비UTF8 출력 보존", requires: .nonUTF8Output),
        ContractCase(id: .cancellation, title: "취소 반응", requires: .cancellation),
        ContractCase(id: .exitCode, title: "종료 상태 보고", requires: .terminationStatus),
        ContractCase(id: .standardInput, title: "stdin 연결", requires: .standardInput),
        ContractCase(id: .forkBomb, title: "fork bomb 봉쇄", requires: .processIsolation),
        ContractCase(id: .grandchildProcess, title: "손자 프로세스 회수", requires: .processIsolation),
        ContractCase(id: .cpuExhaustion, title: "CPU 시간 소진", requires: .cpuTimeLimit),
        ContractCase(id: .memoryExhaustion, title: "메모리 상한", requires: .memoryLimit),
        ContractCase(id: .fileSizeFlood, title: "파일 크기 상한", requires: .fileSizeLimit),
    ]

    public func run(only: Set<ContractCaseID>? = nil) async -> ContractReport {
        var results: [ContractCaseResult] = []
        for contractCase in Self.allCases {
            if let only, !only.contains(contractCase.id) { continue }
            results.append(await run(contractCase))
        }
        return ContractReport(backend: backendName, language: language, results: results)
    }

    private func run(_ contractCase: ContractCase) async -> ContractCaseResult {
        guard support.contains(contractCase.requires) else {
            return ContractCaseResult(
                id: contractCase.id,
                title: contractCase.title,
                outcome: .skipped("백엔드가 \(missingSupportNames(contractCase.requires)) 를 지원하지 않음"),
                durationMilliseconds: 0
            )
        }
        guard let fixture = catalog[language, contractCase.id] else {
            return ContractCaseResult(
                id: contractCase.id,
                title: contractCase.title,
                outcome: .skipped("\(language.rawValue) 픽스처 없음"),
                durationMilliseconds: 0
            )
        }

        let cancelAfter = fixture.expectations.compactMap { expectation -> Int? in
            if case .cancelsWithin = expectation { return 300 }
            return nil
        }.first

        let observation = await observe(fixture, cancelAfterMilliseconds: cancelAfter)

        var problems: [String] = []
        for expectation in fixture.expectations {
            if let problem = evaluate(expectation, observation) { problems.append(problem) }
        }
        return ContractCaseResult(
            id: contractCase.id,
            title: contractCase.title,
            outcome: problems.isEmpty ? .passed : .failed(problems.joined(separator: "; ")),
            durationMilliseconds: observation.elapsedMilliseconds
        )
    }

    private func missingSupportNames(_ required: ContractSupport) -> String {
        let names = required.subtracting(support).names
        return names.isEmpty ? "필요 기능" : names.joined(separator: "+")
    }

    // MARK: - 관측

    private func observe(_ fixture: ContractFixture, cancelAfterMilliseconds: Int?) async -> ContractObservation {
        let request = fixture.request
        let safety = fixture.limits.wallClockSeconds + safetyMarginSeconds

        guard let cancelAfter = cancelAfterMilliseconds else {
            return await withSafetyTimeout(seconds: safety) {
                await Self.collect(runner: runner, request: request)
            }
        }

        // 취소 케이스는 소비자 Task 를 밖에서 잡고 있어야 취소를 걸 수 있다.
        let consumer = Task { await Self.collect(runner: runner, request: request) }
        try? await Task.sleep(nanoseconds: UInt64(cancelAfter) * 1_000_000)
        let cancelInstant = DispatchTime.now()
        consumer.cancel()

        var observation = await withSafetyTimeout(seconds: safety) { await consumer.value }
        observation.cancellationReactionMilliseconds =
            Int((DispatchTime.now().uptimeNanoseconds &- cancelInstant.uptimeNanoseconds) / 1_000_000)
        return observation
    }

    private func withSafetyTimeout(
        seconds: Int,
        _ body: @escaping @Sendable () async -> ContractObservation
    ) async -> ContractObservation {
        await withTaskGroup(of: ContractObservation?.self) { group in
            group.addTask { await body() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                return nil
            }
            var timedOut = ContractObservation()
            timedOut.failureKind = .other
            timedOut.failureDescription = "하네스 안전 타임아웃 \(seconds)초 초과"
            timedOut.elapsedMilliseconds = seconds * 1_000
            var observation = timedOut
            for await value in group {
                if let value { observation = value }
                group.cancelAll()
                break
            }
            return observation
        }
    }

    private static func collect(runner: any CodeRunner, request: RunRequest) async -> ContractObservation {
        var observation = ContractObservation()
        let started = DispatchTime.now()
        do {
            for try await event in runner.run(request) {
                switch event {
                case .phase(let phase):
                    observation.phases.append(phase)
                case .standardOutput(let data):
                    observation.stdout.append(data)
                case .standardError(let data):
                    observation.stderr.append(data)
                case .diagnostic(let diagnostic):
                    observation.diagnostics.append(diagnostic)
                case .resultSet(let set):
                    observation.resultSets.append(set)
                case .truncated:
                    observation.truncated = true
                case .finished(let termination):
                    observation.termination = termination
                }
            }
        } catch {
            observation.failureKind = ContractFailureKind(error)
            observation.failureDescription = "\(error)"
        }
        observation.elapsedMilliseconds =
            Int((DispatchTime.now().uptimeNanoseconds &- started.uptimeNanoseconds) / 1_000_000)
        return observation
    }

    // MARK: - 판정

    private func evaluate(_ expectation: ContractExpectation, _ observation: ContractObservation) -> String? {
        switch expectation {
        case .finishes(let expected):
            if let kind = observation.failureKind {
                return "\(Self.describe(expected)) 를 기대했는데 \(kind.rawValue) 로 실패 (\(observation.failureDescription ?? ""))"
            }
            guard let termination = observation.termination else {
                return "finished 이벤트가 오지 않았습니다"
            }
            switch (expected, termination.status) {
            case (.succeeded, .succeeded):
                return nil
            case (.failed(let wanted), .failed(let actual)):
                // 기대한 코드가 nil 이면 "실패했다"는 사실만 본다 — 종료 코드가 없는
                // 백엔드도 같은 픽스처를 통과해야 하기 때문이다.
                guard let wanted else { return nil }
                return wanted == actual
                    ? nil
                    : "종료코드 \(wanted) 를 기대했는데 \(actual.map(String.init) ?? "코드 없음")"
            default:
                return "\(Self.describe(expected)) 를 기대했는데 \(Self.describe(termination.status))"
            }

        case .fails(let kind):
            guard let actual = observation.failureKind else {
                let status = observation.termination.map { Self.describe($0.status) } ?? "무응답"
                return "\(kind.rawValue) 실패를 기대했는데 \(status)"
            }
            return actual == kind ? nil : "\(kind.rawValue) 를 기대했는데 \(actual.rawValue) (\(observation.failureDescription ?? ""))"

        case .cancelsWithin(let milliseconds):
            guard let reaction = observation.cancellationReactionMilliseconds else {
                return "취소를 걸지 않았습니다 (하네스 오류)"
            }
            if observation.termination != nil, observation.failureKind == nil {
                return "취소했는데 정상 완료했습니다"
            }
            return reaction <= milliseconds ? nil : "취소 반응이 \(reaction)ms — 상한 \(milliseconds)ms"

        case .truncatesOutput:
            return observation.truncated ? nil : "출력이 잘리지 않았습니다 (stdout \(observation.stdout.count)바이트)"

        case .emitsNonUTF8Output:
            return observation.stdoutIsValidUTF8 ? "stdout 이 전부 유효한 UTF-8 입니다" : nil

        case .emitsLine(let atLeastBytes):
            let longest = observation.longestLineBytes
            return longest >= atLeastBytes ? nil : "가장 긴 줄이 \(longest)바이트 — \(atLeastBytes) 이상 기대"

        case .stdoutContains(let needle):
            let haystack = String(decoding: observation.stdout, as: UTF8.self)
            return haystack.contains(needle) ? nil : "stdout 에 '\(needle)' 가 없습니다"

        case .emitsErrorDiagnostic(let containing):
            let errors = observation.diagnostics.filter { $0.severity == .error }
            guard !errors.isEmpty else { return "error 진단이 없습니다" }
            guard let containing else { return nil }
            return errors.contains { $0.message.contains(containing) }
                ? nil
                : "'\(containing)' 를 담은 error 진단이 없습니다 (받은 것: \(errors.map(\.message)))"

        case .emitsResultSet(let rows, let columns):
            guard let set = observation.resultSets.first else {
                return "resultSet 이벤트가 오지 않았습니다"
            }
            if observation.resultSets.count != 1 {
                return "resultSet 이벤트가 \(observation.resultSets.count)번 왔습니다 — 1번 기대"
            }
            if set.rowCount != rows || set.columnCount != columns {
                return "결과셋이 \(set.rowCount)행 \(set.columnCount)열 — \(rows)행 \(columns)열 기대"
            }
            return nil

        case .completesWithin(let milliseconds):
            return observation.elapsedMilliseconds <= milliseconds
                ? nil
                : "\(observation.elapsedMilliseconds)ms 걸렸습니다 — 상한 \(milliseconds)ms"
        }
    }
}

/// 실패 메시지용 문구. 종료 상태는 세 갈래(성공·코드 있는 실패·코드 없는 실패)라
/// 기본 문자열 보간으로는 무엇이 어긋났는지 읽히지 않는다.
extension RunnerContractTests {
    static func describe(_ expectation: TerminationExpectation) -> String {
        switch expectation {
        case .succeeded: "성공 종료"
        case .failed(let code): code.map { "실패 종료(코드 \($0))" } ?? "실패 종료"
        }
    }

    static func describe(_ status: RunTermination.Status) -> String {
        switch status {
        case .succeeded: "성공 종료"
        case .failed(let code): code.map { "실패 종료(코드 \($0))" } ?? "실패 종료(코드 없음)"
        }
    }
}
