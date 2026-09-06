internal import AppKit
internal import SwiftUI
internal import DesignSystem

/// `Typography.Sans` 크기를 실제 `Font` 로 바꾼다.
///
/// `DesignSystem` 은 이 변환을 `LabelText`·`MonoText`·`FlatButton` 같은 고정 크기
/// 프리미티브 뒤에서만 내부적으로 한다(`AppFont` 는 internal). 이 화면의 제목·질문·답
/// 본문은 그 프리미티브들이 커버하는 크기(11px 라벨, 모노, 36px 버튼)가 아니라서
/// `Typography.Sans` 를 직접 골라야 하고, 그러려면 해석이 필요하다. `OnboardingFeature`
/// 가 프리미티브 완성 전에 같은 이유로 `Internal/FontResolution.swift` 를 둔 것과 같은
/// 상황이다 — 차이는 그쪽은 프리미티브 자체의 임시 대역이었고, 여기는 프리미티브가 다루지
/// 않는 크기의 해석기라는 것.
extension Font {
    static func reviewSans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        let family = NSFont(name: Typography.sansFamily, size: size.rawValue) != nil
            ? Typography.sansFamily
            : Typography.sansFallback
        return .custom(family, size: size.rawValue).weight(weight)
    }
}
