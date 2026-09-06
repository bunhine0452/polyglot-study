internal import Foundation
public import PackReport

/// 사람이 터미널에서 읽는 형태.
///
/// 기계가 읽는 것은 JSON 과 JUnit 이고 이쪽은 개발자용이다. 그래서 증거를 접지 않는다 —
/// diff 와 러너 원문이 그대로 보여야 손으로 고칠 수 있다.
public enum TextReport {
    public static func render(_ outcome: ValidationOutcome) -> String {
        let report = outcome.report
        var out = "packtool validate — \(report.packID)@\(report.packVersion)\n"
        out += "단계: \(stageLine(report))\n"

        if !outcome.skipNotes.isEmpty {
            out += "\n건너뛴 실행 게이트:\n"
            for note in outcome.skipNotes { out += "  · \(note)\n" }
            out += "  → stagesRun 에 execution 이 없다. 이 결과를 '통과' 로 읽으면 안 된다.\n"
        }

        let failed = report.failedLessons
        if failed.isEmpty {
            out += "\n레슨 \(report.lessons.count)개, 실패 0건.\n"
            if !report.executionStageRan {
                out += "다만 실행 게이트가 돌지 않았다 — 예제와 과제는 검증되지 않았다.\n"
            }
            return out
        }

        let count = failed.reduce(0) { $0 + $1.failures.count }
        out += "\n실패 \(count)건 / 레슨 \(failed.count)개\n"
        for lesson in failed {
            out += "\n── \(lesson.stableID) (\(lesson.language)) \(lesson.title)\n"
            for failure in lesson.failures {
                out += "  [\(failure.stage.rawValue)/\(failure.kind.rawValue)] "
                out += JUnitReport.headline(failure) + "\n"
                if let evidence = failure.evidence, !evidence.isEmpty {
                    for line in evidence.split(separator: "\n", omittingEmptySubsequences: false) {
                        out += "      \(line)\n"
                    }
                }
            }
        }
        return out
    }

    public static func stageLine(_ report: PackValidationReport) -> String {
        let ran = Set(report.stagesRun)
        return PackValidationReport.Stage.allCases
            .map { "\($0.rawValue)\(ran.contains($0) ? "" : "(미실행)")" }
            .joined(separator: " → ")
    }
}
