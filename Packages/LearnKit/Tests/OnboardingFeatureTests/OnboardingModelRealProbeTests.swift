import Testing
import LanguageKit
@testable import OnboardingFeature

/// 이 머신에서 **실제** `LanguageToolchain`/`ToolchainProbe` 를 불러 모델을 채운다.
/// `RunnerKitTests.ToolchainProbeTests.detectAllToolchains` 와 같은 결과를 공유한다
/// (`LanguageToolchain.shared` 가 프로세스 전역 캐시라 두 번째 호출은 사실상 공짜다).
///
/// 벽시계 시간은 관대하게(`.timeLimit`), 구조는 엄격하게 단언한다 — 어떤 버전이
/// 나오는지가 아니라 "10행이 전부 결정된 상태로 끝나는지" 를 본다.
@Suite("OnboardingModel 실측 감지")
struct OnboardingModelRealProbeTests {
    @Test("기본 생성자가 실제 툴체인을 불러 10행을 채운다", .timeLimit(.minutes(3)))
    func scanResolvesAllTenRowsFromRealToolchain() async {
        let model = OnboardingModel()
        #expect(model.rows.count == 10)

        await model.scan()

        #expect(model.rows.allSatisfy {
            if case .resolved = $0.status { return true }
            return false
        })
        #expect(model.summary.total == 10)
        #expect(model.summary.installed + model.summary.missing + model.summary.problem == 10)
        #expect(model.lastScanFinishedAt != nil)

        // MVP 3종(Python·SQL·Swift)은 설계 전제상 이 머신에서 추가 설치 없이 ready 여야 한다
        // (`ToolchainProbeTests.detectAllToolchains` 와 동일한 전제).
        for id in ["python3", "sqlite3", "swiftc"] {
            let row = try! #require(model.rows.first { $0.id == id })
            guard case let .resolved(availability) = row.status else {
                Issue.record("\(id) 가 resolved 상태가 아니다")
                continue
            }
            #expect(availability.isReady, "\(id) 가 ready 가 아니다: \(availability)")
        }
    }
}
