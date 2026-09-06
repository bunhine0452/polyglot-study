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
        // 공급자 중립 LLM 경계. `LLMProvider` 프로토콜과 그 주변(키 취급·재시도·로그
        // 마스킹·계약 스위트)만 산다. **여기에는 어떤 공급자의 와이어 타입도 없다** —
        // 로컬 MLX 백엔드가 붙는 날 이 타깃이 그대로 재사용되어야 하기 때문이다.
        // `LanguageKit` 이 `CodeRunner` 를 들고 백엔드는 `RunnerKit` 에 두는 것과 같은 배치다.
        /// packtool 이 쓰고 lessongen 이 읽는 유일한 계약. 두 실행 파일 밖에 둬야
        /// 한쪽이 다른 쪽 내부 타입에 손을 뻗지 않는다.
        .target(name: "PackReport", swiftSettings: toolSettings),
        .target(name: "LLMKit", swiftSettings: toolSettings),
        // OpenRouter 구현. OpenAI 호환 chat/completions 를 URLSession 으로 직접 친다.
        // 요청 조립과 응답 해석은 순수 함수로 떼어 두어 네트워크 없이 검증된다.
        .target(name: "OpenRouterKit", dependencies: ["LLMKit"], swiftSettings: toolSettings),
        // 트랙 개요·레슨 본문·수리 루프의 도메인. 스키마·프롬프트·조립·검증·직렬화.
        // CLI 는 여기에 얇게 얹힌다.
        //
        // **LLMKit 만 의존한다** — 어느 공급자를 쓸지는 CLI 가 정한다.
        //
        // `ContentKit` 을 무는 이유는 하나다. 이 타깃이 만드는 것은 **디렉티브
        // 마크다운**이고, 그 문법의 유일한 권위는 `LessonParser`·`DirectiveSourceLint`
        // 다. 직렬화기가 자기 산출물을 그 파서에 곧바로 태워 보고 나서야 파일을 쓰기
        // 때문에 (`LessonSerializer.serializeChecked`), 생성물이 `packtool` 의 문법
        // 단계에 처음 닿는 순간이 **디스크에 쓰이기 전**이다. 문법 규칙을 여기 다시
        // 적으면 두 벌이 되고 곧 어긋난다.
        .target(
            name: "LessonGenKit",
            dependencies: [
                "LLMKit",
                "PackReport",
                .product(name: "LearnCore", package: "LearnKit"),
                .product(name: "ContentKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        .executableTarget(
            name: "lessongen",
            dependencies: [
                "LessonGenKit",
                "OpenRouterKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: toolSettings
        ),
        // 팩 검증 게이트의 로직 전부. CLI 와 나눠 둔 이유는 테스트다 — 실행 파일
        // 타깃에 로직이 있으면 단계별 단위 테스트를 붙일 수 없고, 게이트는 자기 자신이
        // 검증되지 않으면 아무것도 보장하지 못한다.
        .target(
            name: "PackValidate",
            dependencies: [
                "PackReport",
                .product(name: "LearnCore", package: "LearnKit"),
                .product(name: "LanguageKit", package: "LearnKit"),
                .product(name: "ContentKit", package: "LearnKit"),
                // 실행 게이트가 태우는 백엔드. `SubprocessRunner`(python·swift) 와
                // `InProcessRunner`(sql) 를 앱과 **같은 코드로** 태워야 게이트가 의미를 갖는다.
                .product(name: "RunnerKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        // 배포 팩을 굽는 쪽. 검증(`PackValidate`)과 나눠 둔 이유는 의존성이다 — 굽기는
        // 툴체인도 러너도 쓰지 않는다(`ContentKit` 하나만 본다). 검증 게이트를 부르는
        // 것은 CLI 의 일이고, 그래야 "굽기" 자체를 러너 없이 테스트할 수 있다.
        .target(
            name: "PackBuild",
            dependencies: [
                .product(name: "LearnCore", package: "LearnKit"),
                .product(name: "ContentKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        // 콘텐츠 팩 검증·빌드·서명 CLI. 로직은 전부 PackValidate·PackBuild 에 있고
        // 여기는 플래그·종료 코드·출력 형식만 본다.
        .executableTarget(
            name: "packtool",
            dependencies: [
                "PackReport",
                "PackValidate",
                "PackBuild",
                .product(name: "ContentKit", package: "LearnKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: toolSettings
        ),

        .target(
            name: "TestSupport",
            dependencies: ["LLMKit"],
            path: "Tests/TestSupport",
            swiftSettings: toolSettings
        ),
        .testTarget(name: "PackReportTests", dependencies: ["PackReport"], swiftSettings: toolSettings),
        .testTarget(
            name: "PackBuildTests",
            dependencies: [
                "PackBuild",
                .product(name: "ContentKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        .testTarget(
            name: "PackValidateTests",
            dependencies: [
                "PackValidate",
                "PackReport",
                .product(name: "ContentKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
        // CLI 표면(플래그·종료 코드·리포트 형식)만 본다. 로직은 PackValidateTests 가 본다.
        .testTarget(name: "packtoolTests", dependencies: ["packtool"], swiftSettings: toolSettings),
        .testTarget(
            name: "LLMKitTests",
            dependencies: ["LLMKit", "TestSupport"],
            swiftSettings: toolSettings
        ),
        .testTarget(
            name: "OpenRouterKitTests",
            dependencies: ["OpenRouterKit", "TestSupport"],
            swiftSettings: toolSettings
        ),
        .testTarget(
            name: "LessonGenKitTests",
            dependencies: [
                "LessonGenKit",
                "TestSupport",
                "PackReport",
                .product(name: "ContentKit", package: "LearnKit"),
            ],
            swiftSettings: toolSettings
        ),
    ]
)
