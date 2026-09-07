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
        .package(path: "../Packages/LearnKit"),
        // Sparkle 는 소스가 아니라 **바이너리 XCFramework** 로 온다({#sparkle-updates}).
        // `exact:` 로 조이는 것은 이 저장소의 다른 의존과 같은 정책이고, 여기서는 이유가
        // 하나 더 있다 — Sparkle 은 `Contents/Frameworks/` 에 통째로 임베드되어 앱과
        // 함께 서명되므로, 버전이 조용히 올라가면 서명 대상 파일 목록이 바뀐다.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
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
                // 에디터 화면({#route-editor-screen}). `EditorUI`(CodeEditSourceEditor
                // 위의 무채색 테마)와 `LSPKit`(sourcekit-lsp)은 이 타깃의 의존이라
                // 전이로 함께 링크된다 — 앱이 직접 이름 부를 일이 없다.
                .product(name: "EditorFeature", package: "LearnKit"),
                .product(name: "ContentKit", package: "LearnKit"),
                .product(name: "LearnPersistence", package: "LearnKit"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            // LearnKit 의 uiSettings 와 동일해야 한다 — 격리 도메인이 타깃 경계에서
            // 어긋나면 뷰 코드에 @MainActor 가 다시 번진다.
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ],
            // SPM 은 "앱 번들" 개념이 없어서 XCFramework 를 `.build/` 안의 경로로만
            // rpath 에 넣는다. 조립된 `.app` 에서도 Sparkle.framework 를 찾게 하려면
            // 번들 상대 rpath 가 하나 더 필요하다 — Scripts/build-app.sh 가 프레임워크를
            // `Contents/Frameworks/` 에 복사하는 것과 짝이다. 이게 없으면 앱은 빌드는
            // 되지만 실행 시 dyld 가 Sparkle 을 못 찾아 즉사한다.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
