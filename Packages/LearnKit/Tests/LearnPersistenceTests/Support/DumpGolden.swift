import Foundation
import Testing
@testable import LearnPersistence

/// 골든 스키마 픽스처를 다시 굽는 도구.
///
/// 평소에는 비활성이다. 마이그레이션을 **새 번호로** 추가한 뒤에만 켠다:
///
/// ```
/// LEARNKIT_REGENERATE_GOLDEN=1 swift test --filter regenerateGoldenSchema
/// ```
///
/// 그러면 `Tests/LearnPersistenceTests/Support/GoldenSchema.swift` 가 다시 쓰인다.
/// 환경변수 없이는 아무것도 하지 않는다 — 골든을 실수로 덮어쓰면 스냅샷 테스트가 의미를 잃는다.
@Suite("골든 스키마 재생성 도구")
struct DumpGoldenTests {
    @Test("regenerateGoldenSchema")
    func regenerateGoldenSchema() throws {
        guard ProcessInfo.processInfo.environment["LEARNKIT_REGENERATE_GOLDEN"] == "1" else { return }

        let harness = try TestDatabase(.inMemory)
        let dump = try harness.database.schemaDump()

        let target = SourceTree.packageRoot
            .appendingPathComponent("Tests/LearnPersistenceTests/Support/GoldenSchema.swift")
        let contents = """
            // 이 파일은 생성물이다. 손으로 고치지 말고 아래 명령으로 다시 굽는다.
            //
            //   LEARNKIT_REGENERATE_GOLDEN=1 swift test --filter regenerateGoldenSchema
            //
            // 다시 구워야 하는 유일한 경우는 **새 번호의 마이그레이션을 추가했을 때**다.
            // 기존 마이그레이션을 고쳐서 이 파일이 바뀐다면 그건 정책 위반이고, 되돌려야 한다.

            enum GoldenSchema {
                static let dump = \"\"\"
            \(dump.split(separator: "\n", omittingEmptySubsequences: false)
                .map { "    " + $0 }
                .joined(separator: "\n"))
                \"\"\"
            }

            """
        try contents.write(to: target, atomically: true, encoding: .utf8)
    }
}
