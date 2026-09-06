internal import AppKit
internal import Foundation

/// 앱이 자기 창을 PNG 로 굽고 종료하는 디버그 경로. `POLYGLOT_SNAPSHOT_PATH` 가
/// 설정됐을 때만 동작하고, 없으면 이 파일은 아무 일도 하지 않는다.
///
/// 왜 필요한가: `screencapture` 와 `CGWindowListCreateImage` 는 **화면 녹화 권한**을
/// 요구한다. 헤드리스 에이전트·CI 에는 그 권한이 없다(실측: `could not create image
/// from window`). 반면 자기 뷰 계층을 비트맵으로 굽는 것은 권한 밖이다. 그래서
/// "창이 실제로 떠서 이렇게 그려졌다"를 남기려면 앱 자신이 찍는 수밖에 없다.
enum Snapshot {
    /// 창이 레이아웃을 끝내고 첫 프레임을 그릴 시간. 벽시계 단언이라 넉넉히 잡는다.
    ///
    /// 비동기 작업이 끝난 뒤를 찍어야 하면 `POLYGLOT_SNAPSHOT_DELAY` 로 늘린다 —
    /// 툴체인 스캔은 도구당 2초 상한 × 10개 순차라 기본 2초로는 "확인 중…" 만 찍힌다.
    private static var settleDelay: TimeInterval {
        ProcessInfo.processInfo.environment["POLYGLOT_SNAPSHOT_DELAY"]
            .flatMap(TimeInterval.init) ?? 2.0
    }

    static func captureAndTerminateIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["POLYGLOT_SNAPSHOT_PATH"],
              !path.isEmpty
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            let status = capture(to: URL(fileURLWithPath: path))
            FileHandle.standardError.write(Data("snapshot: \(status)\n".utf8))
            NSApplication.shared.terminate(nil)
        }
    }

    private static func capture(to url: URL) -> String {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else {
            return "보이는 창 없음"
        }
        guard let view = window.contentView else { return "contentView 없음" }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return "빈 bounds" }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return "bitmapImageRep 생성 실패"
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return "PNG 인코딩 실패"
        }
        do {
            try data.write(to: url)
        } catch {
            return "쓰기 실패 \(error)"
        }
        return "\(rep.pixelsWide)x\(rep.pixelsHigh) → \(url.path)"
    }
}
