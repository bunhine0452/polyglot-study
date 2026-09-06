public import Foundation
public import LearnCore

/// `swift test --event-stream-output-path <f> --event-stream-version 0` 이 내는
/// JSON Lines 를 `GradeResult.TestOutcome` 으로 옮긴다.
///
/// 스트림은 두 종류의 줄로 이뤄진다 (실측 Swift 6.3.3 / Testing 1902).
///   - `{"kind":"test","payload":{"id":…,"kind":"function","name":…,"displayName":…}}`
///     테스트 **메타데이터**. 실행 순서와 무관하게 앞쪽에 몰려 나온다.
///   - `{"kind":"event","payload":{"kind":"testStarted"|"issueRecorded"|"testEnded"|…}}`
///     실제 사건. `testID` 로 위 메타데이터와 이어진다.
///
/// 병렬 실행이라 `testStarted` 들이 섞여 나온다 — 시간은 `instant.absolute`
/// (단조 시계 초) 차이로 재야 하고, 줄 순서로 재면 음수가 나온다.
public enum SwiftTestingEventStream {
    public static func parse(at url: URL) -> [GradeResult.TestOutcome] {
        guard let data = FileManager.default.contents(atPath: url.path) else { return [] }
        return parse(jsonLines: data)
    }

    public static func parse(jsonLines data: Data) -> [GradeResult.TestOutcome] {
        let decoder = JSONDecoder()
        var names: [String: String] = [:]
        var order: [String] = []
        var startedAt: [String: Double] = [:]
        var issues: [String: [String]] = [:]
        var ended: [String: (passed: Bool, at: Double)] = [:]

        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let record = try? decoder.decode(Record.self, from: Data(line)) else { continue }
            let payload = record.payload
            switch record.kind {
            case "test":
                // 스위트(`kind == "suite"`)는 결과 목록에 넣지 않는다 — 학습자가 보는
                // 것은 개별 테스트고, 스위트를 섞으면 통과 개수가 부풀어 보인다.
                guard payload.kind == "function", let id = payload.id else { continue }
                names[id] = payload.displayName ?? payload.name ?? id
            case "event":
                guard let id = payload.testID else { continue }
                switch payload.kind {
                case "testStarted":
                    startedAt[id] = payload.instant?.absolute
                    if !order.contains(id) { order.append(id) }
                case "issueRecorded":
                    let texts = (payload.messages ?? [])
                        .filter { $0.symbol != "details" || !($0.text ?? "").isEmpty }
                        .compactMap(\.text)
                    issues[id, default: []].append(contentsOf: texts)
                case "testEnded":
                    let failed = (issues[id] ?? []).isEmpty == false
                    ended[id] = (passed: !failed, at: payload.instant?.absolute ?? 0)
                    if !order.contains(id) { order.append(id) }
                default:
                    break
                }
            default:
                break
            }
        }

        return order.compactMap { id in
            guard let outcome = ended[id] else { return nil }
            let duration: Int
            if let began = startedAt[id], outcome.at > began {
                // 반올림한다 — 10.6 - 10.5 는 0.0999… 라 잘라 버리면 99ms 가 된다.
                duration = Int(((outcome.at - began) * 1000).rounded())
            } else {
                duration = 0
            }
            let message = (issues[id] ?? []).joined(separator: "\n")
            return GradeResult.TestOutcome(
                name: names[id] ?? id,
                passed: outcome.passed,
                message: message.isEmpty ? nil : message,
                durationMilliseconds: duration
            )
        }
    }

    /// `--event-stream-output-path` 가 사라졌을 때의 폴백.
    ///
    /// xUnit XML 은 케이스마다 `<testcase name=… time=…>` 하나에 실패면
    /// `<failure message=…>` 자식이 붙는다. 이벤트 스트림보다 정보가 적다 —
    /// `displayName` 이 없고 스킵과 통과가 섞인다.
    public static func parseXUnit(at url: URL) -> [GradeResult.TestOutcome] {
        guard let data = FileManager.default.contents(atPath: url.path) else { return [] }
        let parser = XMLParser(data: data)
        let delegate = XUnitDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        return delegate.outcomes
    }

    // MARK: - 디코딩 모델

    struct Record: Decodable {
        var kind: String
        var payload: Payload
    }

    struct Payload: Decodable {
        var kind: String?
        var id: String?
        var name: String?
        var displayName: String?
        var testID: String?
        var messages: [Message]?
        var instant: Instant?
    }

    struct Message: Decodable {
        var symbol: String?
        var text: String?
    }

    struct Instant: Decodable {
        var absolute: Double?
    }
}

private final class XUnitDelegate: NSObject, XMLParserDelegate {
    var outcomes: [GradeResult.TestOutcome] = []
    private var pending: GradeResult.TestOutcome?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        switch elementName {
        case "testcase":
            flush()
            let name = [attributes["classname"], attributes["name"]]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ".")
            let seconds = Double(attributes["time"] ?? "0") ?? 0
            pending = GradeResult.TestOutcome(
                name: name.isEmpty ? "테스트" : name,
                passed: true,
                message: nil,
                durationMilliseconds: Int(seconds * 1000)
            )
        case "failure", "error":
            pending?.passed = false
            pending?.message = attributes["message"] ?? elementName
        case "skipped":
            pending?.message = attributes["message"] ?? "건너뜀"
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        if elementName == "testcase" { flush() }
    }

    func parserDidEndDocument(_ parser: XMLParser) { flush() }

    private func flush() {
        if let pending { outcomes.append(pending) }
        pending = nil
    }
}
