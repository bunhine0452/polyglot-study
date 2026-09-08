import ContentKit
import Testing

@testable import DesignSystem
@testable import LessonFeature

/// ``VisualPlayerState`` 는 순수 값 타입이라 뷰 없이 경계 조건을 전부 잰다 — 재생기가
/// 실제로 쓰는 것과 같은 규칙이다.
@Suite("시각화 재생기 · 상태 전이")
struct VisualPlayerStateTests {
    @Test("처음 상태는 0번 프레임, 정지 상태다")
    func initialState() throws {
        let state = VisualPlayerState(frameCount: 5)
        #expect(state.currentIndex == 0)
        #expect(state.isPlaying == false)
        #expect(state.isAtStart)
        #expect(!state.isAtEnd)
    }

    @Test("다음/이전이 인덱스를 하나씩 옮긴다")
    func stepMovesByOne() throws {
        var state = VisualPlayerState(frameCount: 5)
        state.stepForward()
        #expect(state.currentIndex == 1)
        state.stepForward()
        #expect(state.currentIndex == 2)
        state.stepBackward()
        #expect(state.currentIndex == 1)
    }

    @Test("처음에서 이전을 눌러도 0에서 멈춘다")
    func stepBackwardStopsAtStart() throws {
        var state = VisualPlayerState(frameCount: 5)
        state.stepBackward()
        #expect(state.currentIndex == 0)
        #expect(state.isAtStart)
    }

    @Test("끝에서 다음을 눌러도 마지막 인덱스에서 멈춘다")
    func stepForwardStopsAtEnd() throws {
        var state = VisualPlayerState(frameCount: 3)
        state.jumpToEnd()
        #expect(state.currentIndex == 2)
        state.stepForward()
        #expect(state.currentIndex == 2)
        #expect(state.isAtEnd)
    }

    @Test("처음/끝으로 곧장 뛴다")
    func jumpToEnds() throws {
        var state = VisualPlayerState(frameCount: 7)
        state.jumpToEnd()
        #expect(state.currentIndex == 6)
        state.jumpToStart()
        #expect(state.currentIndex == 0)
    }

    @Test("스크럽은 임의 인덱스로 곧장 이동한다 — 그 앞을 순서대로 밟지 않는다")
    func scrubJumpsDirectly() throws {
        var state = VisualPlayerState(frameCount: 10)
        state.scrub(to: 6)
        #expect(state.currentIndex == 6)
        state.scrub(to: 2)
        #expect(state.currentIndex == 2)
    }

    @Test("스크럽은 범위 밖 인덱스를 가장 가까운 끝으로 붙인다")
    func scrubClampsOutOfRange() throws {
        var state = VisualPlayerState(frameCount: 5)
        state.scrub(to: 99)
        #expect(state.currentIndex == 4)
        state.scrub(to: -3)
        #expect(state.currentIndex == 0)
    }

    @Test("재생을 토글하면 상태가 뒤집힌다")
    func togglePlayingFlipsState() throws {
        var state = VisualPlayerState(frameCount: 5)
        state.togglePlaying()
        #expect(state.isPlaying)
        state.togglePlaying()
        #expect(!state.isPlaying)
    }

    @Test("끝에서 재생을 누르면 처음부터 다시 돈다")
    func togglePlayingAtEndRewinds() throws {
        var state = VisualPlayerState(frameCount: 4)
        state.jumpToEnd()
        state.togglePlaying()
        #expect(state.currentIndex == 0)
        #expect(state.isPlaying)
    }

    @Test("pause 는 재생 중이 아니어도 안전하다")
    func pauseIsIdempotent() throws {
        var state = VisualPlayerState(frameCount: 4)
        state.pause()
        #expect(!state.isPlaying)
        state.togglePlaying()
        state.pause()
        #expect(!state.isPlaying)
    }

    @Test("정지 상태에서 틱은 아무것도 옮기지 않는다")
    func tickDoesNothingWhilePaused() throws {
        var state = VisualPlayerState(frameCount: 5)
        state.tick()
        #expect(state.currentIndex == 0)
    }

    @Test("재생 중 틱은 한 프레임씩 전진하다가 끝에서 스스로 멈춘다")
    func tickAdvancesThenStopsAtEnd() throws {
        var state = VisualPlayerState(frameCount: 3)
        state.togglePlaying()
        state.tick()
        #expect(state.currentIndex == 1)
        #expect(state.isPlaying)
        state.tick()
        #expect(state.currentIndex == 2)
        #expect(state.isPlaying)
        // 마지막 프레임에 이미 있던 틱이 멈춘다 — 반복 재생하지 않는다.
        state.tick()
        #expect(state.currentIndex == 2)
        #expect(!state.isPlaying)
    }

    @Test("프레임이 하나뿐이면 시작이자 끝이다")
    func singleFrameIsStartAndEnd() throws {
        let state = VisualPlayerState(frameCount: 1)
        #expect(state.isAtStart)
        #expect(state.isAtEnd)
    }
}
