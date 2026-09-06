public import Foundation

/// Swift 과제 채점이 쓰는 예열된 SwiftPM 템플릿의 자리.
///
/// **머신 전역으로 고정된 경로를 쓰면 안 된다.** 병렬 워크트리에서 두 세션이 같은
/// `.build` 를 공유하면 SwiftPM 락이 걸리고, 대기 끝에 **이전 실행의 결과가 반환된다**
/// (실측: `LanguageSwiftGradingTests` 가 4~9건 실패했고 두 세션이 독립적으로 재현했다).
/// 그래서 팩 디렉터리의 실제 경로를 해시해 이름에 붙인다 — 같은 팩의 반복 검증은
/// 여전히 예열을 재사용하고, 다른 체크아웃끼리만 갈린다.
///
/// 한 프로세스 안의 동시 채점은 ``SwiftTestingGrader`` 가 액터라서 자연히 직렬화된다.
public enum SwiftTemplateLocation {
    public static func directory(for packDirectory: URL) -> URL {
        // resolvingSymlinksInPath 로 /var → /private/var 를 먼저 접는다. 같은 팩을
        // 다른 이름으로 가리켜도 같은 템플릿을 쓰게 하려는 것이다.
        let key = packDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("packtool-swift-template-\(fnv1a(key))", isDirectory: true)
    }

    /// FNV-1a 64bit 을 36진수로. 짧고 파일 이름에 안전하다.
    static func fnv1a(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 36)
    }
}
