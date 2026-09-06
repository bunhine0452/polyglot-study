import Foundation
import Darwin
import LanguageKit
import LearnCore
@testable import RunnerKit

/// 서브프로세스 백엔드 테스트가 공유하는 관측 도구.
enum SubprocessTestSupport {
    /// 테스트용 `SubprocessRunner` 설정. 런처는 빌드 산출물에서 찾는다.
    static func configuration(workspaceContainer: URL? = nil) throws -> SubprocessRunnerConfiguration {
        SubprocessRunnerConfiguration(
            launcherPath: try ToolchainLauncherHarness.locateLauncher(),
            workspaceContainer: workspaceContainer
        )
    }

    static func runner(
        program: any SubprocessProgram,
        workspaceContainer: URL? = nil
    ) throws -> SubprocessRunner {
        SubprocessRunner(program: program, configuration: try configuration(workspaceContainer: workspaceContainer))
    }

    /// 실행 하나에서 관측한 것 전부.
    struct Observation {
        var stdout = Data()
        var stderr = Data()
        var phases: [RunPhase] = []
        var diagnostics: [Diagnostic] = []
        var truncated = false
        var truncatedCount = 0
        var termination: RunTermination?
        var failure: RunFailure?
        var otherError: String?
        var elapsed: Duration = .zero

        var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
        var stderrText: String { String(decoding: stderr, as: UTF8.self) }

        var longestLineBytes: Int {
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
    }

    static func observe(_ runner: some CodeRunner, _ request: RunRequest) async -> Observation {
        var observation = Observation()
        let clock = ContinuousClock()
        let started = clock.now
        do {
            for try await event in runner.run(request) {
                switch event {
                case .phase(let phase): observation.phases.append(phase)
                case .standardOutput(let data): observation.stdout.append(data)
                case .standardError(let data): observation.stderr.append(data)
                case .diagnostic(let diagnostic): observation.diagnostics.append(diagnostic)
                case .resultSet: break
                case .truncated:
                    observation.truncated = true
                    observation.truncatedCount += 1
                case .finished(let termination): observation.termination = termination
                }
            }
        } catch let failure as RunFailure {
            observation.failure = failure
        } catch {
            observation.otherError = "\(error)"
        }
        observation.elapsed = started.duration(to: clock.now)
        return observation
    }
}

/// 컴파일러를 도는 실측 테스트가 **한꺼번에** 코어를 다 가져가지 않게 하는 문지기.
///
/// swift-testing 은 스위트를 병렬로 돌린다. 이 타깃에는 벽시계 예산이 걸린 순수 CPU
/// 벤치마크가 있고(`SQLResultDiffTests` 의 1만 행 diff — 유휴 시 22ms, 상한 100ms),
/// swiftc·SwiftPM 을 서너 갈래로 동시에 돌리면 그 측정이 5배로 늘어져 **남의 테스트가
/// 깨진다**. 컴파일 계열만 직렬로 묶어 최대 부하를 낮춘다 — 전체 시간은 조금 늘지만
/// 병렬 스위트에서 시간을 재는 테스트가 무의미해지는 것보다 낫다.
actor CompilerLoadGate {
    static let shared = CompilerLoadGate()

    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func withAccess<T>(_ body: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await body()
    }

    private func acquire() async {
        guard busy else {
            busy = true
            return
        }
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }

    private func release() {
        if waiting.isEmpty {
            busy = false
        } else {
            waiting.removeFirst().resume()
        }
    }
}
