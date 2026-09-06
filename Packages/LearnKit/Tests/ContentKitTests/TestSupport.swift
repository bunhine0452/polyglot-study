import Foundation
import Testing

@testable import ContentKit

/// 리포 안의 고정 경로를 찾는다.
///
/// `Bundle.module` 을 쓰지 않는 이유는 `Package.swift` 에 손대지 않기로 했기 때문이다
/// (ContentKitTests 에 `resources:` 선언이 없다). `#filePath` 는 컴파일 시점에 박히므로
/// 소스가 있는 개발·CI 환경에서 결정적으로 동작한다.
enum RepoPaths {
    /// `<repo>/` — 이 파일에서 다섯 단계 위.
    static var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    /// 리포에 커밋된 샘플 팩.
    static var samplePack: URL {
        root.appendingPathComponent("Content/packs/polyglot-mvp", isDirectory: true)
    }

    static var packFormatSpec: URL {
        root.appendingPathComponent("docs/pack-format.md")
    }
}

/// 테스트마다 새로 만들고 끝나면 통째로 지우는 임시 디렉터리.
///
/// **정리를 `deinit` 에 걸지 않는다.** Swift 는 지역 변수의 수명을 스코프 끝까지
/// 보장하지 않아서, 마지막 사용 직후 ARC 가 객체를 놓아 버리면 테스트가 아직 쓰고 있는
/// 디렉터리가 사라진다. 실제로 그 함정을 한 번 밟았다 — 설치 테스트가 무작위로 실패했다.
/// 그래서 수명은 ``withTemporaryDirectory(_:_:)`` 의 스코프가 쥔다.
final class TemporaryDirectory {
    let url: URL

    init(_ name: String = "contentkit") {
        url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: url)
    }

    func child(_ component: String) -> URL {
        url.appendingPathComponent(component, isDirectory: true)
    }

    /// 파일 하나를 상대 경로에 쓴다. 부모 디렉터리는 알아서 만든다.
    @discardableResult
    func write(_ contents: String, to relativePath: String) -> URL {
        let target = url.appendingPathComponent(relativePath)
        try? FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(contents.utf8).write(to: target)
        return target
    }

    /// 디렉터리 트리를 복사한다.
    func copyTree(from source: URL, to relativePath: String) {
        let target = url.appendingPathComponent(relativePath, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: source, to: target)
    }

    /// 디렉터리 안의 항목 개수 (숨김 포함). 잔여물 0 을 단언할 때 쓴다.
    func entryCount(at relativePath: String = ".") -> Int {
        let target =
            relativePath == "." ? url : url.appendingPathComponent(relativePath, isDirectory: true)
        let contents = try? FileManager.default.contentsOfDirectory(atPath: target.path)
        return contents?.count ?? 0
    }
}

/// 임시 디렉터리를 만들고, 클로저가 끝나면 반드시 지운다.
func withTemporaryDirectory<T>(
    _ name: String = "contentkit", _ body: (TemporaryDirectory) throws -> T
) rethrows -> T {
    let temporary = TemporaryDirectory(name)
    defer { temporary.cleanUp() }
    return try body(temporary)
}

extension FileManager {
    func exists(_ url: URL) -> Bool { fileExists(atPath: url.path) }
}
