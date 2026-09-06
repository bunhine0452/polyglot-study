import Testing
import Foundation
@testable import RunnerKit

/// 강등 판정. "조용히 실패하지 않는다"가 이 스위트의 전부다.
@Suite("샌드박스 강등 판정")
struct SandboxPolicyTests {
    static func makeProfile() throws -> (SandboxProfile, URL) {
        let (profile, workspace, _) = try SandboxProfileTests.makeProfile(workspaceName: "policy")
        return (profile, workspace)
    }

    @Test("sandbox-exec 가 있으면 강제한다")
    func enforcesWhenAvailable() throws {
        let (profile, workspace) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let decision = SandboxPolicy.decide(profile: profile, environment: [:], isExecutable: { _ in true })
        #expect(decision.isEnforced)
        #expect(decision.degradation == nil)
        #expect(decision.profile == profile)
    }

    @Test("sandbox-exec 가 없으면 이유를 남기고 강등한다")
    func degradesWhenExecutableMissing() throws {
        let (profile, workspace) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let decision = SandboxPolicy.decide(profile: profile, environment: [:], isExecutable: { _ in false })
        #expect(!decision.isEnforced)
        let degradation = try #require(decision.degradation)
        #expect(degradation.reason == .executableMissing(path: SandboxProfile.executablePath))
        // 강등돼도 무방비가 아니라는 사실이 문장에 남아야 한다.
        #expect(degradation.remainingIsolation.contains("setsid"))
        #expect(degradation.korean.contains("런처 단독 격리"))
    }

    @Test("환경변수 스위치는 참 값에만 반응한다 — 오타로 격리가 풀리면 안 된다")
    func environmentSwitchIsStrict() throws {
        let (profile, workspace) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        for truthy in ["1", "true", "TRUE", "yes", "on"] {
            let decision = SandboxPolicy.decide(
                profile: profile,
                environment: [SandboxPolicy.disableEnvironmentKey: truthy],
                isExecutable: { _ in true }
            )
            #expect(decision.degradation?.reason
                == .disabledByEnvironment(key: SandboxPolicy.disableEnvironmentKey, value: truthy))
        }
        for falsy in ["0", "false", "no", "", "maybe"] {
            let decision = SandboxPolicy.decide(
                profile: profile,
                environment: [SandboxPolicy.disableEnvironmentKey: falsy],
                isExecutable: { _ in true }
            )
            #expect(decision.isEnforced, "\(falsy) 로 샌드박스가 꺼졌다")
        }
    }

    @Test("프로파일 조립 실패도 강등 이유로 잡힌다 — 던지지 않는 진입점")
    func degradesWhenProfileCannotBeBuilt() {
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")
        let decision = SandboxPolicy.decide(
            workspaceRoot: missing,
            temporaryDirectory: missing,
            environment: [:]
        )
        #expect(!decision.isEnforced)
        guard case .profileUnbuildable = try? #require(decision.degradation?.reason) else {
            Issue.record("profileUnbuildable 이 아니다: \(String(describing: decision.degradation))")
            return
        }
    }

    @Test("verify 는 실제 sandbox-exec 로 프로파일을 컴파일해 본다")
    func verifyAcceptsRealProfile() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: SandboxProfile.executablePath))
        let (profile, workspace) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let decision = await SandboxPolicy.verify(.enforced(profile))
        #expect(decision.isEnforced, "프로파일 v1 이 이 커널에서 컴파일되지 않았다: \(String(describing: decision.degradation))")
    }

    @Test("프로파일이 거부되면 종료코드와 메시지를 담아 강등한다")
    func verifyDegradesOnRejection() async throws {
        let (profile, workspace) = try Self.makeProfile()
        defer { try? FileManager.default.removeItem(at: workspace) }

        // 프로파일 거부를 흉내 내는 스텁. 진짜 sandbox-exec 를 망가뜨릴 수는 없으므로
        // 종료코드 65 와 stderr 한 줄만 재현한다.
        let stub = workspace.appendingPathComponent("fake-sandbox-exec")
        try """
        #!/bin/sh
        echo "sandbox-exec: unbound variable: nope at <input string>" >&2
        exit 65
        """.write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)

        let decision = await SandboxPolicy.verify(.enforced(profile), sandboxExecutablePath: stub.path)
        #expect(!decision.isEnforced)
        let reason = try #require(decision.degradation?.reason)
        guard case let .profileRejected(exitCode, message) = reason else {
            Issue.record("profileRejected 가 아니다: \(reason)")
            return
        }
        #expect(exitCode == 65)
        #expect(message.contains("unbound variable"))
    }

    @Test("이미 강등된 판정은 verify 가 건드리지 않는다")
    func verifyPassesThroughDegradedDecision() async {
        let degradation = SandboxDegradation(.executableMissing(path: "/nope"))
        let decision = await SandboxPolicy.verify(.degraded(degradation))
        #expect(decision.degradation == degradation)
    }
}
