internal import AppKit
internal import SwiftUI
internal import DesignSystem

/// `Typography` 토큰이 이름만 가진 폰트 패밀리를 실제 `Font` 로 바꾼다.
///
/// 패밀리가 등록돼 있지 않으면(이 패키지는 폰트를 등록하지 않는다 — 앱 타깃의 몫이다)
/// `Typography.*Fallback` 으로 넘어간다. `DesignSystem` 에 이 변환을 해 줄 프리미티브가
/// 아직 없어서 임시로 여기 둔다 — 프리미티브가 나오면 지운다.
extension Font {
    static func appSans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        let family = NSFont(name: Typography.sansFamily, size: size.rawValue) != nil
            ? Typography.sansFamily
            : Typography.sansFallback
        return .custom(family, size: size.rawValue).weight(weight)
    }

    static func appMono(_ size: Typography.Mono) -> Font {
        let family = NSFont(name: Typography.monoFamily, size: size.rawValue) != nil
            ? Typography.monoFamily
            : Typography.monoFallback
        return .custom(family, size: size.rawValue)
    }
}
