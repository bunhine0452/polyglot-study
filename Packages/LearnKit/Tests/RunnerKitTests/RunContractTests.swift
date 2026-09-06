import Foundation
import Testing
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("실행 계약 — 종료·자원·상한")
struct RunContractTests {

    @Test("종료 코드가 있는 백엔드는 0 을 성공으로 접는다")
    func exitCodeFoldsIntoStatus() {
        #expect(RunTermination.exitCode(0, durationMilliseconds: 12).status == .succeeded)
        #expect(RunTermination.exitCode(0, durationMilliseconds: 12).exitCode == 0)
        #expect(RunTermination.exitCode(42, durationMilliseconds: 12).status == .failed(code: 42))
        #expect(RunTermination.exitCode(42, durationMilliseconds: 12).succeeded == false)
        #expect(RunTermination.exitCode(7, durationMilliseconds: 12).durationMilliseconds == 12)
    }

    @Test("종료 코드라는 개념이 없는 백엔드는 코드 없는 실패를 낸다")
    func codelessFailureIsRepresentable() {
        let codeless = RunTermination(status: .failed(code: nil), durationMilliseconds: 3)
        #expect(codeless.exitCode == nil)
        #expect(!codeless.succeeded)
        // 코드 없는 실패와 코드 1 인 실패는 **다른 값**이다 — 임의 매핑을 되살리지 못하게 한다.
        #expect(codeless.status != .failed(code: 1))
    }

    @Test("RunRequest 의 자원은 기본이 비어 있다")
    func resourcesDefaultEmpty() {
        let request = RunRequest(files: [SourceFile(path: "q.sql", contents: "SELECT 1;")])
        #expect(request.resources.isEmpty)

        let targeted = RunRequest(
            files: request.files,
            resources: [RunRequest.Resource.database: URL(fileURLWithPath: "/tmp/study.db")]
        )
        #expect(targeted.resources[RunRequest.Resource.database]?.lastPathComponent == "study.db")
    }

    @Test("ResourceLimits 는 파일 크기 상한을 64MiB 로 기본 제공한다")
    func fileSizeLimitHasContractDefault() {
        #expect(ResourceLimits.lesson.fileSizeBytes == 64 << 20)
        // outputBytes 와 다른 축이다 — 하나를 바꿔도 다른 하나가 따라가지 않는다.
        #expect(ResourceLimits.lesson.outputBytes != ResourceLimits.lesson.fileSizeBytes)
        #expect(ResourceLimits(fileSizeBytes: 1 << 10).fileSizeBytes == 1 << 10)
    }

    @Test("EnforcedLimits.all 은 여섯 축 전부를 담는다")
    func enforcedLimitsCoverSixAxes() {
        let axes: [EnforcedLimits] = [
            .wallClock, .cpuTime, .memory, .outputBytes, .fileSize, .processCount,
        ]
        for axis in axes {
            #expect(EnforcedLimits.all.contains(axis))
            #expect(!EnforcedLimits.none.contains(axis))
        }
        #expect(Set(axes.map(\.rawValue)).count == 6)
    }

    @Test("인프로세스 러너는 못 막는 상한을 숨기지 않는다")
    func inProcessRunnerDeclaresWhatItCannotEnforce() {
        let runner = InProcessRunner()
        #expect(runner.enforcedLimits.contains(.wallClock))
        #expect(runner.enforcedLimits.contains(.outputBytes))
        #expect(runner.enforcedLimits.contains(.memory))
        // 프로세스를 안 띄우니 걸 대상이 없다.
        #expect(!runner.enforcedLimits.contains(.cpuTime))
        #expect(!runner.enforcedLimits.contains(.fileSize))
        #expect(!runner.enforcedLimits.contains(.processCount))
        // 메모리는 막지만 프로세스 전역이라는 사실까지 같이 알린다.
        #expect(runner.capabilities.contains(.processGlobalMemoryLimit))
        #expect(runner.capabilities.contains(.structuredResults))
    }
}
