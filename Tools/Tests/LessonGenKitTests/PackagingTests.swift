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

    /// 원래 이 자리에는 "packtool 은 아직 스텁이다" 를 매니페스트 문자열로 고정하는 테스트가
    /// 있었다. 구현이 시작되는 순간 사라질 사실이라, 구현 뒤에도 지켜야 하는 경계로 바꿨다.
    ///
    /// **두 실행 파일은 서로를 모른다.** packtool 이 검증 결과를 쓰고 lessongen 이 그걸 읽어
    /// 실패한 레슨만 재생성하는데, 그 통로는 `PackReport` 하나뿐이어야 한다. 한쪽이 다른 쪽
    /// 내부 타입에 손을 뻗기 시작하면 "검증기와 생성기가 같은 가정을 공유한다" 는 사고가 난다 —
    /// 생성기가 검증기의 약점을 우회하게 되기 때문이다.
    @Test("packtool 과 lessongen 은 서로를 직접 의존하지 않는다")
    func executablesCommunicateOnlyThroughPackReport() throws {
        let manifest = try read("Tools/Package.swift")

        func dependencies(ofTarget name: String) -> String {
            guard let start = manifest.range(of: #"name: "\#(name)""#) else { return "" }
            let tail = manifest[start.upperBound...]
            // 다음 타깃 선언 전까지를 이 타깃의 블록으로 본다.
            let end = tail.range(of: "\n        ." )?.lowerBound ?? tail.endIndex
            return String(tail[..<end])
        }

        #expect(!dependencies(ofTarget: "packtool").contains("lessongen"))
        #expect(!dependencies(ofTarget: "lessongen").contains("packtool"))
        #expect(manifest.contains(#".target(name: "PackReport""#), "공유 계약 타깃이 있어야 한다")
    }

    @Test("의존 방향은 Tools → LearnKit 단방향이다")
    func dependencyDirection() throws {
        #expect(try read("Tools/Package.swift").contains(#".package(path: "../Packages/LearnKit")"#))
        #expect(!(try read("Packages/LearnKit/Package.swift").contains("Tools")))
    }
}
