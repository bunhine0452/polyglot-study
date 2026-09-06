internal import ContentKit
internal import LearnCore
public import Foundation
public import PackReport

/// 검증 한 번의 산출물.
public struct ValidationOutcome: Sendable {
    public var report: PackValidationReport
    /// 실행 게이트에서 건너뛴 것들 (`--allow-missing-toolchain`).
    ///
    /// 리포트 자체에는 `stagesRun` 에서 `.execution` 이 빠지는 것으로만 남는다 —
    /// 계약에 스킵 사유를 담을 자리가 없다. 사람이 읽는 출력에는 반드시 찍는다.
    public var skipNotes: [String]

    public init(report: PackValidationReport, skipNotes: [String] = []) {
        self.report = report
        self.skipNotes = skipNotes
    }

    /// 종료 코드. **실행 게이트가 돌지 않은 clean 은 clean 이 아니다** —
    /// 다만 그 판단은 호출자(CI 정책)의 몫이라 여기서는 실패 유무만 본다.
    public var isClean: Bool { report.isClean }
}

/// 콘텐츠 팩 하나를 네 단계로 검증한다.
///
/// 단계는 뒤로 갈수록 비싸고, **앞 단계가 실패한 레슨은 뒤 단계를 돌지 않는다** —
/// 파싱되지 않는 레슨을 실행기에 태우는 것은 시간 낭비이고, 그 실패는 파싱 실패의
/// 메아리라 리포트만 시끄러워진다.
///
/// 던지지 않는다. 매니페스트가 아예 없는 팩에도 리포트가 나와야 `lessongen repair` 가
/// 무엇이 잘못됐는지 읽을 수 있다.
public struct PackValidator: Sendable {
    /// 어느 레슨의 것도 아닌 실패가 붙는 합성 레슨 id.
    public static let packLevelStableID = FailureTable.packLevelStableID

    public let packDirectory: URL
    public var options: ValidationOptions

    public init(packDirectory: URL, options: ValidationOptions = ValidationOptions()) {
        self.packDirectory = packDirectory
        self.options = options
    }

    public func validate() async -> ValidationOutcome {
        var table = FailureTable()
        var stages: [PackValidationReport.Stage] = [.structural]

        // ── 구조: 매니페스트부터. 여기서 막히면 나머지는 볼 것이 없다.
        let pack: ContentPack
        do {
            pack = try ContentPack(directory: packDirectory)
        } catch {
            // 요약은 **한 줄**이어야 하는데 디코딩 실패의 원문은 여러 줄이다. 첫 줄만
            // 요약으로 올리고 전문은 증거로 내린다 — 네 가지 매니페스트 결함
            // (없음·디코딩 불가·중복 id·경로 탈출)이 서로 다른 한 줄로 갈려야 한다.
            let detail = "\(error)"
            let headline = detail.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? detail
            table.addPackLevel(
                .init(
                    stage: .structural, kind: .brokenReference,
                    summary: headline, evidence: detail))
            return ValidationOutcome(
                report: PackValidationReport(
                    packID: packDirectory.lastPathComponent,
                    packVersion: "0.0.0",
                    validatedAt: timestamp(),
                    stagesRun: stages,
                    lessons: table.lessonResults()))
        }

        for entry in pack.manifest.lessons {
            table.declare(
                stableID: entry.stableID.rawValue,
                language: entry.language.rawValue,
                title: entry.title)
        }
        StructuralStage.run(pack: pack, into: &table)

        // ── 문법: 디렉티브 파싱과 6블록 순서.
        stages.append(.syntax)
        let parsed = SyntaxStage.run(pack: pack, into: &table)

        // ── 의미: 퀴즈 정답 키와 빈칸 정답.
        stages.append(.semantic)
        SemanticStage.run(parsed, into: &table)

        // ── 실행: 앞 세 단계가 깨끗한 레슨만 태운다.
        var skipNotes: [String] = []
        if options.runExecution && pack.manifest.isDistribution {
            // 배포 팩에는 solutions 가 없다. 과제 게이트의 절반(solution 통과)을 물리적으로
            // 태울 수 없으므로 **돌지 않았다고 기록한다** — 반쪽만 돌린 실행 게이트를
            // stagesRun 에 `.execution` 으로 올리면 그게 거짓말이다. 실행 게이트는
            // 굽기 **전** 소스 팩에서 돈다.
            skipNotes.append(
                "배포 팩이라 실행 게이트를 돌리지 않았다 — solutions 가 벗겨져 과제를 태울 수 없다")
        } else if options.runExecution {
            let clean = parsed.filter { table.isClean($0.entry.stableID.rawValue) }
            let stage = ExecutionStage(pack: pack, options: options)
            let result = await stage.run(clean)
            for failure in result.packLevelFailures { table.addPackLevel(failure) }
            for (lesson, failure) in result.failures { table.add(failure, to: lesson) }
            skipNotes += result.skipNotes
            // 앞 단계에서 걸러진 레슨이 있으면 실행 게이트는 팩 전체를 태우지 못한 것이다.
            let coveredEverything = clean.count == parsed.count && !parsed.isEmpty
            if result.ranEverything && coveredEverything {
                stages.append(.execution)
            }
        }

        return ValidationOutcome(
            report: PackValidationReport(
                packID: pack.manifest.packID.rawValue,
                packVersion: pack.manifest.version,
                validatedAt: timestamp(),
                stagesRun: stages,
                lessons: table.lessonResults()),
            skipNotes: skipNotes)
    }

    private func timestamp() -> Int64 {
        options.validatedAt ?? Int64(Date().timeIntervalSince1970 * 1000)
    }
}
