internal import SwiftUI

/// 사이드바의 최상위 목적지 4개. 이 열거형이 곧 앱의 전체 화면 지도다 —
/// 여기 없는 화면은 다른 화면 안에서 밀려 들어온다(레슨·에디터·결과).
///
/// `설정` 은 목적지가 아니다. 디자인에서 별도 푸터 행으로 분리돼 있고, MVP 범위 밖이다.
public enum ShellDestination: String, Sendable, CaseIterable, Identifiable, Hashable {
    case today
    case tracks
    case review
    case toolchain

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "오늘"
        case .tracks: "트랙"
        case .review: "복습"
        case .toolchain: "툴체인"
        }
    }
}
