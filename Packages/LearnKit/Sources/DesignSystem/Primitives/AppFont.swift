internal import AppKit
public import SwiftUI

/// `Typography` 의 이름을 실제 `Font` 로 바꾸는 **단 하나의 지점**.
///
/// Plex 번들링(`{#plex-font-bundling}`)이 아직 붙지 않았으므로 지금은 폴백으로 떨어진다.
/// 폰트가 등록되면 이 파일을 고치지 않아도 자동으로 Plex 가 잡힌다 — 해석 순서가
/// `Typography.sansFamily` → `Typography.sansFallback` → 시스템이기 때문이다.
///
/// 뷰 코드가 `Font.custom` 을 직접 부르면 등록 실패 시 조용히 시스템 폰트로 떨어지면서
/// 어느 화면이 폴백인지 알 수 없게 된다. 그래서 해석을 여기 한 곳에 모은다.
///
/// ## 왜 public 인가
///
/// 프리미티브(`LabelText`·`MonoText`·`FlatButton`)가 감싸는 것은 고정 크기 몇 개뿐이다.
/// 화면에는 그 바깥의 크기 — 제목 24pt, 본문 15pt, 큰 숫자 32pt — 가 반드시 나오고,
/// 이 타입이 internal 이던 동안 화면 넷이 각자 사본을 만들었다(온보딩·대시보드·레슨·복습).
/// 사본들은 조금씩 달랐고, 그 차이가 곧 화면 사이의 렌더링 차이였다. 어느 쪽을 골랐는지는
/// 아래 각 멤버의 주석에 남긴다.
public enum AppFont {
    // MARK: - 산스

    public static func sans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        sans(points: size.rawValue, weight: weight)
    }

    /// 타입 스케일에 없는 크기를 위한 탈출구. **의도적으로 internal 이다** — 화면 코드는
    /// `Typography.Sans` 를 거쳐야 하고, 그래야 토큰 밖 크기가 조용히 늘지 않는다.
    /// 사본 넷 중 어느 것도 이 문을 열지 않았으므로 공개할 이유가 없다.
    static func sans(points: CGFloat, weight: Font.Weight = .regular) -> Font {
        // `fixedSize:` 다. 사본 셋(`appSans`·`dashSans`·`reviewSans`)은 `size:` 를 썼는데,
        // 그쪽은 Dynamic Type 배율을 탄다. 이 디자인은 8px 베이스라인에 맞춘 실측 치수이고
        // `ResultSlotMetrics`·`LessonLayout` 이 그 포인트 값으로 높이를 **미리 예약**한다 —
        // 글자만 커지고 예약 높이는 그대로면 예약이 깨진다. 배율은 나중에 토큰째로
        // 도입할 일이지 폰트 접근자가 몰래 할 일이 아니다.
        if let family = resolvedSans {
            return .custom(family, fixedSize: points).weight(weight)
        }
        // 사본 셋은 여기서도 `.custom(Typography.sansFallback)` 을 강제했다. 그러면 폴백
        // 폰트마저 없을 때 SwiftUI 가 조용히 시스템 폰트로 떨어지고, **떨어졌다는 사실을
        // 관측할 방법이 사라진다**. `resolvedSans == nil` 이 그 관측 지점이다.
        return .system(size: points, weight: weight)
    }

    // MARK: - 모노

    /// `weight` 와 `monospacedDigit()` 은 사본 중 `LessonChrome` 쪽에만 있었다.
    /// 자릿수 정렬은 레지스터 표(`Typography.Mono.register`)의 존재 이유라 여기 남긴다.
    public static func mono(_ size: Typography.Mono, weight: Font.Weight = .regular) -> Font {
        if let family = resolvedMono {
            return .custom(family, fixedSize: size.rawValue).weight(weight).monospacedDigit()
        }
        return .system(size: size.rawValue, weight: weight, design: .monospaced).monospacedDigit()
    }

    // MARK: - 해석

    /// 지금 이 머신에서 실제로 잡힌 산스 패밀리. `nil` 이면 시스템 폰트로 떨어진 것이다.
    ///
    /// **`static let` 이다 — 뷰 body 에서 폰트 조회를 반복하지 않는다.** 사본 셋은 폰트를
    /// 만들 때마다 `NSFont(name:)` 을 불렀고, 그건 스크롤하는 목록의 모든 행에서 매번이다.
    public static let resolvedSans: String? = resolve([
        Typography.sansFamily, Typography.sansFallback,
    ])

    /// 지금 이 머신에서 실제로 잡힌 모노 패밀리. `nil` 이면 `.monospaced` 시스템 폰트다.
    public static let resolvedMono: String? = resolve([
        Typography.monoFamily, Typography.monoFallback,
    ])

    /// 후보 이름들을 순서대로 시도해 **이 머신이 실제로 그릴 수 있는** 패밀리명을 돌려준다.
    ///
    /// 폰트 이름에는 두 표기가 섞여 돌아다닌다 — PostScript 형 `"IBMPlexSansKR"` 과
    /// 표시명 `"IBM Plex Sans KR"`. 같은 폰트인데 조회 창구가 다르다: 표시명은
    /// `availableFontFamilies` 에 있고 PostScript 명은 `NSFont(name:)` 이 푼다. 토큰이
    /// 어느 쪽으로 적혀 있든 동작해야 하므로 **셋 다** 본다.
    ///
    /// 1. 패밀리명 그대로 등록돼 있는가.
    /// 2. `NSFont(name:)` 이 푸는가 (PostScript 명).
    /// 3. 공백을 지우고 대소문자를 무시했을 때 등록된 패밀리와 같은가.
    ///
    /// 3번이 두 표기를 잇는 다리다. 돌려주는 것은 **등록된 실제 패밀리명**이라
    /// `Font.custom` 이 그대로 받는다.
    static func resolve(_ candidates: [String]) -> String? {
        let families = NSFontManager.shared.availableFontFamilies
        let exact = Set(families)
        // 먼저 온 것을 남긴다 — `availableFontFamilies` 는 정렬돼 있어 결정적이다.
        var byNormalizedName: [String: String] = [:]
        for family in families {
            let key = normalizedFamilyKey(family)
            if byNormalizedName[key] == nil { byNormalizedName[key] = family }
        }

        for candidate in candidates {
            if exact.contains(candidate) { return candidate }
            if NSFont(name: candidate, size: 12) != nil { return candidate }
            if let family = byNormalizedName[normalizedFamilyKey(candidate)] { return family }
        }
        return nil
    }

    /// 표기 차이를 지운 비교 키. 공백만 지운다 — 하이픈은 남긴다. `"SFMono-Regular"` 처럼
    /// 무게가 붙은 PostScript 전체 이름이 패밀리 `"SF Mono"` 로 잘못 접히면 안 된다.
    static func normalizedFamilyKey(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }
}
