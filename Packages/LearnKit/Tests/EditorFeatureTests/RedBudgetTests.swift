import Foundation
import Testing

/// `{#red-budget-guard}` — 에디터 콘솔 화면 소스에서 `Palette.fail` 은 정확히 한 곳
/// (종료 코드 옆 8px 사각)이어야 한다. 타입으로는 강제할 수 없는 규칙이라 소스를
/// 직접 읽는다 — `DesignSystemTests.PrimitivesSealingTests`·`DashboardFeatureTests
/// .PsychologyDesignTests` 와 같은 방식이다.
///
/// SQL 결과 화면(`Internal/SQL/`)은 이 예산 밖이다 — `{#sql-row-padding}` 이 누락·초과
/// 행마다 `Palette.fail`·`Palette.failWash` 를 쓰는 것을 명시적으로 허용한다.
@Suite("빨강 예산 · 에디터 콘솔 화면")
struct RedBudgetTests {
    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)      // .../Tests/EditorFeatureTests/RedBudgetTests.swift
            .deletingLastPathComponent()     // .../Tests/EditorFeatureTests
            .deletingLastPathComponent()     // .../Tests
            .deletingLastPathComponent()     // .../LearnKit
            .appendingPathComponent("Sources/Features/EditorFeature")
    }

    /// 콘솔 화면 소스 전부 — SQL 결과 화면(`Internal/SQL/`)만 뺀다.
    static var consoleScreenSwiftFiles: [URL] {
        get throws {
            var found: [URL] = []
            var stack = [sourceRoot]
            while let directory = stack.popLast() {
                for entry in try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: [.isDirectoryKey]
                ) {
                    let isDirectory = (try entry.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
                    if isDirectory {
                        guard entry.lastPathComponent != "SQL" else { continue }
                        stack.append(entry)
                    } else if entry.pathExtension == "swift" {
                        found.append(entry)
                    }
                }
            }
            return found.sorted { $0.path < $1.path }
        }
    }

    /// 주석은 제외한다 — 이 규칙을 설명하려면 금지어를 코드처럼 적을 수밖에 없다.
    static func codeLines(of file: URL) throws -> [(line: Int, text: String)] {
        let source = try String(contentsOf: file, encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: String($0.element)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    @Test("소스 경로 계산이 맞다 — grep 이 빈 디렉터리를 훑고 통과하지 않게")
    func sourceRootIsWhereWeThink() throws {
        let names = Set(try Self.consoleScreenSwiftFiles.map(\.lastPathComponent))
        for required in ["EditorModel.swift", "EditorView.swift", "ConsoleResultPanel.swift", "ConsoleEditorLayout.swift"] {
            #expect(names.contains(required), "\(required) 를 못 찾았다")
        }
        // SQL 화면 파일은 이 목록에 있으면 안 된다 — 제외 로직 자체를 검증한다.
        #expect(!names.contains("SQLDiffTable.swift"))
        #expect(!names.contains("SQLResultLayout.swift"))
    }

    @Test("Palette.fail 을 쓰는 코드 지점이 정확히 1곳 — 종료 코드 배지뿐")
    func exactlyOneRedUsageInConsoleScreen() throws {
        var hits: [String] = []
        for file in try Self.consoleScreenSwiftFiles {
            for (line, text) in try Self.codeLines(of: file) {
                // `Palette.failWash` 는 별개 토큰이고 SQL 전용이라 콘솔 화면엔 등장하면 안 된다.
                if text.contains("Palette.failWash") {
                    hits.append("\(file.lastPathComponent):\(line) — failWash 는 SQL 화면 전용이다")
                }
                if text.contains("Palette.fail"), !text.contains("Palette.failWash") {
                    hits.append("\(file.lastPathComponent):\(line) — \(text.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(hits.count == 1, "빨강 사용 지점이 1곳이 아니다:\n\(hits.joined(separator: "\n"))")
        #expect(hits.first?.contains("ConsoleResultPanel.swift") == true)
    }

    @Test("StatusDot(.fail) 도 콘솔 화면에는 없다 — 우회로가 아니다")
    func noStatusDotFailEitherInConsoleScreen() throws {
        var hits: [String] = []
        for file in try Self.consoleScreenSwiftFiles {
            for (line, text) in try Self.codeLines(of: file) where text.contains(".fail") && text.contains("StatusDot") {
                hits.append("\(file.lastPathComponent):\(line)")
            }
        }
        #expect(hits.isEmpty, "StatusDot(.fail) 로 빨강 예산을 우회한 지점:\n\(hits.joined(separator: "\n"))")
    }

    @Test("에디터 안에 유채색이 없다 — 문법 하이라이팅도 무채색이다")
    func noChromaticColorTokensInEditorCodePanel() throws {
        let files = try Self.consoleScreenSwiftFiles.filter {
            $0.lastPathComponent == "EditorCodePanel.swift" || $0.lastPathComponent == "InlineDiagnosticRowView.swift"
        }
        #expect(files.count == 2)
        let banned = ["Palette.fail", "Palette.pass", "Color(hex:", "Color(red:", "Color(.sRGB", ".red", ".green", ".blue", ".orange", ".yellow"]
        var hits: [String] = []
        for file in files {
            for (line, text) in try Self.codeLines(of: file) {
                for needle in banned where text.contains(needle) {
                    hits.append("\(file.lastPathComponent):\(line) — \(needle)")
                }
            }
        }
        #expect(hits.isEmpty, "코드 패널 안 유채색 흔적:\n\(hits.joined(separator: "\n"))")
    }
}
