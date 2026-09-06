public import Foundation
public import PackReport

/// 레슨별 수리 시도 횟수. **실행을 넘어 이어진다.**
///
/// 수리 루프는 한 프로세스 안에서 닫히지 않는다. `lessongen repair` 가 고치고,
/// `packtool validate` 가 다시 돌고, 그 리포트를 들고 `lessongen repair` 가 또 도는
/// 모양이다. 그래서 "3회 실패" 를 세려면 실행 밖에 장부가 있어야 한다.
///
/// 팩 디렉터리에 두지 않는 이유: 팩은 매니페스트에 등록되지 않은 파일을 허용하지 않는다.
/// 장부는 실행 로그 뿌리에 산다.
public struct AttemptLedger: Codable, Hashable, Sendable {
    public static let fileName = "repair-attempts.json"

    public var packID: String
    /// stableID → 지금까지 수리한 횟수.
    public var attempts: [String: Int]

    public init(packID: String, attempts: [String: Int] = [:]) {
        self.packID = packID
        self.attempts = attempts
    }

    public func attempts(for stableID: String) -> Int { attempts[stableID] ?? 0 }

    public mutating func recordAttempt(_ stableID: String) {
        attempts[stableID, default: 0] += 1
    }

    /// 통과한 레슨은 장부에서 지운다 — 다음에 다시 실패하면 처음부터 세는 것이 맞다.
    /// 몇 달 전에 한 번 고쳤다는 사실로 오늘의 레슨을 격리하면 안 된다.
    public mutating func clear(_ stableID: String) {
        attempts.removeValue(forKey: stableID)
    }

    public static func load(from url: URL, packID: String) -> AttemptLedger {
        guard let data = try? Data(contentsOf: url),
            let ledger = try? JSONDecoder().decode(AttemptLedger.self, from: data),
            ledger.packID == packID
        else {
            return AttemptLedger(packID: packID)
        }
        return ledger
    }

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

/// 리포트 한 장과 장부를 놓고 "무엇을 다시 만들고 무엇을 버릴지" 를 정한다.
public struct RepairPlan: Sendable {
    /// 이번에 다시 만들 레슨.
    public var targets: [Target]
    /// 시도를 다 쓴 레슨. 팩에서 빼고 non-zero 로 끝낸다.
    public var quarantined: [Quarantine]
    public var maxAttempts: Int

    public struct Target: Sendable, Hashable {
        public var lesson: PackValidationReport.LessonResult
        /// 이번이 몇 번째 수리인가. 1부터.
        public var attempt: Int
    }

    public struct Quarantine: Sendable, Hashable, Codable {
        public var stableID: String
        public var language: String
        public var title: String
        public var attempts: Int
        /// 마지막으로 남은 실패들. 사람이 읽고 손으로 고칠 재료다.
        public var failures: [String]

        public init(
            stableID: String, language: String, title: String, attempts: Int, failures: [String]
        ) {
            self.stableID = stableID
            self.language = language
            self.title = title
            self.attempts = attempts
            self.failures = failures
        }
    }

    public var isEmpty: Bool { targets.isEmpty && quarantined.isEmpty }
}

public enum RepairPlanner {
    /// 기본 시도 상한. 3회 실패하면 격리한다 (`{#lessongen-quarantine}`).
    public static let defaultMaxAttempts = 3

    /// - Parameters:
    ///   - report: `packtool validate` 의 산출물.
    ///   - ledger: 지금까지의 시도 장부.
    ///   - only: 비어 있지 않으면 이 stableID 만 대상으로 삼는다.
    public static func plan(
        report: PackValidationReport,
        ledger: AttemptLedger,
        maxAttempts: Int = RepairPlanner.defaultMaxAttempts,
        only: Set<String> = []
    ) -> RepairPlan {
        var targets: [RepairPlan.Target] = []
        var quarantined: [RepairPlan.Quarantine] = []

        for lesson in report.failedLessons.sorted(by: { $0.stableID < $1.stableID }) {
            if !only.isEmpty && !only.contains(lesson.stableID) { continue }
            let done = ledger.attempts(for: lesson.stableID)
            if done >= maxAttempts {
                quarantined.append(
                    RepairPlan.Quarantine(
                        stableID: lesson.stableID,
                        language: lesson.language,
                        title: lesson.title,
                        attempts: done,
                        failures: lesson.failures.map {
                            "[\($0.stage.rawValue)/\($0.kind.rawValue)] \($0.summary)"
                        }))
            } else {
                targets.append(RepairPlan.Target(lesson: lesson, attempt: done + 1))
            }
        }
        return RepairPlan(targets: targets, quarantined: quarantined, maxAttempts: maxAttempts)
    }

    /// 격리 명단을 사람이 읽는 문단으로. 종료 직전 stderr 로 나간다.
    public static func quarantineReport(_ entries: [RepairPlan.Quarantine], maxAttempts: Int)
        -> String
    {
        guard !entries.isEmpty else { return "" }
        var lines = [
            "격리 \(entries.count)건 — \(maxAttempts)회 수리하고도 검증을 통과하지 못했습니다.",
            "이 레슨들은 팩에서 빠졌습니다. 사람이 직접 고치기 전까지 머지하지 마십시오.",
            "",
        ]
        for entry in entries {
            lines.append("  \(entry.stableID) (\(entry.language)) — \(entry.title)")
            for failure in entry.failures { lines.append("    · \(failure)") }
        }
        return lines.joined(separator: "\n")
    }
}
