import Testing
import LanguageKit
import LearnCore
import RunnerKit
@testable import OnboardingFeature

/// `OnboardingModel` 을 진짜 프로세스 없이 검증한다 — `probeAvailability`/`clipboardWriter`
/// 를 주입해 매핑·집계·클립보드 계약만 고정한다. 실제 감지는
/// `OnboardingModelRealProbeTests` 가 맡는다.
@Suite("OnboardingModel")
struct OnboardingModelTests {
    /// 이 리포지토리의 실측(`HANDOFF.md`)을 그대로 흉내낸 픽스처 — 7 ready / 2 missing / 1 stub.
    nonisolated static func machineLikeAvailability(for spec: ToolSpec) -> ModuleAvailability {
        switch spec.id {
        case "python3": .ready(version: "3.14.3", executablePath: "/opt/homebrew/bin/uv-python")
        case "sqlite3": .ready(version: "3.51.1", executablePath: "/opt/homebrew/bin/sqlite3")
        case "swiftc": .ready(version: "6.3.3", executablePath: "/usr/bin/swiftc")
        case "rustc": .ready(version: "1.98.0", executablePath: "~/.cargo/bin/rustc")
        case "clang++": .ready(version: "21.0.0", executablePath: "/usr/bin/clang++")
        case "node": .ready(version: "26.7.0", executablePath: "~/.local/bin/node")
        case "as": .ready(version: "21.0.0", executablePath: "/usr/bin/as")
        case "javac": .stub(path: "/usr/bin/java", reason: "Unable to locate a Java Runtime")
        case "go": .missing(installHint: "brew install go")
        case "tsc": .missing(installHint: "npm install -g typescript")
        default: .missing(installHint: "unknown")
        }
    }

    @Test("스캔 전에는 모든 행이 자리만 예약한다 — 레이아웃이 튀지 않게")
    func rowsStartAsScanningPlaceholders() {
        let model = OnboardingModel(probeAvailability: { _ in .missing(installHint: "-") })
        #expect(model.rows.count == 10)
        #expect(model.rows.allSatisfy { $0.status == .scanning })
        #expect(model.summary == .init(installed: 0, missing: 0, problem: 0, total: 10))
    }

    @Test("집계는 실제 결과와 일치한다 — 이 머신 실측을 그대로 흉내낸 픽스처")
    func summaryMatchesInjectedResults() async {
        let model = OnboardingModel(probeAvailability: { spec in
            Self.machineLikeAvailability(for: spec)
        })

        await model.scan()

        #expect(model.summary == .init(installed: 7, missing: 2, problem: 1, total: 10))
        #expect(model.rows.allSatisfy {
            if case .resolved = $0.status { return true }
            return false
        })
    }

    @Test(".unsupported 는 집계에서도 '미설치' 버킷으로 접힌다")
    func unsupportedCountsAsMissingInAggregate() async {
        let specs: [ToolSpec] = [ToolchainCatalog.python, ToolchainCatalog.swift]
        let model = OnboardingModel(specs: specs, probeAvailability: { spec in
            switch spec.id {
            case "python3": .ready(version: "3.14.3", executablePath: "/usr/bin/python3")
            default: .unsupported(path: "/usr/bin/swiftc", version: "5.5.0", minimum: "5.9")
            }
        })

        await model.scan()

        #expect(model.summary == .init(installed: 1, missing: 1, problem: 0, total: 2))
    }

    @Test("installHint 는 변형 없이 클립보드로 그대로 나간다")
    func copyInstallHintForwardsExactString() {
        // `clipboardWriter` 의 정적 타입은 `@Sendable` 이지만, `copyInstallHint` 는
        // 호출자와 같은(MainActor) 컨텍스트에서 동기적으로 부른다 — 이 테스트 안에서는
        // 동시 접근이 없다는 걸 알고 있으므로 `nonisolated(unsafe)` 로 캡처한다.
        nonisolated(unsafe) var written: [String] = []
        let model = OnboardingModel(
            probeAvailability: { _ in .missing(installHint: "-") },
            clipboardWriter: { written.append($0) }
        )

        model.copyInstallHint("brew install --cask temurin")

        #expect(written == ["brew install --cask temurin"])
    }

    @Test("표 순서는 카탈로그 순서가 아니라 디자인 순서다 — Next.js 가 TypeScript 보다 앞")
    func displayOrderMatchesDesignNotCatalog() {
        let ids = OnboardingModel.displayOrder.map(\.id)
        #expect(ids == ["python3", "sqlite3", "swiftc", "rustc", "clang++", "go", "javac", "node", "tsc", "as"])
        #expect(ToolchainCatalog.all.map(\.id) != ids, "카탈로그 순서를 그냥 베낀 게 아니라는 걸 확인한다")
    }

    @Test("트랙 이름은 언어 ID 로부터 10개 전부 온다")
    func trackNameCoversAllTenLanguages() {
        let names = OnboardingModel.displayOrder.map { OnboardingModel.trackName(for: $0.language) }
        #expect(names == [
            "Python", "SQL", "Swift", "Rust", "C++", "Go", "Java", "Next.js", "TypeScript", "Assembly",
        ])
    }
}
