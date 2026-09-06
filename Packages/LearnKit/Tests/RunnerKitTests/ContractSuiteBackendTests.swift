import Testing
import Foundation
import Darwin
import LanguageKit
import LearnCore
@testable import RunnerKit

/// 계약 스위트를 **두 백엔드**에 전부 통과시킨다.
///
/// 플랜 문구는 "세 백엔드"지만 에뮬레이터 백엔드는 Assembly 트랙과 함께 나중이다.
/// 지금 실재하는 것은 인프로세스(SQL)와 서브프로세스(Python·Swift) 둘이고,
/// 완료 기준은 그 둘로 읽는다.
///
/// 인프로세스 쪽은 여기서 다시 돌리지 않는다 — `ContractHarnessTests` 가 이미 같은
/// 스위트를 같은 단언으로 돌린다. 한 번 더 돌리면 무한 재귀 CTE 두 벌이 **동시에**
/// 코어를 태워, 같은 타깃에서 시간을 재는 다른 테스트를 흔든다.
@Suite("계약 스위트 — 서브프로세스 백엔드", .serialized)
struct ContractSuiteBackendTests {

    @Test("Subprocess 백엔드가 Python 계약 스위트를 통과한다", .timeLimit(.minutes(5)))
    func subprocessPythonBackend() async throws {
        let runner = try SubprocessTestSupport.runner(program: PythonProgram())
        let report = await RunnerContractTests(
            runner: runner,
            language: .python,
            catalog: AdjustedContractCatalog.shared,
            backendName: "SubprocessRunner(python)"
        ).run()
        #expect(report.isSatisfied, "\n\(report.summary)")
        // 전부 skip 되면 통과처럼 보인다. Python 은 13 케이스 전부를 실제로 돈다.
        #expect(report.passed.count == 13, "\n\(report.summary)")
    }

    @Test("Subprocess 백엔드가 Swift 계약 스위트를 통과한다", .timeLimit(.minutes(6)))
    func subprocessSwiftBackend() async throws {
        let runner = try SubprocessTestSupport.runner(program: SwiftProgram())
        // 12 개 픽스처를 전부 컴파일한다 — 다른 스위트의 시간 측정과 겹치지 않게 묶는다.
        let report = await CompilerLoadGate.shared.withAccess {
            await RunnerContractTests(
                runner: runner,
                language: .swift,
                catalog: AdjustedContractCatalog.shared,
                backendName: "SubprocessRunner(swift)"
            ).run()
        }
        #expect(report.isSatisfied, "\n\(report.summary)")
        // Swift 픽스처는 fork bomb 만 없다 — `os.fork()` 에 대응하는 한 줄짜리
        // 표현이 Swift 에는 없어서 카탈로그가 아예 두지 않았다.
        #expect(report.passed.count == 12, "\n\(report.summary)")
        #expect(report.skipped.map(\.id) == [.forkBomb], "\n\(report.summary)")
    }

    @Test("서브프로세스 러너는 여섯 축 상한을 전부 강제한다고 선언한다")
    func subprocessDeclaresAllLimits() throws {
        let python = try SubprocessTestSupport.runner(program: PythonProgram())
        #expect(python.enforcedLimits == .all)
        let pythonSupport = ContractSupport.inferred(from: python)
        // 상한 여섯 축 + stdin. 진단은 컴파일 단계가 없는 언어에는 없다.
        #expect(pythonSupport == ContractSupport.all.subtracting(.diagnostics))
        #expect(pythonSupport.contains(.standardInput))
        #expect(pythonSupport.contains(.processIsolation))

        let swift = try SubprocessTestSupport.runner(program: SwiftProgram())
        #expect(swift.enforcedLimits == .all)
        #expect(ContractSupport.inferred(from: swift) == .all)
    }

    // MARK: - 병렬·누수

