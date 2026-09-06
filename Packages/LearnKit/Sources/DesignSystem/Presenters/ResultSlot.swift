public import SwiftUI

/// 결과 영역이 **실행 전에도** 차지하는 자리.
///
/// 실행 버튼을 눌렀을 때 결과 영역이 0에서 커지면 그 위의 코드와 설명이 통째로
/// 위로 밀린다. 학습자가 방금 읽던 줄이 눈앞에서 움직이는 것이라, 실행 결과보다
/// 그 움직임이 먼저 눈에 들어온다. 그래서 슬롯은 비어 있을 때부터 최소 크기를
/// 잡아 두고, 내용이 그보다 커지면 **아래로만** 자란다(`alignment: .top`).
/// 슬롯이 놓이는 두 자리. 값은 전부 토큰에서 온다.
public enum ResultSlotReservation: String, Sendable, Hashable, CaseIterable {
    /// 레슨 카드 안의 출력 영역. 높이를 예약한다.
    case lessonOutput
    /// 에디터 오른쪽 결과 패널. 폭을 예약한다.
    case editorPanel

    public var minHeight: CGFloat? {
        switch self {
        case .lessonOutput: Spacing.outputSlotHeight
        case .editorPanel: nil
        }
    }

    public var width: CGFloat? {
        switch self {
        case .lessonOutput: nil
        case .editorPanel: Spacing.resultPanelWidth
        }
    }
}

public struct ResultSlot<Content: View>: View {
    public typealias Reservation = ResultSlotReservation

    private let reservation: Reservation
    private let content: Content

    public init(_ reservation: Reservation, @ViewBuilder content: () -> Content) {
        self.reservation = reservation
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: reservation.minHeight, alignment: .top)
            .frame(width: reservation.width)
            .overlay {
                Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: Rules.thickness)
            }
    }
}

/// 슬롯이 실제로 차지하는 높이. **뷰를 렌더하지 않고 단언하기 위한 순수 함수**다.
///
/// 실행 전(줄 0개)과 짧은 실행 후가 같은 값이어야 한다 — 그것이 이 예약의 전부다.
public enum ResultSlotMetrics {
    /// 출력 한 줄. 디자인 실측 18px (12.5pt 모노 + 여유). `Typography.codeLineHeight`
    /// 는 에디터용 20px 이라 토큰에 이 값이 없다 — 지역 상수다.
    public static let lineHeight: CGFloat = 18
    /// 슬롯 위아래 여백. 디자인 실측 10px.
    public static let verticalPadding: CGFloat = Spacing.unit + Spacing.xs / 2
    /// "출력 / 실행 전" 머리줄.
    public static let headerHeight: CGFloat = 16
    /// 머리줄과 본문 사이.
    public static let headerGap: CGFloat = Spacing.unit - 2

    /// 예약 높이. 최소값 아래로는 절대 줄지 않고, 넘으면 아래로만 자란다.
    public static func reservedHeight(lineCount: Int) -> CGFloat {
        let content = CGFloat(max(lineCount, 1)) * lineHeight
        let natural = verticalPadding * 2 + headerHeight + headerGap + content
        return max(Spacing.outputSlotHeight, natural)
    }

    /// 예약 높이 안에 몇 줄까지 들어가는가. 이 줄 수까지는 슬롯이 커지지 않는다.
    public static var reservedLineCount: Int {
        let available =
            Spacing.outputSlotHeight - verticalPadding * 2 - headerHeight - headerGap
        return max(1, Int(available / lineHeight))
    }
}
