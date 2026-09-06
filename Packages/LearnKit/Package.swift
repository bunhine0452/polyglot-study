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
        .library(name: "LearnPersistence", targets: ["LearnPersistence"]),
        .library(name: "LearnScheduling", targets: ["LearnScheduling"]),
        .library(name: "RunnerKit", targets: ["RunnerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.11.1")),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "LearnCore", swiftSettings: coreSettings),
        .target(name: "LanguageKit", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        .target(
            name: "LearnPersistence",
            dependencies: ["LearnCore", .product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: coreSettings
        ),
        .target(name: "LearnScheduling", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        // 사용자 코드에 rlimit 을 거는 exec 래퍼. `preSpawnProcessConfigurator` 는 부모에서
        // 돌기 때문에 setrlimit 을 거기서 부르면 앱 자신에게 걸린다 — 그래서 별도 헬퍼가 필요하다.
        .executableTarget(name: "learn-launcher"),
        .target(
            name: "RunnerKit",
            dependencies: [
                "LearnCore",
                "LanguageKit",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            swiftSettings: coreSettings
        ),
        .testTarget(name: "LearnCoreTests", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        .testTarget(name: "LearnPersistenceTests", dependencies: ["LearnPersistence"], swiftSettings: coreSettings),
        .testTarget(name: "LearnSchedulingTests", dependencies: ["LearnScheduling"], swiftSettings: coreSettings),
        .testTarget(name: "RunnerKitTests", dependencies: ["RunnerKit"], swiftSettings: coreSettings),
    ]
)
