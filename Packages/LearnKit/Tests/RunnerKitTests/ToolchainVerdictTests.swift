import Testing
import Foundation
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("툴체인 판정 규칙")
struct ToolchainVerdictTests {
    static func candidate(
        _ path: String,
        _ verdict: ToolCandidateResult.Verdict,
        origin: ToolCandidateOrigin = .conventional
    ) -> ToolCandidateResult {
        ToolCandidateResult(path: path, resolvedPath: path, verdict: verdict, origin: origin)
    }

    // MARK: - 버전 추출

    @Test("도구별 실제 --version 출력에서 버전을 뽑는다")
    func extractsVersionsFromRealOutput() {
        let cases: [(ToolSpec, String, String)] = [
            (ToolchainCatalog.python, "Python 3.13.12", "3.13.12"),
            (ToolchainCatalog.python, "Python 3.9.6", "3.9.6"),
            (ToolchainCatalog.sqlite, "3.51.1 2025-11-28 17:28:25 281fc0e9 (64-bit)", "3.51.1"),
            (ToolchainCatalog.swift, "swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3)", "6.3.3"),
            (ToolchainCatalog.rust, "rustc 1.98.0 (88d9e12ae 2026-08-18)", "1.98.0"),
            (ToolchainCatalog.cpp, "Apple clang version 21.0.0 (clang-2100.1.1.101)", "21.0.0"),
            (ToolchainCatalog.go, "go version go1.22.5 darwin/arm64", "1.22.5"),
            (ToolchainCatalog.java, "javac 21.0.1", "21.0.1"),
            (ToolchainCatalog.typescript, "Version 5.4.5", "5.4.5"),
            (ToolchainCatalog.node, "v26.7.0", "26.7.0"),
            (ToolchainCatalog.assembler, "Apple clang version 21.0.0 (clang-2100.1.1.101)", "21.0.0"),
            (ToolchainCatalog.assembler, "NASM version 2.16.01 compiled on Jan 1 2024", "2.16.01"),
        ]
        for (spec, output, expected) in cases {
            let version = ToolchainVerdict.extractVersion(pattern: spec.versionPattern, from: output)
            #expect(version?.raw == expected, "\(spec.id): \(output)")
        }
    }

    @Test("버전 비교는 자리수가 달라도 성립한다")
    func versionOrdering() {
        #expect(ToolVersion("3.9.6")! < ToolVersion("3.13.12")!)
        #expect(ToolVersion("3.51.0")! < ToolVersion("3.51.1")!)
        #expect(ToolVersion("1.98")! < ToolVersion("1.98.1")!)
        #expect(ToolVersion("21")! == ToolVersion("21.0.0")!)
        #expect(ToolVersion("abc") == nil)
    }

    // MARK: - 판정

    @Test("종료코드 0 + 버전 매치 + 스텁 문구 없음만 ready")
    func readyRequiresAllThree() {
        let verdict = ToolchainVerdict.classify(
            spec: ToolchainCatalog.python,
            result: BoundedCommandResult(exitCode: 0, standardOutput: "Python 3.13.12\n")
        )
        #expect(verdict == .ready(version: ToolVersion("3.13.12")!))
    }

    @Test("/usr/bin/java 는 종료코드 1 에 런타임 없음 문구 — command -v 가 오탐하는 바로 그 케이스")
    func javaStubIsNotReady() {
        let verdict = ToolchainVerdict.classify(
            spec: ToolchainCatalog.java,
            result: BoundedCommandResult(
                exitCode: 1,
                standardError: "The operation couldn’t be completed. Unable to locate a Java Runtime.\nPlease visit http://www.java.com\n"
            )
        )
        guard case let .stub(reason) = verdict else {
            Issue.record("java 스텁은 .stub 이어야 한다: \(verdict)")
            return
        }
        #expect(reason.contains("Unable to locate a Java Runtime"))
    }

    @Test("스텁 문구는 종료코드 0 이어도 이긴다")
    func stubMarkerBeatsExitCode() {
        let verdict = ToolchainVerdict.classify(
            spec: ToolchainCatalog.swift,
            result: BoundedCommandResult(
                exitCode: 0,
                standardOutput: "Swift version 6.0",
                standardError: "xcrun: error: invalid active developer path"
            )
        )
        guard case .stub = verdict else {
            Issue.record("스텁 문구가 있으면 .stub: \(verdict)")
            return
        }
    }

    @Test("동작하지만 최소 버전 미달이면 belowMinimum")
    func belowMinimum() {
        let verdict = ToolchainVerdict.classify(
            spec: ToolchainCatalog.node,
            result: BoundedCommandResult(exitCode: 0, standardOutput: "v16.20.0\n")
        )
        #expect(verdict == .belowMinimum(version: ToolVersion("16.20.0")!))
    }

    @Test("종료코드 0 인데 버전을 못 읽으면 failed")
    func unparseableVersion() {
        let verdict = ToolchainVerdict.classify(
            spec: ToolchainCatalog.python,
            result: BoundedCommandResult(exitCode: 0, standardOutput: "hello\n")
        )
        guard case .failed = verdict else {
            Issue.record("버전 미해독은 .failed: \(verdict)")
            return
        }
    }

