public import ContentKit
public import DesignSystem
/// 재생기의 프레임 이동 규칙. 뷰에서 떼어 둔 순수 값 타입이라 SwiftUI 없이, `VisualPlayerView`
/// 없이도 테스트된다.
///
/// 다음/이전/스크럽/경계에서 멈추는 규칙을 전부 여기 모은다 — 뷰가 이 규칙을 직접 구현하면
/// "끝에서 다음을 누르면 멈추는지, 재생이 끝에 닿으면 스스로 서는지" 같은 경계 조건이
/// 뷰 코드 속에 흩어지고 테스트하려면 매번 `ImageRenderer` 를 태워야 한다.
public struct VisualPlayerState: Hashable, Sendable {
    /// 이 재생기가 도는 프레임 총 개수. `VisualFrameSet` 의 모든 장면은 `ContentKit` 쪽
    /// 검증에서 이미 `noFrames` 를 걸러내므로 실제로는 항상 1 이상이지만, 그림자 모델은
    /// 그 검증을 갖고 있지 않으므로(``VisualFrameSet`` 머리말 참고) 여기서 다시 한번 지킨다.
    public let frameCount: Int
    public private(set) var currentIndex: Int
    public private(set) var isPlaying: Bool

    public init(frameCount: Int) {
        precondition(frameCount > 0, "frameCount 는 1 이상이어야 한다 — 프레임 없는 재생기는 없다")
        self.frameCount = frameCount
        self.currentIndex = 0
        self.isPlaying = false
    }

    public var isAtStart: Bool { currentIndex == 0 }
    public var isAtEnd: Bool { currentIndex == frameCount - 1 }

    /// 끝에서는 멈춘다 — 마지막 프레임을 넘어가는 인덱스는 없다.
    public mutating func stepForward() {
        guard !isAtEnd else { return }
        currentIndex += 1
    }

    /// 처음에서는 멈춘다.
    public mutating func stepBackward() {
        guard !isAtStart else { return }
        currentIndex -= 1
    }

    public mutating func jumpToStart() { currentIndex = 0 }
    public mutating func jumpToEnd() { currentIndex = frameCount - 1 }

    /// 스크럽 — 프레임 눈금을 눌러 임의 인덱스로 곧장 이동한다. 범위 밖 인덱스는 가장
    /// 가까운 끝으로 붙인다(눈금은 항상 유효한 개수만큼만 그려지므로 실제로는 방어적
    /// 처리다). 프레임이 전체 상태를 담고 있으므로 그 앞을 순서대로 재생할 필요가 없다.
    public mutating func scrub(to index: Int) {
        currentIndex = min(max(index, 0), frameCount - 1)
    }

    /// 끝에서 재생을 누르면 처음부터 다시 돈다 — 안 그러면 재생 버튼이 아무 반응 없어
    /// 보인다.
    public mutating func togglePlaying() {
        if !isPlaying, isAtEnd { currentIndex = 0 }
        isPlaying.toggle()
    }

    public mutating func pause() { isPlaying = false }

    /// 재생 타이머가 매 틱마다 부른다. 끝에 닿으면 스스로 멈춘다 — 반복 재생은 v1 범위
    /// 밖이다. 한 번 훑고 서는 것이 "재생"의 기본값이다.
    public mutating func tick() {
        guard isPlaying else { return }
        guard !isAtEnd else {
            isPlaying = false
            return
        }
        currentIndex += 1
    }
}
