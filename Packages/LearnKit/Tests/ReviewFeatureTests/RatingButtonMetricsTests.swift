import SwiftUI
import Testing
import LearnCore
import DesignSystem
@testable import ReviewFeature

/// 0xRRGGBB 로 되돌린다. `DesignSystemTests.hexValue` 와 같은 이유 — 근사가 아니라 정수 일치.
private func hexValue(_ color: Color) -> UInt32 {
    let converted = NSColor(color).usingColorSpace(.sRGB)!
    let r = UInt32((converted.redComponent * 255).rounded())
    let g = UInt32((converted.greenComponent * 255).rounded())
    let b = UInt32((converted.blueComponent * 255).rounded())
    return (r << 16) | (g << 8) | b
}

/// **완료 기준의 핵심** — "4개 채점 버튼의 폭·높이·배경·테두리가 완전히 동일하다" 를
/// 렌더 없이 못박는다. `{#screen-review}` `{#review-no-nudge}`
@Suite("채점 버튼 · 4개 동일성")
struct RatingButtonMetricsTests {
    @Test("공유 스펙이 디자인 실측값과 같다 — 72px 높이 · 종이 배경 · 1px 잉크 테두리 · 곡률 0")
    func sharedMetricsMatchDesignTokens() {
        let metrics = RatingButtonMetrics.shared
        #expect(metrics.height == 72)
        #expect(hexValue(metrics.background) == 0xF4F4F2)
        #expect(hexValue(metrics.borderColor) == 0x141414)
        #expect(metrics.borderWidth == Rules.thickness)
        #expect(metrics.cornerRadius == 0)
    }

    @Test("4개 rating 전부 완전히 같은 스타일을 낸다 — 하나라도 다르면 다크 패턴이다")
    func allFourRatingsShareIdenticalStyle() {
        let allMetrics = ReviewRating.allCases.map(RatingButtonMetrics.metrics(for:))
        #expect(allMetrics.count == 4)
        for metrics in allMetrics {
            #expect(metrics == RatingButtonMetrics.shared)
        }
        // 필드 단위로도 다시 확인한다 — 색은 hex 로, 나머지는 값으로.
        #expect(Set(allMetrics.map { hexValue($0.background) }).count == 1)
        #expect(Set(allMetrics.map { hexValue($0.borderColor) }).count == 1)
        #expect(Set(allMetrics.map(\.height)).count == 1)
        #expect(Set(allMetrics.map(\.borderWidth)).count == 1)
        #expect(Set(allMetrics.map(\.cornerRadius)).count == 1)
    }

    @Test("'좋음' 도 예외가 아니다 — 특정 rating 만 강조하는 경로가 없다")
    func goodRatingIsNotSpecialCased() {
        let good = RatingButtonMetrics.metrics(for: .good)
        let others = [ReviewRating.again, .hard, .easy].map(RatingButtonMetrics.metrics(for:))
        #expect(others.allSatisfy { $0 == good })
    }

    @Test("폭은 스펙에 없다 — 4버튼 모두 같은 HStack 안에서 균등 분할되기 때문")
    func specHasNoWidthField() {
        // 이 테스트는 컴파일 그 자체가 증거다: `RatingButtonMetrics` 에 `width` 필드를
        // 추가하는 순간(예: 특정 rating 만 넓히려는 시도) 아래 이니셜라이저 시그니처가
        // 달라져 이 파일이 컴파일되지 않는다.
        let metrics = RatingButtonMetrics(
            height: 72,
            background: Palette.paper,
            borderColor: Palette.ink,
            borderWidth: Rules.thickness,
            cornerRadius: 0
        )
        #expect(metrics == RatingButtonMetrics.shared)
    }
}

/// `RatingButtonSpec` 이 시각 속성을 하나도 담지 않는다는 것도 같은 방식으로 고정한다.
@Suite("채점 버튼 · 스펙은 텍스트만 담는다")
struct RatingButtonSpecTests {
    @Test("스펙은 rating·간격 라벨만 갖고, 파생 프로퍼티는 ReviewCopy 를 그대로 옮긴다")
    func specDerivesTextFromReviewCopy() {
        let spec = RatingButtonSpec(rating: .good, intervalLabel: "4일")
        #expect(spec.id == .good)
        #expect(spec.label == ReviewCopy.label(for: .good))
        #expect(spec.keyHint == ReviewCopy.keyHint(for: .good))
        #expect(spec.intervalLabel == "4일")
    }
}
