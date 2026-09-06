import Testing
import LanguageKit
@testable import OnboardingFeature

/// `ModuleAvailability` 4케이스 → `RowPresentation` 매핑을 고정한다.
@Suite("ModuleAvailability 표시 매핑")
struct ModuleAvailabilityPresentationTests {
    @Test(".ready 는 녹색 채움 + 버전·경로")
    func readyMapsToFilledPass() {
        let presentation = ModuleAvailability
            .ready(version: "3.14.3", executablePath: "/opt/homebrew/bin/python3")
            .presentation

        #expect(presentation.glyph == .filledPass)
        #expect(presentation.statusLabel == "설치됨")
        #expect(presentation.detailText.contains("3.14.3"))
        #expect(presentation.detailText.contains("/opt/homebrew/bin/python3"))
        #expect(presentation.copyableCommand == nil)
    }

    @Test(".missing 은 빈 사각 + 설치 명령이 그대로 나온다")
    func missingMapsToEmptySquareWithInstallHint() {
        let presentation = ModuleAvailability.missing(installHint: "brew install go").presentation

        #expect(presentation.glyph == .emptySquare)
        #expect(presentation.statusLabel == "미설치")
        #expect(presentation.copyableCommand == "brew install go")
    }

    @Test(".stub 은 적색 채움 + 사유, 설치 명령은 없다")
    func stubMapsToFilledFailWithReason() {
        let presentation = ModuleAvailability
            .stub(path: "/usr/bin/java", reason: "Unable to locate a Java Runtime")
            .presentation

        #expect(presentation.glyph == .filledFail)
        #expect(presentation.statusLabel == "스텁 감지")
        #expect(presentation.detailText.contains("/usr/bin/java"))
        #expect(presentation.detailText.contains("Unable to locate a Java Runtime"))
        #expect(presentation.copyableCommand == nil)
    }

    @Test(".unsupported 는 디자인에 없는 4번째 상태라 '미설치' 빈 사각으로 접힌다")
    func unsupportedFoldsIntoMissingVisual() {
        let presentation = ModuleAvailability
            .unsupported(path: "/usr/bin/swiftc", version: "5.5.0", minimum: "5.9")
            .presentation

        // 아이콘·라벨이 `.missing` 과 같은 표현으로 접힌다.
        #expect(presentation.glyph == .emptySquare)
        #expect(presentation.statusLabel == "미설치")
        // 그러나 설치 명령이 아니라 사유 문구가 붙는다 — `ModuleAvailability.unsupported` 는
        // 애초에 설치/업그레이드 명령을 들고 있지 않다.
        #expect(presentation.copyableCommand == nil)
        #expect(presentation.detailText.contains("5.5.0"))
        #expect(presentation.detailText.contains("5.9"))
        #expect(presentation.detailText.contains("/usr/bin/swiftc"))
    }

    @Test("네 케이스 모두 다른 표시 라벨을 만들지는 않는다 — 빈 사각을 공유하는 둘을 확인")
    func missingAndUnsupportedShareTheSameGlyphFamily() {
        let missing = ModuleAvailability.missing(installHint: "x").presentation
        let unsupported = ModuleAvailability.unsupported(path: "p", version: "1", minimum: "2").presentation
        #expect(missing.glyph == unsupported.glyph)
        #expect(missing.statusLabel == unsupported.statusLabel)
    }
}