    @Test("타임아웃과 실행 실패는 failed")
    func timeoutAndLaunchFailure() {
        let timedOut = ToolchainVerdict.classify(
            spec: ToolchainCatalog.python,
            result: BoundedCommandResult(exitCode: -1, timedOut: true)
        )
        guard case .failed = timedOut else {
            Issue.record("타임아웃은 .failed")
            return
        }
        let notLaunched = ToolchainVerdict.classify(
            spec: ToolchainCatalog.python,
            result: BoundedCommandResult(launchFailure: "No such file")
        )
        guard case .failed = notLaunched else {
            Issue.record("실행 실패는 .failed")
            return
        }
    }

    // MARK: - 선택 정책

    @Test("PATH 순서가 아니라 최고 버전을 고른다 — 3.9.6 이 아니라 3.13")
    func picksHighestVersionNotFirstOnPath() {
        let availability = ToolchainVerdict.select(
            spec: ToolchainCatalog.python,
            candidates: [
                Self.candidate("/usr/bin/python3", .ready(version: ToolVersion("3.9.6")!), origin: .searchPath(index: 0)),
                Self.candidate("/opt/conda/bin/python3", .ready(version: ToolVersion("3.13.12")!), origin: .searchPath(index: 5)),
                Self.candidate("/opt/homebrew/bin/python3", .ready(version: ToolVersion("3.12.4")!), origin: .searchPath(index: 3)),
            ]
        )
        guard case let .ready(version, path) = availability else {
            Issue.record("ready 여야 한다: \(availability)")
            return
        }
        #expect(version == "3.13.12")
        #expect(path == "/opt/conda/bin/python3")
    }

    @Test("동률이면 먼저 발견된 것")
    func tieGoesToFirstFound() {
        let availability = ToolchainVerdict.select(
            spec: ToolchainCatalog.python,
            candidates: [
                Self.candidate("/first/python3", .ready(version: ToolVersion("3.13.0")!)),
                Self.candidate("/second/python3", .ready(version: ToolVersion("3.13.0")!)),
            ]
        )
        guard case let .ready(_, path) = availability else {
            Issue.record("ready 여야 한다")
            return
        }
        #expect(path == "/first/python3")
    }

    @Test("전부 최소 버전 미달이면 unsupported — 설치가 아니라 업그레이드 안내")
    func allBelowMinimumIsUnsupported() {
        let availability = ToolchainVerdict.select(
            spec: ToolchainCatalog.node,
            candidates: [
                Self.candidate("/a/node", .belowMinimum(version: ToolVersion("14.0.0")!)),
                Self.candidate("/b/node", .belowMinimum(version: ToolVersion("16.20.0")!)),
            ]
        )
        guard case let .unsupported(reason) = availability else {
            Issue.record("unsupported 여야 한다: \(availability)")
            return
        }
        #expect(reason.contains("16.20.0"))
    }

    @Test("스텁만 있으면 stub, 후보가 아예 없으면 missing")
    func stubAndMissing() {
        let stub = ToolchainVerdict.select(
            spec: ToolchainCatalog.java,
            candidates: [Self.candidate("/usr/bin/javac", .stub(reason: "Unable to locate a Java Runtime"))]
        )
        guard case let .stub(path, _) = stub else {
            Issue.record("stub 이어야 한다: \(stub)")
            return
        }
        #expect(path == "/usr/bin/javac")

        let missing = ToolchainVerdict.select(spec: ToolchainCatalog.go, candidates: [])
        guard case let .missing(hint) = missing else {
            Issue.record("missing 이어야 한다: \(missing)")
            return
        }
        #expect(hint == ToolchainCatalog.go.installHint)
    }

    @Test("개발자 디렉터리가 없어 건너뛴 후보는 stub 으로 보고된다")
    func skippedBecomesStub() {
        let availability = ToolchainVerdict.select(
            spec: ToolchainCatalog.swift,
            candidates: [Self.candidate("/usr/bin/swiftc", .skippedWithoutDeveloperDirectory)]
        )
        guard case let .stub(path, reason) = availability else {
            Issue.record("stub 이어야 한다: \(availability)")
            return
        }
        #expect(path == "/usr/bin/swiftc")
        #expect(reason.contains("xcode-select"))
    }

    @Test("ready 가 하나라도 있으면 스텁·미달을 덮는다")
    func readyWinsOverEverything() {
        let availability = ToolchainVerdict.select(
            spec: ToolchainCatalog.java,
            candidates: [
                Self.candidate("/usr/bin/javac", .stub(reason: "Unable to locate a Java Runtime")),
                Self.candidate("/opt/jdk/bin/javac", .ready(version: ToolVersion("21.0.1")!)),
                Self.candidate("/old/jdk/bin/javac", .belowMinimum(version: ToolVersion("11.0.2")!)),
            ]
        )
        #expect(availability.isReady)
    }

    // MARK: - 카탈로그

    @Test("카탈로그가 10 개 트랙을 모두 덮는다")
    func catalogCoversTenTracks() {
        let languages = Set(ToolchainCatalog.all.map(\.language.rawValue))
        #expect(languages == [
            "python", "sql", "swift", "rust", "cpp", "go", "java", "typescript", "nextjs", "assembly",
        ])
        #expect(ToolchainCatalog.all.count == 10)
        #expect(Set(ToolchainCatalog.all.map(\.id)).count == 10)
    }

    @Test("모든 정규식이 컴파일된다")
    func allPatternsCompile() {
        for spec in ToolchainCatalog.all {
            #expect(
                (try? NSRegularExpression(pattern: spec.versionPattern)) != nil,
                "\(spec.id) 의 정규식이 컴파일되지 않는다"
            )
        }
    }
}
