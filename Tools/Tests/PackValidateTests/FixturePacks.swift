import Foundation
import Testing

/// 런타임에 만든 문자열을 `#expect` 의 설명으로 넘긴다.
///
/// `Comment` 는 `ExpressibleByStringLiteral` 이지만 보간 리터럴은 받지 않는다 —
/// 리포트 전문을 실패 메시지에 붙이려면 이 래퍼가 필요하다.
func note(_ text: String) -> Comment { Comment(rawValue: text) }

/// 픽스처 팩과 리포의 실제 샘플 팩을 찾는다.
///
/// `Bundle.module` 이 아니라 `#filePath` 를 쓰는 이유는 팩이 **디렉터리 트리 그대로**
/// 읽혀야 하기 때문이다. 리소스로 복사하면 상대 경로 레이아웃이 번들 규칙에 휘둘리고,
/// 검증기가 보는 것은 실제 팩 디렉터리여야 한다.
enum FixturePacks {
    /// `Tools/Tests`
    static let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // PackValidateTests
        .deletingLastPathComponent()  // Tests

    /// `Tools`
    static let toolsRoot = testsRoot.deletingLastPathComponent()

    /// 리포 루트.
    static let repositoryRoot = toolsRoot.deletingLastPathComponent()

    /// 구조·문법·의미·실행 네 단계를 전부 통과해야 하는 기준 팩 (python + sql).
    static let valid = testsRoot.appendingPathComponent("Fixtures/packs/fixture-mvp", isDirectory: true)

    /// 리포에 실재하는 MVP 샘플 팩 (python + sql + swift).
    static let samplePack = repositoryRoot.appendingPathComponent(
        "Content/fixtures/polyglot-mvp", isDirectory: true)

    /// 팩을 임시 디렉터리로 복사한다. 호출자가 지운다.
    static func copyToTemporary(_ source: URL, label: String) throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("packtool-fixture-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let inner = destination.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        try FileManager.default.copyItem(at: source, to: inner)
        return inner
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
