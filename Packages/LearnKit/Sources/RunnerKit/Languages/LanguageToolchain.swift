internal import Foundation
public import LanguageKit

/// 언어 어댑터가 "어느 바이너리를 쓸지" 물어보는 한 곳.
///
/// 감지 자체는 `ToolchainProbe` 가 이미 한다 — PATH 순서가 아니라 **버전 정책**으로
/// 고르고(`{#toolchain-probe}`), 이 머신에서는 `/usr/bin/python3`(3.9.6) 이 아니라
/// uv 의 3.14.3 이 이긴다. 어댑터가 그 규칙을 다시 쓰지 않게 하는 것이 이 타입의 일이다.
///
/// 프로세스 수명 동안 결과를 들고 있는 이유는 비용 때문이다. 로그인 PATH 수확
/// (`zsh -lic`, 최대 3초) + 후보마다 `--version` 실행이라 레슨을 열 때마다 하면
/// 체감이 무너진다. 툴체인 교체 감지는 `ToolchainProbeCache` 의 24시간 TTL 이 맡는다.
public actor LanguageToolchain {
    public static let shared = LanguageToolchain()

    private var probe: ToolchainProbe?
    private var reports: [String: ToolProbeReport] = [:]
    private var deshimmed: [String: String] = [:]
    /// 진행 중인 감지. **액터는 `await` 지점에서 재진입한다** — 캐시 확인과 감지 사이에
    /// 다른 태스크가 들어오면 둘 다 캐시가 비었다고 보고 각자 감지를 시작한다.
    /// 8개를 동시에 돌리면 `zsh -lic` 로그인 셸이 8번 뜨고, 실측에서 그 폭풍이
    /// 실행 하나를 30초 넘게 밀어냈다. 결과가 아니라 **진행 중인 작업**을 캐시해야
    /// "정확히 한 번"이 된다.
    private var probeTask: Task<ToolchainProbe, Never>?
    private var reportTasks: [String: Task<ToolProbeReport, Never>] = [:]

    public init() {}

    /// 감지 결과. 실패해도 던지지 않는다 — 온보딩 화면은 "무엇이 왜 없는지"를 그려야 한다.
    public func availability(for spec: ToolSpec) async -> ModuleAvailability {
        await report(for: spec).availability
    }

    public func report(for spec: ToolSpec) async -> ToolProbeReport {
        if let cached = reports[spec.id] { return cached }
        if let inFlight = reportTasks[spec.id] { return await inFlight.value }
        // Task 생성과 저장 사이에는 `await` 가 없다 — 그래서 이 검사·등록은 원자적이다.
        let task = Task { [spec] () -> ToolProbeReport in
            let probe = await resolvedProbe()
            return await probe.probe(spec)
        }
        reportTasks[spec.id] = task
        let report = await task.value
        reports[spec.id] = report
        reportTasks[spec.id] = nil
        return report
    }

    /// 실행 경로. 없으면 `RunFailure.toolchainMissing` — 격리 없는 실행으로 강등하지 않는다.
    public func executablePath(for spec: ToolSpec) async throws -> String {
        switch await availability(for: spec) {
        case .ready(_, let path):
            return await resolvingShim(path)
        case .missing(let hint):
            throw RunFailure.toolchainMissing(hint: hint)
        case .stub(let path, let reason):
            throw RunFailure.toolchainMissing(hint: "\(path) 는 동작하지 않는다: \(reason)")
        case .unsupported(let path, let version, let minimum):
            throw RunFailure.toolchainMissing(
                hint: "\(path) 는 \(version) 이라 최소 요구 버전 \(minimum) 에 못 미친다."
            )
        }
    }

    /// 테스트가 감지 비용 없이 경로를 꽂아 넣는 통로.
    public func override(_ availability: ModuleAvailability, for spec: ToolSpec) {
        reports[spec.id] = ToolProbeReport(
            toolID: spec.id,
            language: spec.language,
            availability: availability,
            candidates: []
        )
    }

    /// `/usr/bin` 아래의 개발도구는 실제 바이너리가 아니라 **xcrun 셰이더**다.
    ///
    /// 셰이더는 실행될 때 `<DARWIN_USER_TEMP_DIR>/xcrun_db-XXXX` 에 캐시를 쓴다.
    /// 샌드박스 프로파일 아래에서는 그 쓰기가 거부되어 stderr 에
    /// `couldn't create cache file …` 이 섞인다 — 종료 코드는 0 이라 실행 자체는
    /// 되지만 **우리가 파싱하는 stderr 가 오염된다.** 진단 파서와 테스트 출력 파서가
    /// 그 줄을 컴파일러 진단으로 오인한다.
    ///
    /// 프로파일을 열어 캐시 쓰기를 허용하는 것은 답이 아니다 — 캐시를 쓸 수 있으면
    /// 샌드박스 밖의 이후 `xcrun` 호출을 바꿔치기할 수 있고, 그건 탈출구다.
    /// 그래서 고치는 곳은 프로파일이 아니라 **실행 경로 선택**이다: `xcrun --find` 가
    /// 가리키는 실제 툴체인 경로를 `execv` 대상으로 쓴다(실측으로 stderr 가 깨끗함).
    ///
    /// `/usr/bin` 밖의 후보(uv·conda·homebrew)는 셰이더가 아니므로 손대지 않는다.
    func resolvingShim(_ path: String) async -> String {
        guard path.hasPrefix("/usr/bin/") else { return path }
        if let cached = deshimmed[path] { return cached }
        let name = URL(fileURLWithPath: path).lastPathComponent
        let result = await BoundedCommand.run(
            executable: "/usr/bin/xcrun",
            arguments: ["--find", name],
            timeout: .seconds(2)
        )
        var resolved = path
        if result.succeeded {
            let found = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !found.isEmpty,
               !found.hasPrefix("/usr/bin/"),
               FileManager.default.isExecutableFile(atPath: found) {
                resolved = found
            }
        }
        deshimmed[path] = resolved
        return resolved
    }

    private func resolvedProbe() async -> ToolchainProbe {
        if let probe { return probe }
        if let inFlight = probeTask { return await inFlight.value }
        let task = Task { await ToolchainProbe.standard() }
        probeTask = task
        let created = await task.value
        probe = created
        probeTask = nil
        return created
    }
}
