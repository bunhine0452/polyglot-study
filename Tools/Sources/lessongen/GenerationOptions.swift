import ArgumentParser
import Foundation
import LessonGenKit
import LLMKit
import OpenRouterKit

/// `lesson` 과 `repair` 가 공유하는 옵션.
///
/// 공급자 조립·실행 로그·비용 가드가 두 커맨드에서 같아야 하므로 한 군데에 둔다.
/// 여기서 만들어지는 것은 셋이다 — 공급자, 실행 로그, 그 둘을 묶은 ``MeteredClient``.
struct GenerationOptions: ParsableArguments {
    @Option(
        name: .long,
        help: "모델 ID. 생략하면 \(ModelID.environmentVariableName) (단계별 오버라이드는 그대로 적용)."
    )
    var model: String?

    @Option(name: .long, help: "사고 노력 수준. 이 모델은 low/high/max 만 받습니다 (medium 없음).")
    var effort: ReasoningEffort = .high

    @Option(name: .long, help: "레슨 하나당 응답 최대 토큰.")
    var maxTokens: Int = 24000

    @Option(name: .long, help: "샘플링 온도. 생략하면 모델 기본값.")
    var temperature: Double?

    @Option(name: .long, help: "샘플링 시드. 재현을 노릴 때 지정합니다 (보장은 아닙니다).")
    var seed: Int?

    @Option(name: .long, help: "동시에 띄울 요청 수. Batch 엔드포인트 대신 쓰는 팬아웃 폭입니다.")
    var concurrency: Int = 4

    @Option(
        name: .long,
        help: """
            이 실행의 지출 상한(USD). 넘으면 남은 요청을 시작하지 않고 중단합니다. \
            이미 나간 요청은 되돌릴 수 없으므로 상한이 아니라 정지선입니다.
            """
    )
    var maxUsd: Double?

    @Option(
        name: .long,
        help: """
            캐시 친화 라우팅 키. 같은 값을 쓰는 요청이 같은 업스트림에 붙습니다 — \
            프롬프트 캐시가 업스트림에 붙어 있어서 이게 캐시 적중의 전제입니다.
            """
    )
    var sessionID: String = "polyglot-lessongen"

    @Option(
        name: .customLong("provider"),
        help: """
            업스트림을 이 이름으로 고정합니다. 여러 번 주면 우선순위 순입니다. \
            session_id 는 힌트일 뿐이고 이쪽이 제약입니다 — 실측상 힌트만으로는 \
            업스트림이 갈려 프롬프트 캐시가 매번 차가웠습니다. 이름은 실행 로그 \
            run.json 의 upstreamProviders 에서 가져오십시오.
            """
    )
    var providers: [String] = []

    @Flag(
        name: .long,
        help: """
            --provider 로 고정한 업스트림이 모두 불가할 때 다른 곳으로 넘어갑니다. \
            기본은 금지입니다 — 조용히 새면 캐시는 차가운데 요청은 성공해서 고정이 \
            실패한 줄 아무도 모릅니다.
            """
    )
    var allowProviderFallback = false

    @Option(name: .long, help: "실행 로그를 남길 뿌리 디렉터리.")
    var runsDirectory: String = ".lessongen/runs"

    @Option(name: .long, help: "직렬화가 거부했을 때 모델에게 다시 물어볼 횟수.")
    var serializationRetries: Int = 1

    @Option(name: .customLong("env-file"), help: ".env 파일 경로. 생략하면 현재 디렉터리부터 위로 찾습니다.")
    var envFile: String?

    @Flag(name: .long, help: "호출하지 않고 보낼 요청만 출력합니다. API 키가 없어도 됩니다.")
    var dryRun = false

    @Flag(name: [.customShort("v"), .long], help: "진행 로그를 stderr 로 출력합니다.")
    var verbose = false

