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
        .library(name: "EditorUI", targets: ["EditorUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.11.1")),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
        // 벤더링된 CodeEditSourceEditor. 0.15.2 에 업스트림 PR #355(머지 대기, 죽은
        // CodeEditSymbols 의존 제거)를 적용했다 — `swift build`/`swift test` CLI 경로에서
        // CodeEditSymbols 의 Package.swift 가 리소스를 선언하지 않아 Bundle.module 생성이
        // 실패하는 문제였다(`xcodebuild` 경로는 원래 통과했다). 경위·로컬 수정 목록은
        // `Vendor/CodeEditSourceEditor/VENDORING.md`.
        //
        // 그 아래에서 전이 의존하는 CodeEditLanguages(`exact: 0.1.20`)는 이쪽에서 손댈 수
        // 없고(exact 핀), 그 저장소 자체에 LICENSE 파일이 없다 — CodeEdit 조직의 나머지
        // 저장소(CodeEdit·CodeEditSourceEditor·CodeEditTextView)가 전부 MIT 이고 README
        // 태그라인이 "Open source, free forever" 라 정책이 아니라 누락으로 판단한다.
        .package(path: "../../Vendor/CodeEditSourceEditor"),
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
        // `LearnCore` 하나만 본다. 프리젠터가 `GradeResult.Presenter` 와 `ResultSet` 을
        // **그대로** 받기 위해서다 — 이 의존이 없던 동안 디자인 시스템은 두 타입을 옮겨
        // 적은 미러(`ResultPresentation`·`ResultTable`)를 들고 있었고, 화면 계층에 그
        // 둘을 잇는 변환기가 하나 더 있었다.
        //
        // `LearnCore` 는 값 타입과 프로토콜만 있는 모듈이다(GRDB·Subprocess 를 모른다).
        // 스토어·러너가 있는 `LearnPersistence`·`RunnerKit` 은 여기서 보이면 안 되고,
        // `LanguageKit` 도 붙이지 않는다 — 필요한 쪽은 `ModuleAvailability` 를 쓰는
        // `DashboardFeature` 이지 디자인 시스템이 아니다.
        .target(name: "DesignSystem", dependencies: ["LearnCore"], swiftSettings: uiSettings),
        .target(
            name: "OnboardingFeature",
            dependencies: ["LearnCore", "LanguageKit", "RunnerKit", "DesignSystem"],
            path: "Sources/Features/OnboardingFeature",
            swiftSettings: uiSettings
        ),
        .target(
            name: "DashboardFeature",
            // `LanguageKit` 은 툴체인 열 때문에 붙는다. 감지 결과를 받는 포트가
            // `ModuleAvailability` 를 **그대로** 실어 나른다 — 그 타입을 못 보던 동안
            // 여기 ready·missing·stub 을 다시 적은 열거형이 있었다. 감지를 실제로
            // 수행하는 `RunnerKit` 은 여전히 보이지 않는다(포트는 결과만 받는다).
            dependencies: ["LearnCore", "LanguageKit", "LearnPersistence", "DesignSystem"],
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
        // 벤더링된 CodeEditSourceEditor 위에 무채색 테마·조인 설정을 얹는 층. 자세한 경위는
        // 위 `dependencies` 의 주석과 `Vendor/CodeEditSourceEditor/VENDORING.md`.
        .target(
            name: "EditorUI",
            dependencies: [
                "DesignSystem",
                .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor"),
            ],
            swiftSettings: uiSettings
        ),
        .testTarget(name: "ContentKitTests", dependencies: ["ContentKit"], swiftSettings: coreSettings),
        .testTarget(name: "DashboardFeatureTests", dependencies: ["DashboardFeature"], swiftSettings: uiSettings),
        .testTarget(name: "LessonFeatureTests", dependencies: ["LessonFeature"], swiftSettings: uiSettings),
        .testTarget(name: "ReviewFeatureTests", dependencies: ["ReviewFeature"], swiftSettings: uiSettings),
        .testTarget(name: "EditorUITests", dependencies: ["EditorUI"], swiftSettings: uiSettings),
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
