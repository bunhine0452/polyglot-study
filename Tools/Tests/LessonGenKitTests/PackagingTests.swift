import Foundation
import Testing

/// Tools 가 LearnKit 과 **별도 패키지**인 이유를 못 박는 테스트.
///
/// 누군가 편하다고 `packtool`·`lessongen` 을 LearnKit 으로 옮기면 `swift-argument-parser`
/// 가 앱 의존성 그래프에 들어온다. 그 순간 이 스위트가 빨개진다.
@Suite("패키지 경계")
struct PackagingTests {
    /// 리포지토리 루트. `Tools/Tests/LessonGenKitTests/…` 에서 네 단계 위.
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // LessonGenKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Tools
            .deletingLastPathComponent()  // <repo>
    }

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repositoryRoot.appending(path: relativePath), encoding: .utf8)
    }

    @Test("LearnKit 은 ArgumentParser 를 의존하지 않는다")
    func learnKitDoesNotDependOnArgumentParser() throws {
        let manifest = try read("Packages/LearnKit/Package.swift")
        #expect(!manifest.lowercased().contains("argument-parser"))
        #expect(!manifest.contains("ArgumentParser"))

        let resolved = try read("Packages/LearnKit/Package.resolved")
        #expect(!resolved.lowercased().contains("argument-parser"))
    }

    @Test("Tools 는 ArgumentParser 를 정확한 버전으로 물고 있다")
    func toolsPinsArgumentParser() throws {
        let resolved = try read("Tools/Package.resolved")
        #expect(resolved.lowercased().contains("swift-argument-parser"))
    }

    @Test("packtool 은 ArgumentParser 를 링크하지 않는다 — 아직 스텁이다")
    func packtoolIsDependencyFree() throws {
        let manifest = try read("Tools/Package.swift")
        let stub = try read("Tools/Sources/packtool/main.swift")
        #expect(manifest.contains(#".executableTarget(name: "packtool", swiftSettings: toolSettings)"#))
        #expect(!stub.contains("import ArgumentParser"))
    }

    @Test("의존 방향은 Tools → LearnKit 단방향이다")
    func dependencyDirection() throws {
        #expect(try read("Tools/Package.swift").contains(#".package(path: "../Packages/LearnKit")"#))
        #expect(!(try read("Packages/LearnKit/Package.swift").contains("Tools")))
    }
}
