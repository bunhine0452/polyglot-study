internal import Foundation
internal import Sparkle

/// 업데이트 왕복을 **사람 없이** 끝까지 몰아 보는 드라이버 — `{#sparkle-updates}` 검증용.
///
/// 왜 있는가. 그 항목의 완료 기준은 "구버전 앱이 appcast 를 읽어 신버전을 받고 서명 검증
/// 후 설치까지 완료" 다. 이걸 사람이 대화상자를 누르는 것으로만 확인하면 (a) 회귀를 못
/// 잡고 (b) 서명이 틀린 업데이트가 실제로 거부되는지를 증명할 수 없다. 둘 다 이 프로젝트가
/// 요구하는 종류의 증거가 아니다.
///
/// `POLYGLOT_SPARKLE_PROBE=1` 이면 Sparkle 의 표준 UI 대신 이 드라이버가 붙어서 모든 선택을
/// 자동 수락하고, 단계마다 `SPARKLE-PROBE <단계> <세부>` 한 줄을 stderr 로 찍는다
/// (`POLYGLOT_SPARKLE_PROBE_LOG` 가 있으면 그 파일에도 덧붙인다 — 설치 단계에서 프로세스가
/// 종료당하므로 파이프보다 파일이 안전하다). `Scripts/verify-sparkle.sh` 가 그 줄을 읽는다.
///
/// 앱 동작에는 영향이 없다. 변수가 없으면 이 파일의 코드는 한 줄도 실행되지 않는다 —
/// `POLYGLOT_START_DESTINATION`·`Snapshot.captureAndTerminateIfRequested()` 와 같은 관용구다.
enum SparkleProbe {
    static let enabledKey = "POLYGLOT_SPARKLE_PROBE"
    static let logPathKey = "POLYGLOT_SPARKLE_PROBE_LOG"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[enabledKey] == "1"
    }

    /// 드라이버와 업데이터는 세션 내내 살아 있어야 한다. 지역 변수로 두면 곧바로 해제된다.
    private static var driver: ProbeUserDriver?
    private static var updater: SPUUpdater?

    /// 앱 실행 후 호출한다(`RootView.task`). `SPUUpdater` 는 실행 루프를 요구하므로
    /// `App.init()` 안에서 부르면 안 된다.
    static func startIfRequested() {
        guard isEnabled, updater == nil else { return }

        let driver = ProbeUserDriver()
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: driver,
            delegate: driver
        )
        Self.driver = driver
        Self.updater = updater

        ProbeLog.emit("host-version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
        do {
            try updater.start()
        } catch {
            ProbeLog.emit("start-failed", "\(error)")
            ProbeLog.exit(20)
        }
        ProbeLog.emit("feed", updater.feedURL?.absoluteString ?? "<nil>")
        updater.checkForUpdates()
    }
}

// MARK: - 로그

/// stderr 와(있으면) 파일에 동시에 남긴다. 버퍼링하지 않는다 — 설치 단계에서 Sparkle 이
/// 앱에 종료 이벤트를 보내므로, 버퍼에 남은 줄은 영영 안 나온다.
private enum ProbeLog {
    static func emit(_ stage: String, _ detail: String = "") {
        let line = detail.isEmpty ? "SPARKLE-PROBE \(stage)\n" : "SPARKLE-PROBE \(stage) \(detail)\n"
        guard let data = line.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
        guard let path = ProcessInfo.processInfo.environment[SparkleProbe.logPathKey], !path.isEmpty
        else { return }
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }

    static func exit(_ code: Int32) -> Never {
        emit("exit", "\(code)")
        Foundation.exit(code)
    }
}

// MARK: - 드라이버

/// 모든 대화상자를 "예" 로 답하는 `SPUUserDriver`. 판단은 하나도 하지 않는다 —
/// 거부는 Sparkle 이 하고, 이 드라이버는 그 결과를 받아 적기만 한다.
private final class ProbeUserDriver: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    /// 설치 단계에 들어갔는지. `dismissUpdateInstallation` 이 성공 종료인지 중단인지를
    /// 구별하는 유일한 단서다.
    private var installing = false

    // MARK: SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? { SparkleFeed.override }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        ProbeLog.emit("aborted", "\(error)")
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        ProbeLog.emit("will-relaunch")
    }

    // MARK: SPUUserDriver — 권한·검사

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        ProbeLog.emit("permission-request")
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        ProbeLog.emit("check-started")
    }

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        ProbeLog.emit("update-found", "\(appcastItem.displayVersionString) stage=\(state.stage.rawValue)")
        reply(.install)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        ProbeLog.emit("no-update", "\(error)")
        acknowledgement()
        ProbeLog.exit(10)
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        ProbeLog.emit("updater-error", "\(error)")
        acknowledgement()
        ProbeLog.exit(11)
    }

    // MARK: SPUUserDriver — 다운로드·설치

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        ProbeLog.emit("download-started")
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        ProbeLog.emit("download-length", "\(expectedContentLength)")
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {}

    func showDownloadDidStartExtractingUpdate() {
        ProbeLog.emit("extracting")
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // 여기 도달했다는 것은 Sparkle 의 서명 검증(EdDSA + 코드 서명 정책)이 이미 통과했다는 뜻이다.
        ProbeLog.emit("ready-to-install")
        installing = true
        reply(.install)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        ProbeLog.emit("installing", "terminated=\(applicationTerminated)")
        // 여기서 프로세스를 죽이면 안 된다. 설치기(Autoupdate)가 앱에 종료 이벤트를 보내고,
        // 그걸 받아 정상 종료하는 것이 Sparkle 의 순서다.
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        ProbeLog.emit("installed", "relaunched=\(relaunched)")
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        ProbeLog.emit("dismissed", "installing=\(installing)")
        if !installing { ProbeLog.exit(13) }
    }
}
