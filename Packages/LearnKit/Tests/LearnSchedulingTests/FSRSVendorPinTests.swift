import Foundation
import Testing

@testable import LearnScheduling

/// 벤더링이 **의도한 커밋**에서 왔는지 못박는다. `{#fsrs-vendor}` `{#fsrs-sha-rationale}` `{#fsrs-vendor-trim}`
///
/// 이 스위트가 존재하는 이유: `open-spaced-repetition/swift-fsrs` 의 최신 태그 v5.0.0 에는
/// FSRS-6 이 **아예 없다**. `BasicSchedulerV6.swift` 와 21개짜리 `defaultWv6` 는 main 브랜치에만
/// 있고, 그래서 태그가 아니라 커밋 `4fbaf20184d62f82a9f44f343337c61a2c5483e9` 를 고정했다.
/// 누군가 "최신 릴리스로 올리자" 며 태그로 갈아끼우면 여기서 즉시 빨간불이 난다.
@Suite("벤더 FSRS 핀")
struct FSRSVendorPinTests {

    @Test("FSRS-6 기본 w 는 21개다 — 19개면 FSRS-5 고 v6 스케줄러가 안 돈다")
    func defaultWv6HasTwentyOneEntries() {
        expectOracle(
            FSRSDefaults.defaultWv6.count, 21,
            oracle: "swift-fsrs@4fbaf20 FSRSDefaults.defaultWv6.count"
        )
        expectOracle(
            FSRSDefaults.defaultWv6[20], 0.1542,
            tolerance: 1e-12,
            oracle: "ts-fsrs FSRS6_DEFAULT_DECAY"
        )
    }

    @Test("21개 w 는 v6 로, 19개 w 는 v5 로 판정된다")
    func versionDetection() {
        expectOracle(
            FSRSAlgorithmVersion.detect(FSRSDefaults.defaultWv6), .v6,
            oracle: "swift-fsrs FSRSAlgorithmVersion.detect(21)"
        )
        expectOracle(
            FSRSAlgorithmVersion.detect(Array(repeating: 0.5, count: 19)), .v5,
            oracle: "swift-fsrs FSRSAlgorithmVersion.detect(19)"
        )
    }

    @Test("BasicSchedulerV6.swift 가 벤더 트리에 실재하고, v4/v5·reschedule 은 제외됐다")
    func vendorTreeIsV6Only() throws {
        let v6 = vendorRoot.appendingPathComponent("Scheduler/BasicSchedulerV6.swift")
        #expect(
            FileManager.default.fileExists(atPath: v6.path),
            "BasicSchedulerV6.swift 가 없다 — v5.0.0 태그를 벤더링했을 가능성이 높다: \(v6.path)"
        )

        for excluded in ["Scheduler/BasicScheduler.swift", "Scheduler/FSRSReschedule.swift"] {
            let url = vendorRoot.appendingPathComponent(excluded)
            #expect(
                !FileManager.default.fileExists(atPath: url.path),
                "\(excluded) 는 V6 전용 벤더링에서 제외돼야 한다"
            )
        }
    }

    @Test("VENDORING.md 가 upstream SHA·MIT 사본·fsrs-rs 라이선스 차이를 담고 있다")
    func vendoringNoteRecordsProvenance() throws {
        let note = vendorRoot.appendingPathComponent("VENDORING.md")
        let text = String(decoding: try Data(contentsOf: note), as: UTF8.self)

        for needle in [
            "4fbaf20184d62f82a9f44f343337c61a2c5483e9",
            "open-spaced-repetition/swift-fsrs",
            "MIT License",
            "BSD-3-Clause",
            "fsrs-rs",
        ] {
            #expect(text.contains(needle), "VENDORING.md 에 '\(needle)' 가 없다")
        }
    }

    @Test("LearnCore 코드 어디에도 FSRS 가 없다 — 벤더 은닉의 핵심 단언 `{#scheduler-protocol}`")
    func learnCoreMentionsNoFSRS() throws {
        // 산문에서 "FSRS-6 을 쓴다" 같은 설명은 허용한다. 걸러내려는 것은 **심볼 참조**다 —
        // `FSRSParameters`, `FSRS(`, `FSRS.`, `import ...FSRS`, `LearnScheduling.` 처럼
        // 식별자로 쓰인 경우. 한국어 산문의 "FSRS 퍼즈" / "FSRS-6" 는 여기 걸리지 않는다.
        let offenders = try scanSwiftFiles(under: packageRoot.appendingPathComponent("Sources/LearnCore")) { line in
            line.contains(/FSRS[A-Za-z_(.]/)
                || line.contains(/\bimport\s+\w*(FSRS|LearnScheduling)/)
                || line.contains(/\bLearnScheduling\./)
        }
        #expect(
            offenders.isEmpty,
            """
            LearnCore 코드에 FSRS/LearnScheduling 이 등장했다 — ReviewScheduler 프로토콜 뒤에
            숨기는 설계가 깨진 것이다:
            \(offenders.joined(separator: "\n"))
            """
        )
    }

    @Test("벤더 트리에 public 선언이 하나도 없다 — 모듈 밖으로 FSRS 타입이 새지 않는다")
    func vendorTreeExposesNothing() throws {
        let offenders = try scanSwiftFiles(under: vendorRoot) { line in
            line.hasPrefix("public ") || line.contains(" public ")
        }
        #expect(
            offenders.isEmpty,
            """
            벤더 FSRS 에 public 선언이 남아 있다. LearnScheduling 은 라이브러리 프로덕트라서
            벤더의 public 은 곧 앱 전체의 공개 API 가 된다:
            \(offenders.joined(separator: "\n"))
            """
        )
    }

    @Test("v5 + 단기 스케줄링은 조용히 넘어가지 않고 실패한다")
    func v5ShortTermIsRejected() {
        // 업스트림에서 이 조합은 `BasicScheduler`(v4/v5) 로 갔다. 그 파일을 벤더링하지
        // 않았으므로, 잘못된 파라미터가 들어오면 **다른 알고리즘으로 조용히 스케줄되는 대신**
        // 오류가 나야 한다.
        let v5 = FSRS(parameters: FSRSParameters(w: FSRSDefaults().defaultW, enableShortTerm: true))
        #expect(throws: FSRSError.self) {
            _ = try v5.next(card: FSRSDefaults().createEmptyCard(), now: Date(), grade: .good)
        }
    }
}

// MARK: - 소스 스캔 헬퍼

private let packageRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // LearnSchedulingTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // LearnKit

private let vendorRoot: URL = packageRoot
    .appendingPathComponent("Sources/LearnScheduling/Vendor/FSRS", isDirectory: true)

/// `directory` 아래 모든 `.swift` 파일에서 `matches` 를 만족하는 줄을 모은다.
private func scanSwiftFiles(under directory: URL, matches: (String) -> Bool) throws -> [String] {
    guard let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
        return ["\(directory.path) 를 열 수 없다"]
    }
    var offenders: [String] = []
    for case let url as URL in walker where url.pathExtension == "swift" {
        let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(line)
            guard matches(line) else { continue }
            offenders.append("\(url.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
        }
    }
    return offenders.sorted()
}
