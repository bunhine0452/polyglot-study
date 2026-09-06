internal import AppKit
internal import DesignSystem
internal import SwiftUI

/// `Typography` 토큰의 패밀리 이름을 실제 `Font` 로 바꾼다.
///
/// `DesignSystem` 에도 같은 일을 하는 `AppFont` 가 있지만 **internal** 이라 다른 모듈에서
/// 부를 수 없다. 프리미티브(`LabelText`·`MonoText`·`FlatButton`)가 감싸 주지 않는 텍스트
/// — 트랙 이름, 레슨 제목, 큰 숫자 — 는 화면이 직접 폰트를 잡아야 하므로 여기서 해석한다.
/// `OnboardingFeature/Internal/FontResolution.swift` 와 같은 이유의 같은 코드다.
/// `DesignSystem` 이 폰트 접근자를 공개하면 두 파일 다 지운다.
extension Font {
    static func dashSans(_ size: Typography.Sans, weight: Font.Weight = .regular) -> Font {
        let family = NSFont(name: Typography.sansFamily, size: size.rawValue) != nil
            ? Typography.sansFamily
            : Typography.sansFallback
        return .custom(family, size: size.rawValue).weight(weight)
    }
}
