// swift-tools-version: 6.2
import PackageDescription

/// 코어 계층: 격리 기본값은 `nonisolated`. 값 타입과 `Sendable` 로 경계를 강제한다.
/// UI 계층 타깃이 생기면 `.defaultIsolation(MainActor.self)` 를 붙인 별도 설정을 쓴다.
/// UI 계층: 기본 격리를 MainActor 로 뒤집는다(SE-0466). 뷰 코드에서 @MainActor 도배가 사라지고,
/// 코어 타깃(nonisolated 기본)과의 경계가 "타깃 = 격리 도메인" 으로 물리적으로 드러난다.
let uiSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

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
        .library(name: "ContentKit", targets: ["ContentKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "DashboardFeature", targets: ["DashboardFeature"]),
        .library(name: "LessonFeature", targets: ["LessonFeature"]),
        .library(name: "ReviewFeature", targets: ["ReviewFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.11.1")),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
    ],
    targets: [
        .target(name: "LearnCore", swiftSettings: coreSettings),
        .target(name: "LanguageKit", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        .target(
            name: "LearnPersistence",
            dependencies: ["LearnCore", .product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: coreSettings
        ),
        .target(
            name: "LearnScheduling",
            dependencies: ["LearnCore"],
            // 벤더링 근거 문서. 소스 트리 옆에 있어야 의미가 있으므로 타깃에서 제외만 한다.
            exclude: ["Vendor/FSRS/VENDORING.md"],
            swiftSettings: coreSettings
        ),
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
        .target(
            name: "ContentKit",
            dependencies: ["LearnCore", .product(name: "Markdown", package: "swift-markdown")],
            swiftSettings: coreSettings
        ),
        .testTarget(name: "LearnCoreTests", dependencies: ["LearnCore"], swiftSettings: coreSettings),
        .target(name: "DesignSystem", swiftSettings: uiSettings),
        .target(
            name: "OnboardingFeature",
            dependencies: ["LearnCore", "LanguageKit", "RunnerKit", "DesignSystem"],
            path: "Sources/Features/OnboardingFeature",
            swiftSettings: uiSettings
        ),
        .target(
            name: "DashboardFeature",
            dependencies: ["LearnCore", "LearnPersistence", "DesignSystem"],
            path: "Sources/Features/DashboardFeature",
            swiftSettings: uiSettings
        ),
        .target(
            name: "LessonFeature",
            dependencies: ["LearnCore", "LanguageKit", "ContentKit", "RunnerKit", "DesignSystem"],
            path: "Sources/Features/LessonFeature",
            swiftSettings: uiSettings
        ),
        .target(
            name: "ReviewFeature",
            dependencies: ["LearnCore", "LearnScheduling", "LearnPersistence", "DesignSystem"],
            path: "Sources/Features/ReviewFeature",
            swiftSettings: uiSettings
        ),
        .testTarget(name: "ContentKitTests", dependencies: ["ContentKit"], swiftSettings: coreSettings),
        .testTarget(name: "DashboardFeatureTests", dependencies: ["DashboardFeature"], swiftSettings: uiSettings),
        .testTarget(name: "LessonFeatureTests", dependencies: ["LessonFeature"], swiftSettings: uiSettings),
        .testTarget(name: "ReviewFeatureTests", dependencies: ["ReviewFeature"], swiftSettings: uiSettings),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: uiSettings),
        .testTarget(name: "OnboardingFeatureTests", dependencies: ["OnboardingFeature"], swiftSettings: uiSettings),
        .testTarget(
            name: "LearnPersistenceTests",
            // LearnScheduling 은 "진짜 드라이버 + 진짜 FSRS + 진짜 SQLite" 조합을 한 번
            // 태워 보기 위해서만 붙는다. 프로덕션 의존 방향(Persistence 는 Scheduling 을
            // 모른다)은 그대로다 — 테스트 타깃만 둘을 함께 본다.
            dependencies: ["LearnPersistence", "LearnScheduling"],
            swiftSettings: coreSettings
        ),
        .testTarget(
            name: "LearnSchedulingTests",
            dependencies: ["LearnScheduling"],
            // 골든 픽스처는 `Bundle.module` 로 읽는다. `.copy` 라서 번들 안에서도
            // `Fixtures/` 디렉터리 구조가 그대로 유지된다.
            resources: [.copy("Fixtures")],
            swiftSettings: coreSettings
        ),
        .testTarget(name: "RunnerKitTests", dependencies: ["RunnerKit"], swiftSettings: coreSettings),
    ]
)
