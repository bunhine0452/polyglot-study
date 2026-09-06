// swift-tools-version: 6.2
import PackageDescription

// MARK: - 왜 `.xcodeproj` 가 아니라 SPM executableTarget + 번들 조립 스크립트인가
//
// 계획 항목 `{#xcode-app-target}` 은 "Polyglot.xcodeproj 를 앱 타깃 하나만 담는 얇은 셸로"
// 였다. 실제로 만들어 본 판단은 아래와 같고, 결론은 **SPM 실행 타깃 + 번들 조립**이다.
//
// 1. pbxproj 는 손으로 쓰면 깨지고, Xcode 가 열 때마다 다시 쓴다. 로컬 SPM 패키지를
//    `XCLocalSwiftPackageReference` 로 물리는 부분이 특히 그렇다 — 리뷰 불가능한 diff 가
//    매 커밋 따라붙는다. 여기서 앱 타깃이 하는 일은 `PolyglotApp.swift` 한 파일을 컴파일하고
//    LearnKit 을 링크하는 것뿐이라, 그 대가를 치를 이유가 없다.
// 2. 잃는 것이 없다. 배포에 필요한 것은 전부 번들 **구조**이지 프로젝트 파일이 아니다.
//    - `{#notarize-staple-dmg}`: `codesign` · `notarytool` · `stapler` 는 `.app` 디렉터리를
//      받는다. Scripts/build-app.sh 가 만드는 번들은 Xcode 산출물과 같은 레이아웃이다.
//    - `{#plex-font-bundling}`: `ATSApplicationFontsPath` 는 앱 번들 `Contents/Resources`
//      에만 먹는다. 스크립트가 `Resources/Fonts/` 를 그 자리에 그대로 복사한다.
//    - `{#helper-signing}`: C 런처(`learn-launcher`)도 `Contents/MacOS/` 에 넣고 개별 서명한다.
// 3. 되돌릴 수 있다. 앱 타깃의 컴파일 소스가 한 파일이므로, Xcode 프로젝트가 정말 필요해지면
//    (예: Sparkle 을 프레임워크로 임베드) 그때 프로젝트를 만들고 이 파일을 그대로 넣으면 된다.
//
// 대가로 포기하는 것: Xcode 의 SwiftUI 프리뷰 캔버스와 `xcodebuild` 스킴. 프리뷰는 앱을
// 실제로 띄우는 것으로 대체하고(`Scripts/build-app.sh --run`), CI 는 `swift build` 를 쓴다.

let package = Package(
    name: "PolyglotApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Packages/LearnKit")
    ],
    targets: [
        .executableTarget(
            name: "PolyglotApp",
            dependencies: [
                .product(name: "DesignSystem", package: "LearnKit"),
                .product(name: "OnboardingFeature", package: "LearnKit"),
                .product(name: "DashboardFeature", package: "LearnKit"),
                .product(name: "LessonFeature", package: "LearnKit"),
                .product(name: "ReviewFeature", package: "LearnKit"),
                .product(name: "ContentKit", package: "LearnKit"),
                .product(name: "LearnPersistence", package: "LearnKit"),
            ],
            // LearnKit 의 uiSettings 와 동일해야 한다 — 격리 도메인이 타깃 경계에서
            // 어긋나면 뷰 코드에 @MainActor 가 다시 번진다.
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
