internal import AppKit
internal import SwiftUI

/// `Typography` 의 이름을 실제 `Font` 로 바꾸는 단 하나의 지점.
///
/// Plex 번들링(`{#plex-font-bundling}`)이 아직 붙지 않았으므로 지금은 폴백으로 떨어진다.
/// 폰트가 등록되면 이 파일을 고치지 않아도 자동으로 Plex 가 잡힌다 — 해석 순서가
/// `Typography.sansFamily` → `Typography.sansFallback` → 시스템이기 때문이다.
///
/// 뷰 코드가 `Font.custom` 을 직접 부르면 등록 실패 시 조용히 시스템 폰트로 떨어지면서
/// 어느 화면이 폴백인지 알 수 없게 된다. 그래서 해석을 여기 한 곳에 모은다.
enum AppFont {
    // MARK: - 산스

    static func sans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        sans(points: size.rawValue, weight: weight)
    }

    /// 타입 스케일에 없는 크기를 위한 탈출구. **프리미티브 안에서만** 쓴다 —
    /// 화면 코드는 `Typography.Sans` 를 거쳐야 한다.
    static func sans(points: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let family = resolvedSans {
            return .custom(family, fixedSize: points).weight(weight)
        }
        return .system(size: points, weight: weight)
    }

    // MARK: - 모노

    static func mono(_ size: Typography.Mono, weight: Font.Weight = .regular) -> Font {
        if let family = resolvedMono {
            return .custom(family, fixedSize: size.rawValue).weight(weight).monospacedDigit()
        }
        return .system(size: size.rawValue, weight: weight, design: .monospaced).monospacedDigit()
    }

    // MARK: - 해석

    /// 지금 이 머신에서 실제로 잡힌 산스 패밀리. `nil` 이면 시스템 폰트로 떨어진 것이다.
    static let resolvedSans: String? = firstAvailable([Typography.sansFamily, Typography.sansFallback])
    /// 지금 이 머신에서 실제로 잡힌 모노 패밀리. `nil` 이면 `.monospaced` 시스템 폰트다.
    static let resolvedMono: String? = firstAvailable([Typography.monoFamily, Typography.monoFallback])

    private static func firstAvailable(_ candidates: [String]) -> String? {
        let families = Set(NSFontManager.shared.availableFontFamilies)
        for candidate in candidates {
            // 패밀리명(`SF Mono`)과 PostScript 명(`SFMono-Regular`) 둘 다 받아들인다 —
            // 토큰이 어느 쪽으로 적혀 있든 동작해야 한다.
            if families.contains(candidate) || NSFont(name: candidate, size: 12) != nil {
                return candidate
            }
        }
        return nil
    }
}
