// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// 벤더링된 패키지. 로컬 수정 내역은 VENDORING.md 를 봐라 — 요약하면 업스트림 PR #355
// (병합 전, CodeEditSymbols 죽은 의존 제거)를 0.15.2 위에 적용했고, 소비하지 않는
// Tests/ 타깃과 SwiftLint 빌드 플러그인도 함께 뺐다(이유는 VENDORING.md — 얼어붙은
// 벤더 소스에 린터를 돌리는 건 우리가 통제할 수 없는 빌드 경고 소스가 된다).
let package = Package(
    name: "CodeEditSourceEditor",
    platforms: [.macOS(.v13)],
    products: [
        // A source editor with useful features for code editing.
        .library(
            name: "CodeEditSourceEditor",
            targets: ["CodeEditSourceEditor"]
        )
    ],
    dependencies: [
        // A fast, efficient, text view for code.
        .package(
            url: "https://github.com/CodeEditApp/CodeEditTextView.git",
            from: "0.12.1"
        ),
        // tree-sitter languages
        .package(
            url: "https://github.com/CodeEditApp/CodeEditLanguages.git",
            exact: "0.1.20"
        ),
        // Rules for indentation, pair completion, whitespace
        .package(
            url: "https://github.com/ChimeHQ/TextFormation",
            from: "0.8.2"
        ),
    ],
    targets: [
        // A source editor with useful features for code editing.
        .target(
            name: "CodeEditSourceEditor",
            dependencies: [
                "CodeEditTextView",
                "CodeEditLanguages",
                "TextFormation",
            ]
        ),
    ]
)
