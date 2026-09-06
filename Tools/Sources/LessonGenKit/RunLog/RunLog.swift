public import Foundation
public import LLMKit

/// 실행 하나가 남기는 디렉터리.
///
/// ```
/// <runs>/20260906-2211-3f9c/
///   run.json                        머리말과 결산
///   calls.jsonl                     호출별 usage·모델·업스트림 한 줄씩
///   calls/0001-lesson-<id>.json     요청·응답 전문
///   report.json                     (수리 실행일 때) 입력으로 삼은 검증 리포트
/// ```
///
/// 액터인 이유는 팬아웃 때문이다 — 동시에 도는 요청들이 같은 카운터와 같은 파일에
/// 쓴다. 비용 가드도 여기 있다: **새 호출을 시작하기 전에** 지금까지 쓴 금액을 보고,
/// 예산을 넘었으면 시작하지 않는다. 이미 나간 호출의 비용은 되돌릴 수 없으므로 가드는
/// 상한이 아니라 **정지선**이다 — 문서화된 한계다.
public actor RunLog {
    /// 이 실행의 디렉터리. 불변이라 액터 밖에서도 읽힌다 — 로그 한 줄 찍자고 `await`
    /// 하게 만들 이유가 없다.
    public nonisolated let directory: URL
    public private(set) var manifest: RunManifest

    private let fileManager: FileManager
    private var sequence = 0
    private var upstreams: Set<String> = []
    private var models: Set<String> = []

    public init(
        rootDirectory: URL,
        runID: String,
        command: String,
        startedAt: Date,
        models selection: ModelSelection,
        sessionID: String?,
        budgetUSD: Double?,
        fileManager: FileManager = .default
    ) throws {
        self.directory = rootDirectory.appendingPathComponent(runID, isDirectory: true)
        self.fileManager = fileManager
        var stageModels: [String: String] = [:]
        for stage in GenerationStage.allCases {
            stageModels[stage.rawValue] = selection.model(for: stage).rawValue
        }
        self.manifest = RunManifest(
            runID: runID,
            startedAt: RunLog.timestamp(startedAt),
            command: command,
            stageModels: stageModels,
            sessionID: sessionID,
            budgetUSD: budgetUSD)
        try fileManager.createDirectory(
            at: directory.appendingPathComponent("calls", isDirectory: true),
            withIntermediateDirectories: true)
        // 액터 초기화 중에는 격리된 메서드를 부를 수 없다. 머리말은 처음부터 디스크에
        // 있어야 한다 — 실행이 중간에 죽어도 "무엇이 돌았는가" 가 남게.
        try Self.encode(manifest).write(
            to: directory.appendingPathComponent("run.json"), options: .atomic)
    }

    /// 지금까지 쓴 것으로 확인된 금액. 비용을 알려 주지 않은 호출은 빠져 있다.
    public var spentUSD: Double { manifest.spentUSD }

    /// 새 호출을 시작해도 되는가. 예산을 넘었으면 던진다.
    public func ensureBudget() throws {
        guard let budget = manifest.budgetUSD else { return }
        guard manifest.spentUSD < budget else {
            throw RunLogError.budgetExceeded(spentUSD: manifest.spentUSD, budgetUSD: budget)
        }
    }

    /// 성공한 호출 하나를 적는다.
    @discardableResult
    public func record(
        stage: GenerationStage,
        subject: String,
        attempt: Int,
        requestedModel: ModelID,
        request: CompletionRequest,
        response: CompletionResponse,
        startedAt: Date,
        duration: Duration
    ) throws -> CallRecord {
        sequence += 1
        let record = CallRecord(
            sequence: sequence,
            stage: stage.rawValue,
            subject: subject,
            attempt: attempt,
            requestedModel: requestedModel.rawValue,
            respondedModel: response.model,
            upstreamProvider: response.upstreamProvider,
            generationID: response.id,
            finishReason: response.finishReason?.rawValue,
            temperature: request.sampling?.temperature,
            seed: request.sampling?.seed,
            sessionID: manifest.sessionID,
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            reasoningTokens: response.usage.reasoningTokens,
            cachedInputTokens: response.usage.cachedInputTokens,
            costUSD: response.usage.costUSD,
            startedAt: RunLog.timestamp(startedAt),
            durationMilliseconds: Int(duration.asTimeInterval * 1000))

        manifest.calls += 1
        manifest.inputTokens += response.usage.inputTokens ?? 0
        manifest.outputTokens += response.usage.outputTokens ?? 0
        manifest.cachedInputTokens += response.usage.cachedInputTokens ?? 0
        if let cost = response.usage.costUSD {
            manifest.spentUSD += cost
        } else {
            manifest.callsWithUnknownCost += 1
        }
        if let upstream = response.upstreamProvider { upstreams.insert(upstream) }
        models.insert(response.model)
        manifest.upstreamProviders = upstreams.sorted()
        manifest.respondedModels = models.sorted()

        try append(record)
        try writeTranscript(
            CallTranscript(
                stage: stage.rawValue,
                subject: subject,
                attempt: attempt,
                requestedModel: requestedModel.rawValue,
                request: request,
                response: response),
            sequence: record.sequence,
            stage: stage,
            subject: subject)
        try writeManifest()
        return record
    }

    /// 실패한 호출도 적는다. **실패가 로그에서 빠지면 재시도 횟수와 비용이 어긋난다.**
    public func recordFailure(
        stage: GenerationStage,
        subject: String,
        attempt: Int,
        requestedModel: ModelID,
        request: CompletionRequest,
        error: String,
        startedAt: Date,
        duration: Duration
    ) throws {
        sequence += 1
        let record = CallRecord(
            sequence: sequence,
            stage: stage.rawValue,
            subject: subject,
            attempt: attempt,
            requestedModel: requestedModel.rawValue,
            sessionID: manifest.sessionID,
            startedAt: RunLog.timestamp(startedAt),
            durationMilliseconds: Int(duration.asTimeInterval * 1000),
            error: error)
        manifest.calls += 1
        manifest.failedCalls += 1
        try append(record)
        try writeTranscript(
            CallTranscript(
                stage: stage.rawValue,
                subject: subject,
                attempt: attempt,
                requestedModel: requestedModel.rawValue,
                request: request,
                response: nil),
            sequence: record.sequence,
            stage: stage,
            subject: subject)
        try writeManifest()
    }

    /// 부속 파일 하나를 실행 디렉터리에 둔다. 검증 리포트·격리 명단이 이걸 쓴다.
    public func attach(_ data: Data, named name: String) throws {
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    /// 결산을 찍고 닫는다.
    @discardableResult
    public func finish(at date: Date = Date()) throws -> RunManifest {
        manifest.finishedAt = RunLog.timestamp(date)
        try writeManifest()
        return manifest
    }

    // MARK: - 쓰기

    private func writeManifest() throws {
        try encode(manifest).write(
            to: directory.appendingPathComponent("run.json"), options: .atomic)
    }

    private func append(_ record: CallRecord) throws {
        let url = directory.appendingPathComponent("calls.jsonl")
        var line = try encode(record, pretty: false)
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: url, options: .atomic)
        }
    }

    private func writeTranscript(
        _ transcript: CallTranscript,
        sequence: Int,
        stage: GenerationStage,
        subject: String
    ) throws {
        let safeSubject = subject.map { character -> Character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-")
                ? character : "-"
        }
        let name = String(format: "%04d-%@-%@.json", sequence, stage.rawValue, String(safeSubject))
        try encode(transcript).write(
            to: directory.appendingPathComponent("calls").appendingPathComponent(name),
            options: .atomic)
    }

    private func encode(_ value: some Encodable, pretty: Bool = true) throws -> Data {
        try Self.encode(value, pretty: pretty)
    }

    private nonisolated static func encode(_ value: some Encodable, pretty: Bool = true) throws
        -> Data
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty
            ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// 실행 디렉터리 이름에 쓰는 시각. 정렬하면 시간순이 되도록 고정폭이다.
    public static func runID(at date: Date = Date(), suffix: String? = nil) -> String {
        var formatter = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = formatter.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        let stamp = String(
            format: "%04d%02d%02d-%02d%02d%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        return suffix.map { "\(stamp)-\($0)" } ?? stamp
    }

    /// `YYYY-MM-DDTHH:MM:SSZ`. 팩 매니페스트의 정규 타임스탬프와 같은 모양이다.
    public static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02dZ",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }
}

public enum RunLogError: Error, Hashable, Sendable, CustomStringConvertible {
    case budgetExceeded(spentUSD: Double, budgetUSD: Double)

    public var description: String {
        switch self {
        case .budgetExceeded(let spent, let budget):
            String(
                format: "지출이 예산을 넘어 중단합니다 — 사용 $%.6f / 예산 $%.6f. --max-usd 를 올리거나 대상을 줄이십시오.",
                spent, budget)
        }
    }
}
