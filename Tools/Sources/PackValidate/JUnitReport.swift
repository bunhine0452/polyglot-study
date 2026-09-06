internal import Foundation
public import PackReport

/// `PackValidationReport` 를 JUnit XML 로. CI 어노테이션이 읽는 형식이다.
///
/// 레슨 하나가 `testsuite`, **단계 하나가 `testcase`** 다. 블록 단위로 쪼개지 않는 이유는
/// CI 화면에서 읽히는 단위가 "이 레슨의 실행 게이트가 깨졌다" 이기 때문이다. 어느
/// 블록인지는 실패 메시지에 들어간다.
///
/// **돌지 않은 단계는 `<skipped/>` 로 남긴다.** 실행 게이트가 통째로 빠진 실행을
/// "전부 통과"로 렌더하면 리포트가 거짓말을 한다.
public enum JUnitReport {
    public static func render(_ report: PackValidationReport) -> String {
        let stages = PackValidationReport.Stage.allCases
        let ran = Set(report.stagesRun)

        var totalTests = 0
        var totalFailures = 0
        var suites = ""

        for lesson in report.lessons {
            var cases = ""
            var suiteFailures = 0
            for stage in stages {
                totalTests += 1
                let failures = lesson.failures.filter { $0.stage == stage }
                let name = escape(stage.rawValue)
                let classname = escape("\(report.packID).\(lesson.stableID)")
                if failures.isEmpty {
                    if ran.contains(stage) {
                        cases += "    <testcase name=\"\(name)\" classname=\"\(classname)\"/>\n"
                    } else {
                        cases += "    <testcase name=\"\(name)\" classname=\"\(classname)\">\n"
                        cases += "      <skipped message=\"이 단계는 돌지 않았다\"/>\n"
                        cases += "    </testcase>\n"
                    }
                    continue
                }
                suiteFailures += failures.count
                totalFailures += failures.count
                cases += "    <testcase name=\"\(name)\" classname=\"\(classname)\">\n"
                for failure in failures {
                    cases += "      <failure type=\"\(escape(failure.kind.rawValue))\""
                    cases += " message=\"\(escape(headline(failure)))\">"
                    cases += escape(failure.evidence ?? failure.summary)
                    cases += "</failure>\n"
                }
                cases += "    </testcase>\n"
            }
            suites += "  <testsuite name=\"\(escape(lesson.stableID))\""
            suites += " package=\"\(escape(report.packID))\""
            suites += " tests=\"\(stages.count)\" failures=\"\(suiteFailures)\""
            suites += " errors=\"0\" skipped=\"\(stages.count - ran.count)\">\n"
            suites += cases
            suites += "  </testsuite>\n"
        }

        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<testsuites name=\"packtool validate \(escape(report.packID))@"
        out += "\(escape(report.packVersion))\""
        out += " tests=\"\(totalTests)\" failures=\"\(totalFailures)\" errors=\"0\">\n"
        out += suites
        out += "</testsuites>\n"
        return out
    }

    static func headline(_ failure: PackValidationReport.Failure) -> String {
        var text = failure.summary
        if let block = failure.blockID { text = "[\(block)] " + text }
        if let line = failure.line {
            let column = failure.column.map { ":\($0)" } ?? ""
            text += " (\(line)\(column))"
        }
        return text
    }

    /// XML 1.0 이 받을 수 없는 문자는 버린다. 러너 원문에는 제어 문자가 섞일 수 있고,
    /// 그 한 바이트 때문에 CI 가 리포트 전체를 파싱하지 못하는 것이 최악이다.
    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            case "\t", "\n", "\r": out.unicodeScalars.append(scalar)
            default:
                if scalar.value < 0x20 || (0xD800...0xDFFF).contains(scalar.value) { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
