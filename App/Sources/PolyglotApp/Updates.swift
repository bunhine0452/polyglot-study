internal import Combine
internal import Foundation
internal import Sparkle
internal import SwiftUI

/// Sparkle 자동 업데이트 배선 — `{#sparkle-updates}` · `{#sparkle-appcast}`.
///
/// 설정은 코드가 아니라 `Resources/Info.plist` 에 있다 — `SUFeedURL`(피드),
/// `SUPublicEDKey`(EdDSA 공개키), `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`.
/// Sparkle 이 그 키들을 **호스트 번들에서** 읽기 때문에, 코드에서 다시 설정하면 두 곳이
/// 어긋난다. 여기서 하는 일은 셋뿐이다.
///
/// 1. `SPUStandardUpdaterController` 를 앱 수명만큼 살려 둔다. 이게 죽으면 예약 검사도 멎는다.
/// 2. 메뉴에 "업데이트 확인…" 을 꽂고, 세션이 도는 동안 비활성화한다.
/// 3. 검증용 피드 재정의(`POLYGLOT_SPARKLE_FEED_URL`)를 델리게이트로 건넨다.
///
/// (3)이 필요한 이유: 이 저장소에는 아직 git 원격도 GitHub Pages 도 없어서 Info.plist 의
/// 실제 피드 URL 로는 왕복을 확인할 방법이 없다. 로컬 HTTP 서버를 세우고 그쪽을 가리키게
/// 하는 것이 지금 실측 가능한 최대치다 — `Scripts/verify-sparkle.sh` 가 그 경로를 쓴다.
/// 변수가 비어 있으면 nil 을 돌려주고 Sparkle 은 Info.plist 값을 그대로 본다.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    /// `SPUUpdater` 는 델리게이트를 **약하게** 잡는다(SPUStandardUpdaterController.h 의
    /// "weakly referenced, so you are responsible for keeping them alive"). 여기서 강한
    /// 참조를 들지 않으면 피드 재정의가 조용히 사라지고 Info.plist 로 되돌아간다.
    private let feedDelegate = FeedURLOverride()
    private let controller: SPUStandardUpdaterController

    /// 메뉴 항목 활성화 상태. 검사·다운로드·설치가 도는 동안 false 가 된다.
    @Published private(set) var canCheckForUpdates = false

    private init() {
        // 프로브 모드에서는 표준 업데이터를 **띄우지 않는다**. 한 프로세스에 업데이터가
        // 둘이면 같은 피드를 두 번 긁고 설치 세션이 서로를 밟는다.
        controller = SPUStandardUpdaterController(
            startingUpdater: !SparkleProbe.isEnabled,
            updaterDelegate: feedDelegate,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// `SUFeedURL` 런타임 재정의의 **단일 출처**. 표준 업데이터와 검증 프로브가 같은 값을
/// 봐야 한다 — 각자 환경 변수를 읽으면 이름이 갈라지는 날 한쪽만 조용히 안 먹는다.
///
/// 이게 보안 구멍이 아닌 이유: 피드를 바꿔치기해도 EdDSA 서명 검증은 그대로다. 공격자가
/// 개인키 없이 만든 업데이트는 `SUPublicEDKey` 검증에서 거부된다 —
/// `Scripts/verify-sparkle.sh` 의 거부 왕복이 정확히 그것을 확인한다.
enum SparkleFeed {
    static let environmentKey = "POLYGLOT_SPARKLE_FEED_URL"

    /// 값이 없거나 비어 있으면 nil. 그러면 Sparkle 이 Info.plist 의 `SUFeedURL` 을 본다.
    static var override: String? {
        guard let value = ProcessInfo.processInfo.environment[environmentKey], !value.isEmpty
        else { return nil }
        return value
    }
}

/// Sparkle 이 권장하는 재정의 방법이 델리게이트다 — `-[SPUUpdater setFeedURL:]` 은 2.x 에서
/// deprecated 이고(사용자 기본값에 눌어붙는다), 델리게이트는 매 검사마다 다시 물어본다.
private final class FeedURLOverride: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? { SparkleFeed.override }
}

/// 애플 메뉴의 "Polyglot 정보" 바로 아래 — macOS 앱이 업데이트 항목을 두는 관례 자리.
struct UpdatesCommands: Commands {
    @ObservedObject private var updater = UpdaterController.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("업데이트 확인…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
        }
    }
}
