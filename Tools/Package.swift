// swift-tools-version: 6.2
import PackageDescription

/// 앱과 분리된 개발자 도구 패키지.
///
/// `Packages/LearnKit` 과 **별도 패키지**인 이유는 하나다 — `swift-argument-parser` 가
/// 앱 산출물에 링크되지 않게 하기 위해서다. LearnKit 에 실행 파일 타깃을 얹으면 CLI 전용
/// 의존성이 앱과 같은 의존성 그래프에 들어온다. 의존 방향은 Tools → LearnKit 단방향이며
/// LearnKit 은 Tools 의 존재를 모른다.
let toolSettings: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "Tools",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "packtool", targets: ["packtool"]),
        .executable(name: "lessongen", targets: ["lessongen"]),
    ],
    dependencies: [
        .package(path: "../Packages/LearnKit"),
        // 최신 안정 태그는 1.8.2 (2026-09-06 확인). 마이너 상한을 걸어 CLI 표면이
        // 조용히 바뀌지 않게 한다.
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.8.2")),
    ],
    targets: [
        // Anthropic Messages API 클라이언트. Swift 공식 SDK 가 없어 URLSession 으로 직접
        // 호출한다. 요청 조립과 응답 해석은 순수 함수로 떼어 두어 네트워크 없이 검증된다.
        .target(name: "AnthropicKit", swiftSettings: toolSettings),
        // 트랙 개요 도메인 — 스키마·프롬프트·조립·검증. CLI 는 여기에 얇게 얹힌다.
        .target(
            name: "LessonGenKit",
            dependencies: [
                "AnthropicKit",
                .product(name: "LearnCore", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        .executableTarget(
            name: "lessongen",
            dependencies: [
                "LessonGenKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: toolSettings
        ),
        // 콘텐츠 팩 검증·빌드·서명 CLI. 실구현은 플래너의 {#packtool-*} 항목이고 다른
        // 작업이다 — 여기서는 자리만 잡는다. 의존성이 비어 있는 것은 의도다.
        .executableTarget(name: "packtool", swiftSettings: toolSettings),

        .target(
            name: "TestSupport",
            dependencies: ["AnthropicKit"],
            path: "Tests/TestSupport",
            swiftSettings: toolSettings
        ),
        .testTarget(
            name: "AnthropicKitTests",
            dependencies: ["AnthropicKit", "TestSupport"],
            swiftSettings: toolSettings
        ),
        .testTarget(
            name: "LessonGenKitTests",
            dependencies: ["LessonGenKit", "TestSupport"],
            swiftSettings: toolSettings
        ),
    ]
)
