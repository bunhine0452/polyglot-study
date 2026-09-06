public import SwiftUI

/// 디자인 토큰. **화면 코드에 색·크기 리터럴이 들어가지 않게 하는 것이 이 파일의 목적**이다.
///
/// 값의 출처는 `design/*.dc.html` 의 스위스 그리드 아트보드 7종이다. 방향의 핵심 규칙은
/// **색을 상태 표시에만 쓴다**는 것 — 통과와 실패 두 가지뿐이고, 나머지는 전부 무채색이다.
/// 문법 하이라이팅조차 무채색이라, 화면에 빨강이 보이면 그건 반드시 실패라는 뜻이 된다.
/// 라운딩과 그림자는 0이며 프리미티브가 타입 차원에서 그걸 봉인한다.
public enum Palette {
    /// 바탕. 앱 전체의 종이.
    public static let paper = Color(hex: 0xF4F4F2)
    /// 카드·에디터처럼 종이 위에 올라오는 면.
    public static let card = Color(hex: 0xFFFFFF)

    /// 본문과 굵은 룰. 활성 항목의 반전 배경이기도 하다.
    public static let ink = Color(hex: 0x141414)
    /// 2차 텍스트 — 라벨, 보조 설명.
    public static let secondary = Color(hex: 0x5F5F5C)
    /// 흐린 텍스트 — 비활성 트랙, 미도래 블록, 주석.
    public static let faint = Color(hex: 0x9A9A97)
    /// 숫자의 선행 0. 헥스 덤프에서 자릿수는 유지하되 눈에 안 띄게 한다.
    public static let zeroDigit = Color(hex: 0xB4B4B1)

    /// 굵은 1px 룰 — 영역을 가르는 선.
    public static let ruleHard = Color(hex: 0x141414)
    /// 가는 1px 룰 — 같은 영역 안의 행 구분.
    public static let ruleSoft = Color(hex: 0xD9D9D6)
    /// 진도 그리드의 미래 칸 테두리.
    public static let cellEmpty = Color(hex: 0xC9C9C6)

    // MARK: - 상태색 — 이 둘이 전부다

    public static let pass = Color(hex: 0x2F8F4E)
    public static let fail = Color(hex: 0xC8372D)
    /// SQL 결과 diff 의 누락 행 배경 전용. 다른 곳에 쓰지 마라.
    public static let failWash = Color(hex: 0xF7E4E2)
}

/// 타입 스케일. 산스와 모노를 **분리**한다 — 같은 숫자를 공유하면 코드 블록의 행 높이가
/// 8px 베이스라인에서 어긋난다.
public enum Typography {
    /// 본문·UI. IBM Plex Sans KR, 폴백은 Apple SD Gothic Neo.
    public enum Sans: CGFloat, CaseIterable, Sendable {
        case micro = 11, label = 13, body = 15, subtitle = 20
        case title = 24, display = 28, hero = 32
    }

    /// 코드·수치. IBM Plex Mono, 폴백은 SF Mono.
    public enum Mono: CGFloat, CaseIterable, Sendable {
        case micro = 11, label = 12, code = 12.5
    }

    public static let sansFamily = "IBMPlexSansKR"
    public static let monoFamily = "IBMPlexMono"

    /// 폰트 등록 전이거나 실패했을 때의 폴백. 메트릭이 가까운 것으로 골랐다 —
    /// PNG·PDF 내보내기에서는 항상 이쪽이 나온다.
    public static let sansFallback = "Apple SD Gothic Neo"
    public static let monoFallback = "SF Mono"

    /// 12.5pt 모노에서 행 높이가 20px 이 되도록 하는 값. 8px 그리드와 맞물린다.
    public static let codeLineHeight: CGFloat = 20
}

/// 8px 베이스라인. 간격은 이 배수로만 쓴다.
public enum Spacing {
    public static let unit: CGFloat = 8
    public static let xs: CGFloat = 4      // 반 칸 — 아이콘·도트 주변에만
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    /// 고정 사이드바 폭.
    public static let sidebarWidth: CGFloat = 232
    /// 에디터 우측 결과 패널의 고정 폭. 실행 전에도 자리를 잡아 레이아웃이 튀지 않게 한다.
    public static let resultPanelWidth: CGFloat = 520
    /// 레슨 실행 예제의 출력 슬롯 최소 높이. 같은 이유로 미리 예약한다.
    public static let outputSlotHeight: CGFloat = 80
    /// 접힌 완료 블록 한 줄의 높이.
    public static let collapsedBlockHeight: CGFloat = 40
}

/// 1px 룰의 두께. Retina 에서도 논리 1px 이다 — hairline 으로 흐려지면 안 된다.
public enum Rules {
    public static let thickness: CGFloat = 1
    /// 레슨 활성 블록 카드의 상단 강조 룰.
    public static let emphasisThickness: CGFloat = 2
    /// 상태 도트 한 변.
    public static let statusDotSize: CGFloat = 8
    /// 에디터 거터의 진단 표식 한 변.
    public static let gutterMarkSize: CGFloat = 6
    /// 진도 그리드 한 칸과 칸 사이.
    public static let progressCellSize: CGFloat = 6
    public static let progressCellGap: CGFloat = 2
}

extension Color {
    /// 0xRRGGBB 리터럴에서. **토큰 정의에서만 쓴다** — 화면 코드는 `Palette` 를 거쳐야 한다.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
