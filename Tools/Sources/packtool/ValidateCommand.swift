internal import ArgumentParser
internal import Foundation
internal import PackReport
internal import PackValidate

/// 리포트 형식.
enum ReportFormat: String, CaseIterable, ExpressibleByArgument {
    /// 사람이 터미널에서 읽는 형태.
    case text
    /// `PackValidationReport.canonicalJSON()` 그대로. `lessongen repair` 가 읽는다.
    case json
    /// CI 어노테이션용.
    case junit
}

struct ValidateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "팩을 네 단계로 검증한다 — 구조·문법·의미·실행",
        discussion: """
            단계는 뒤로 갈수록 비싸고, 앞 단계가 실패한 레슨은 뒤 단계를 돌지 않는다.

              structural  매니페스트 디코딩·sha256 양방향 대조·잠금 위반·참조 파일 존재
              syntax      디렉티브 파싱과 6블록 순서
              semantic    퀴즈 정답 키·빈칸 정답 (line:column 으로 보고)
              execution   예제·빈칸·과제를 실제 CodeRunner 에 태운다

            앞 세 단계는 툴체인이 하나도 없는 머신에서도 돈다.

            실행 게이트가 보는 것:
              · 예제  — 실행해 expected/ 사이드카와 바이트 단위로 대조한다.
                        정규화는 셋뿐이다 — 선행 BOM 제거, CRLF·CR → LF,
                        후행 개행을 정확히 하나로. 그 밖에는 아무것도 접지 않는다
                        (줄 끝 공백도 다르면 다르다).
              · 빈칸  — 정답을 채운 코드가 실제로 돌아가는지.
              · 과제  — solution 이 숨은 테스트를 통과하고 **starter 는 실패하는지 둘 다.**
                        starter 가 이미 통과하면 그 과제는 빈 껍데기다.

            툴체인이 없으면 스킵이 아니라 실패가 기본이다. --allow-missing-toolchain 을
            명시할 때만 건너뛰고, 그 경우 리포트의 stagesRun 에서 execution 이 빠진다.

            종료 코드: 0 통과 · 1 검증 실패 · 2 사용법·입출력 오류.
            """
    )

    @Argument(help: "팩 디렉터리 경로")
    var packPath: String

    @Option(name: .long, help: "리포트 형식 (text | json | junit)")
    var report: ReportFormat = .text

    @Option(name: [.customShort("o"), .long], help: "리포트를 쓸 파일. 생략하면 stdout")
    var output: String?

    @Flag(name: .long, help: "툴체인이 없으면 실행 게이트를 건너뛴다 (기본은 실패)")
    var allowMissingToolchain = false

    @Option(name: [.customShort("j"), .long], help: "동시에 태울 블록 수")
    var jobs: Int?

    func run() async throws {
        let directory = URL(fileURLWithPath: packPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw Self.toolFailure("팩 디렉터리가 아니다: \(packPath)")
        }

        var options = ValidationOptions(allowMissingToolchain: allowMissingToolchain)
        if let jobs { options.maxConcurrency = jobs }

        let outcome = await PackValidator(packDirectory: directory, options: options).validate()

        let rendered: String
        switch report {
        case .text:
            rendered = TextReport.render(outcome)
        case .json:
            do {
                rendered = String(decoding: try outcome.report.canonicalJSON(), as: UTF8.self) + "\n"
            } catch {
                throw Self.toolFailure("리포트를 JSON 으로 쓸 수 없다: \(error)")
            }
        case .junit:
            rendered = JUnitReport.render(outcome.report)
        }

        if let output {
            do {
                try Data(rendered.utf8).write(to: URL(fileURLWithPath: output), options: .atomic)
            } catch {
                throw Self.toolFailure("리포트를 쓸 수 없다 (\(output)): \(error)")
            }
        } else {
            FileHandle.standardOutput.write(Data(rendered.utf8))
        }

        // 기계용 리포트를 stdout 으로 흘려보낼 때도 터미널은 결과를 알아야 한다.
        if report != .text || output != nil {
            FileHandle.standardError.write(Data(Self.summary(outcome).utf8))
        }

        if !outcome.isClean { throw ExitCode(1) }
    }

    static func summary(_ outcome: ValidationOutcome) -> String {
        let report = outcome.report
        var line = "packtool validate \(report.packID)@\(report.packVersion): "
        line += report.isClean ? "통과" : "실패 \(report.failedLessons.reduce(0) { $0 + $1.failures.count })건"
        line += " (단계 \(TextReport.stageLine(report)))\n"
        for note in outcome.skipNotes {
            line += "  건너뜀 — \(note)\n"
        }
        return line
    }

    /// 검증 **결과**가 아니라 도구 자체가 실패한 경우. 종료 코드 2 로 갈린다 —
    /// CI 가 "팩이 나쁘다"(1)와 "도구를 잘못 불렀다"(2)를 구별할 수 있어야 한다.
    static func toolFailure(_ message: String) -> any Error {
        FileHandle.standardError.write(Data(("packtool: " + message + "\n").utf8))
        return ExitCode(2)
    }
}