    @Test("8 개 동시 실행이 서로 간섭하지 않는다", .timeLimit(.minutes(2)))
    func eightConcurrentRunsDoNotInterfere() async throws {
        let configuration = try SubprocessTestSupport.configuration()
        let answers = await withTaskGroup(of: (Int, String, String).self) { group in
            for index in 0..<8 {
                group.addTask {
                    let runner = SubprocessRunner(
                        program: PythonProgram(),
                        configuration: configuration
                    )
                    let source = """
                        import sys
                        data = sys.stdin.read().strip()
                        print("%s:%d" % (data, \(index) * 7))
                        """
                    let observation = await SubprocessTestSupport.observe(
                        runner,
                        RunRequest(
                            files: [SourceFile(path: "main.py", contents: source)],
                            standardInput: Data("in-\(index)".utf8),
                            limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30)
                        )
                    )
                    let detail = "실패=\(String(describing: observation.failure))"
                        + " 종료=\(String(describing: observation.termination))"
                        + " 소요=\(observation.elapsed)"
                        + " stderr=\(observation.stderrText)"
                    return (
                        index,
                        observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines),
                        detail
                    )
                }
            }
            var collected: [(Int, String, String)] = []
            for await value in group { collected.append(value) }
            return collected
        }

        #expect(answers.count == 8)
        for (index, text, detail) in answers {
            #expect(text == "in-\(index):\(index * 7)", "\(index) 번 실행: '\(text)' — \(detail)")
            // 동시 실행이 서로를 직렬화하거나 런처 회수가 지연되면 여기가 먼저 깨진다.
            #expect(!detail.contains("소요=2") && !detail.contains("소요=3"),
                    "\(index) 번이 지나치게 오래 걸렸다 — \(detail)")
        }
    }

    @Test("fork bomb 실행 후 잔존 프로세스가 0 이다", .timeLimit(.minutes(2)))
    func forkBombLeavesNothingBehind() async throws {
        let groups = ObservedProcessGroups()
        var configuration = try SubprocessTestSupport.configuration()
        configuration.processGroupObserver = { groups.record($0) }
        let runner = SubprocessRunner(program: PythonProgram(), configuration: configuration)

        let fixture = try #require(AdjustedContractCatalog.shared[.python, .forkBomb])
        let observation = await SubprocessTestSupport.observe(runner, fixture.request)
        #expect(observation.elapsed < .seconds(15))

        let group = try #require(groups.first)
        #expect(
            ProcessGroupReaper.waitForVanish(processGroup: group, within: .seconds(5)),
            "잔존 \(ProcessGroupMemory.members(ofProcessGroup: group).count) 개"
        )
    }

    @Test("손자 프로세스 실행 후 잔존 프로세스가 0 이다", .timeLimit(.minutes(2)))
    func grandchildLeavesNothingBehind() async throws {
        let groups = ObservedProcessGroups()
        var configuration = try SubprocessTestSupport.configuration()
        configuration.processGroupObserver = { groups.record($0) }
        let runner = SubprocessRunner(program: PythonProgram(), configuration: configuration)

        let fixture = try #require(AdjustedContractCatalog.shared[.python, .grandchildProcess])
        let observation = await SubprocessTestSupport.observe(runner, fixture.request)
        #expect(observation.stdoutText.contains("spawned"))

        let group = try #require(groups.first)
        #expect(
            ProcessGroupReaper.waitForVanish(processGroup: group, within: .seconds(5)),
            "잔존 \(ProcessGroupMemory.members(ofProcessGroup: group).count) 개"
        )
    }
}

/// 표준 카탈로그를 그대로 쓰되 **모순된 상한 하나**만 고친 사본.
///
/// `infinite-loop` 픽스처는 Python·Swift 둘 다 `wallClockSeconds: 2, cpuSeconds: 1`
/// 로 두고 `.fails(.wallClockExceeded)` 를 기대한다. 그런데 바쁜 루프는 CPU 1초를
/// 벽시계 1초 만에 태우므로 **rlimit 을 실제로 거는 백엔드에서는 SIGXCPU 가 먼저
/// 온다** — 즉 그 픽스처는 자기가 기대하는 것과 반대되는 것을 재고 있다.
/// (인프로세스 백엔드는 CPU 상한을 걸 수단이 없어 이 모순이 드러나지 않았다.)
///
/// 픽스처는 `Sources/RunnerKit/Contract/**` 소관이라 여기서 고치지 않고, 계약 스위트를
/// 돌릴 때만 CPU 상한을 벽시계보다 넉넉하게 올려 **케이스의 의도**(무한 루프가 데드라인
/// 안에 멈추는가)를 보존한다. 계약 자체의 수정은 보고로 올린다.
enum AdjustedContractCatalog {
    static let shared: ContractFixtureCatalog = {
        let standard = ContractFixtureCatalog.standard
        var fixtures: [ContractFixture] = []
        for language in standard.languages.sorted(by: { $0.rawValue < $1.rawValue }) {
            for var fixture in standard.fixtures(for: language) {
                if fixture.caseID == .infiniteLoop {
                    fixture.limits.cpuSeconds = max(
                        fixture.limits.cpuSeconds,
                        fixture.limits.wallClockSeconds * 10
                    )
                }
                if fixture.caseID == .fileSizeFlood, language == .python {
                    fixture.files = [SourceFile(path: "main.py", contents: Self.pythonFileSizeFlood)]
                }
                fixtures.append(fixture)
            }
        }
        return ContractFixtureCatalog(fixtures)
    }()

    /// `{#python-grade}` 와 무관한, 계약 스위트만의 보정.
    ///
    /// **CPython 은 시작할 때 `SIGXFSZ` 를 `SIG_IGN` 으로 덮는다.** 그래서 표준
    /// 픽스처(`open`+무한 `write`)는 `RLIMIT_FSIZE` 를 넘겨도 죽지 않고 `OSError:
    /// [Errno 27] File too large` 를 던지며 종료코드 1 로 끝난다 — 백엔드가 볼 수
    /// 있는 것은 그 1 뿐이라 `fileSizeExceeded` 로 접을 근거가 없다.
    /// 상한 자체는 **정상 작동한다**(파일이 딱 상한에서 멈춘다). 케이스가 재려는 것이
    /// "SIGXFSZ 를 fileSizeExceeded 로 접는가" 이므로, 인터프리터가 덮어쓴 처리를
    /// 되돌려 놓고 잰다. 픽스처 자체의 수정은 보고로 올린다.
    static let pythonFileSizeFlood = """
        import signal
        signal.signal(signal.SIGXFSZ, signal.SIG_DFL)
        with open('big.bin', 'wb') as f:
            while True:
                f.write(b'x' * (1 << 20))
                f.flush()
        """
}
