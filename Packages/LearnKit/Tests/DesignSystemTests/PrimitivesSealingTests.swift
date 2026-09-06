import Foundation
import SwiftUI
import Testing

@testable import DesignSystem

/// 라운딩·그림자·머티리얼이 **소스에 존재하지 않는다**는 것을 고정한다.
///
/// 타입 차원 봉인(파라미터를 노출하지 않음)만으로는 프리미티브 *안쪽*에서 몰래 쓰는 것을
/// 막지 못한다. 그래서 소스를 직접 읽어 금지 토큰을 센다 — `public import GRDB` 0건을
/// 지키는 코어의 grep 테스트와 같은 방식이다.
@Suite("디자인 시스템 · 금지 API 봉인")
struct PrimitivesSealingTests {
    /// 주석은 제외한다. 이 규칙을 설명하려면 금지어를 적을 수밖에 없기 때문이다.
    static func codeLines(of file: URL) throws -> [(line: Int, text: String)] {
        let source = try String(contentsOf: file, encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: String($0.element)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)      // .../Tests/DesignSystemTests/PrimitivesSealingTests.swift
            .deletingLastPathComponent()     // .../Tests/DesignSystemTests
            .deletingLastPathComponent()     // .../Tests
            .deletingLastPathComponent()     // .../LearnKit
            .appendingPathComponent("Sources/DesignSystem")
    }

    static var swiftFiles: [URL] {
        get throws {
            let root = sourceRoot
            var found: [URL] = []
            var stack = [root]
            while let dir = stack.popLast() {
                for entry in try FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: [.isDirectoryKey]
                ) {
                    if (try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        stack.append(entry)
                    } else if entry.pathExtension == "swift" {
                        found.append(entry)
                    }
                }
            }
            return found.sorted { $0.path < $1.path }
        }
    }

    @Test("소스 트리를 실제로 찾았고 프리미티브 6종 파일이 전부 있다")
    func sourceTreeIsWhereWeThink() throws {
        let names = Set(try Self.swiftFiles.map(\.lastPathComponent))
        let required = [
            "Rule.swift", "StatusDot.swift", "SegmentedProgress.swift",
            "MonoText.swift", "FlatButton.swift", "LabelText.swift",
        ]
        for name in required {
            #expect(names.contains(name), "\(name) 를 못 찾았다 — 소스 경로 계산이 틀렸을 수 있다")
        }
        #expect(names.contains("Tokens.swift"))
    }

    @Test("라운딩·그림자·머티리얼·시스템 컨테이너가 소스에 0건")
    func noRoundingNoShadowNoMaterial() throws {
        // 왜 각각이 금지인지: 앞의 셋은 이 디자인에 존재하지 않는 시각 요소이고,
        // 뒤의 넷은 그 셋을 **끄는 API 없이** 강제로 그리는 시스템 컨테이너다.
        let banned = [
            "cornerRadius", ".shadow(", "RoundedRectangle", "Capsule(", "ContainerRelativeShape",
            "Material", ".clipShape(", "buttonStyle(.bordered", "buttonStyle(.borderedProminent",
            "buttonStyle(.accessoryBar", "NavigationSplitView", "NavigationView", "GroupBox",
            "glassEffect", ".buttonBorderShape",
        ]
        var hits: [String] = []
        for file in try Self.swiftFiles {
            for (line, text) in try Self.codeLines(of: file) {
                for needle in banned where text.contains(needle) {
                    hits.append("\(file.lastPathComponent):\(line) — \(needle)")
                }
            }
        }
        #expect(hits.isEmpty, "금지 API 발견:\n\(hits.joined(separator: "\n"))")
    }

    @Test("프리미티브가 색 리터럴을 직접 쓰지 않는다 — Tokens.swift 만 예외")
    func noHexLiteralsOutsideTokens() throws {
        var hits: [String] = []
        for file in try Self.swiftFiles where file.lastPathComponent != "Tokens.swift" {
            for (line, text) in try Self.codeLines(of: file) {
                if text.contains("Color(hex:") || text.contains("Color(red:") || text.contains("Color(.sRGB") {
                    hits.append("\(file.lastPathComponent):\(line)")
                }
            }
        }
        #expect(hits.isEmpty, "토큰 밖 색 리터럴:\n\(hits.joined(separator: "\n"))")
    }

    @Test("프리미티브 이니셜라이저가 cornerRadius·shadow 를 아예 받지 않는다")
    func initializersExposeNoRoundingKnobs() throws {
        // 위의 grep 은 구현을 보고, 이건 표면을 본다. 파라미터 라벨에 두 단어가
        // 나타나지 않는지 프리미티브 파일의 `init(` 시그니처만 따로 훑는다.
        let primitiveFiles = try Self.swiftFiles.filter {
            $0.deletingLastPathComponent().lastPathComponent == "Primitives"
        }
        #expect(primitiveFiles.count >= 6)

        for file in primitiveFiles {
            let signatures = try Self.codeLines(of: file)
                .map(\.text)
                .filter { $0.contains("init(") || $0.contains("public init") }
            for signature in signatures {
                #expect(!signature.lowercased().contains("radius"), "\(file.lastPathComponent): \(signature)")
                #expect(!signature.lowercased().contains("shadow"), "\(file.lastPathComponent): \(signature)")
                #expect(!signature.lowercased().contains("elevation"), "\(file.lastPathComponent): \(signature)")
            }
        }
    }
}
