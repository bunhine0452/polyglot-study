// swift-tools-version: 6.2
import PackageDescription

/// 코어 계층: 격리 기본값은 `nonisolated`. 값 타입과 `Sendable` 로 경계를 강제한다.
/// UI 계층 타깃이 생기면 `.defaultIsolation(MainActor.self)` 를 붙인 별도 설정을 쓴다.
let coreSettings: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "LearnKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LearnCore", targets: ["LearnCore"]),
        .library(name: "LanguageKit", targets: ["LanguageKit"]),
    ],
    targets: [
        .target(name: "LearnCore", swiftSettings: coreSettings),
        .target(name: "LanguageKit", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        .testTarget(name: "LearnCoreTests", dependencies: ["LearnCore"], swiftSettings: coreSettings),
    ]
)