    func validate() throws {
        guard maxTokens > 0 else { throw ValidationError("--max-tokens 는 1 이상이어야 합니다.") }
        guard concurrency > 0 else { throw ValidationError("--concurrency 는 1 이상이어야 합니다.") }
        guard serializationRetries >= 0 else {
            throw ValidationError("--serialization-retries 는 0 이상이어야 합니다.")
        }
        if let maxUsd, maxUsd <= 0 { throw ValidationError("--max-usd 는 0 보다 커야 합니다.") }
        guard !sessionID.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError("--session-id 는 비울 수 없습니다 — 비우면 캐시가 매번 차갑습니다.")
        }
        if providers.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            throw ValidationError("--provider 에 빈 이름을 줄 수 없습니다.")
        }
        if allowProviderFallback && providers.isEmpty {
            throw ValidationError("--allow-provider-fallback 은 --provider 와 함께 써야 의미가 있습니다.")
        }
    }

    /// 업스트림 고정. 이름이 하나도 없으면 nil 이다.
    var upstreamPin: UpstreamPin? {
        UpstreamPin(providers: providers, allowFallbacks: allowProviderFallback)
    }

    var sampling: SamplingParameters? {
        guard temperature != nil || seed != nil else { return nil }
        return SamplingParameters(temperature: temperature, seed: seed)
    }

    var log: any ClientLogSink { verbose ? StandardErrorLog() : DiscardLog() }

    /// 환경변수와 `.env` 를 겹친 조회 창구. 프로세스 환경변수가 항상 이긴다.
    func environment() throws -> EnvironmentSource {
        guard let envFile else { return .discovering() }
        let url = URL(fileURLWithPath: envFile)
        do {
            return EnvironmentSource(dotEnv: try DotEnv.load(from: url))
        } catch {
            throw CLIError("--env-file 을 읽지 못했습니다: \(url.path)")
        }
    }

    /// 모델 선택. 키가 없어도 `--dry-run` 이 돌아야 하므로 키보다 먼저 정한다.
    func modelSelection(_ environment: EnvironmentSource) throws -> ModelSelection {
        do {
            return try ModelSelection.fromEnvironment(
                environment.merged, override: model.map { ModelID($0) })
        } catch {
            throw CLIError(String(describing: error))
        }
    }

    func apiKey(_ environment: EnvironmentSource) throws -> APIKey {
        do {
            return try APIKey.fromEnvironment(environment.merged)
        } catch {
            if dryRun {
                // 요청 모양만 보여 주는 자리라 실제로 쓰이지 않는다.
                return try APIKey(rawValue: "sk-or-v1-DRY-RUN-PLACEHOLDER")
            }
            throw CLIError(String(describing: error))
        }
    }

    /// 공급자. `require_parameters` 는 **끄지 않는다** — 끄면 구조화 출력을 모르는
    /// 업스트림이 200 과 함께 산문을 돌려주고, 그건 스키마 위반이 아니라 JSON 이 아예
    /// 아닌 응답이라 한참 뒤 파싱 실패로만 드러난다.
    func provider(apiKey: APIKey, model: ModelID) -> OpenRouterProvider {
        OpenRouterProvider(
            apiKey: apiKey,
            model: model,
            configuration: OpenRouterProvider.Configuration(
                requireParameters: true,
                sessionID: sessionID,
                upstreamPin: upstreamPin),
            log: log)
    }

    /// 실행 로그. 실행마다 디렉터리 하나.
    func runLog(command: String, models: ModelSelection, startedAt: Date = Date()) throws -> RunLog
    {
        try RunLog(
            rootDirectory: URL(fileURLWithPath: runsDirectory, isDirectory: true),
            runID: RunLog.runID(at: startedAt, suffix: command),
            command: command,
            startedAt: startedAt,
            models: models,
            sessionID: sessionID,
            budgetUSD: maxUsd,
            pinnedProviders: upstreamPin?.providers ?? [])
    }

    /// 실행 로그의 재현 재료. **모델은 비밀이 아니라 남겨야 하고, 키는 출처만 남긴다.**
    func logRunHeader(
        _ sink: any ClientLogSink,
        stage: GenerationStage,
        selection: ModelSelection,
        environment: EnvironmentSource,
        runDirectory: URL
    ) {
        guard verbose else { return }
        sink.write(
            "[lessongen] 단계=\(stage.rawValue) 모델=\(selection.model(for: stage)) (\(selection.origin(for: stage)))")
        sink.write("[lessongen] 단계별 모델 — \(selection.logLine)")
        sink.write("[lessongen] session_id=\(sessionID) 실행 로그=\(runDirectory.path)")
        sink.write("[lessongen] 업스트림 고정=\(upstreamPin?.logLine ?? "없음 — 캐시가 차가울 수 있다")")
        sink.write(
            "[lessongen] 키 출처=\(environment.origin(of: APIKey.environmentVariableName) ?? "없음")")
    }
}
