public import Observation
public import LanguageKit
public import LearnCore
public import RunnerKit
public import Foundation

/// 온보딩 화면의 상태 모델.
///
/// 목 데이터가 없다 — 기본 생성자는 `LanguageToolchain.shared`(실제 `ToolchainProbe`)를
/// 부른다. 뷰는 이 모델만 보고 그린다. 테스트는 `probeAvailability`/`clipboardWriter` 를
/// 주입해 프로세스 없이 매핑·집계·클립보드 계약만 검증한다.
///
/// 모듈의 기본 격리가 `MainActor` 다(`Package.swift` 의 `uiSettings`) — 그래서 이 클래스
/// 자체에 `@MainActor` 를 다시 적지 않는다.
@Observable
public final class OnboardingModel {
    /// 표의 한 행. 순서는 `displayOrder` 가 정한다.
    public struct Row: Identifiable, Sendable, Equatable {
        public let id: String
        /// 언어 트랙 이름. `ToolSpec.displayName` 은 도구 계열 이름이라(SQLite, Node.js,
        /// Assembler) 다른 세 트랙에서는 값이 갈린다 — `trackName(for:)` 을 따로 둔 이유.
        public let trackName: String
        /// 감지에 실제로 실행한 실행 파일 이름 (`ToolSpec.executableNames.first`).
        public let toolName: String
        public var status: RowStatus

        public init(id: String, trackName: String, toolName: String, status: RowStatus) {
            self.id = id
            self.trackName = trackName
            self.toolName = toolName
            self.status = status
        }
    }

    /// 감지가 끝나기 전엔 자리부터 예약한다 — 결과가 채워질 때 행 높이가 튀지 않게.
    public enum RowStatus: Equatable, Sendable {
        case scanning
        case resolved(ModuleAvailability)
    }

    /// 상단 집계. 세 버킷의 합은 항상 `total` 과 같다(스캔 중인 행은 어디에도 안 든다).
    ///
    /// `.unsupported` 는 `.missing` 과 같은 버킷("미설치")으로 접는다 — 표에서도 같은
    /// 빈 사각으로 그리므로, 집계 숫자와 화면에 보이는 사각 개수가 어긋나지 않아야 한다.
    public struct Summary: Equatable, Sendable {
        public var installed: Int
        public var missing: Int
        public var problem: Int
        public var total: Int

        public init(installed: Int, missing: Int, problem: Int, total: Int) {
            self.installed = installed
            self.missing = missing
            self.problem = problem
            self.total = total
        }
    }

    public private(set) var rows: [Row]
    public private(set) var isScanning = false
    public private(set) var lastScanFinishedAt: Date?

    private let specs: [ToolSpec]
    /// `nil` 이면 `scan()` 이 `LanguageToolchain.shared.availability(for:)` 로 떨어진다.
    ///
    /// `clipboardWriter` 와 같은 이유로 `nil` 기본값 + 폴백 분기를 쓴다 — **실측으로 밟은
    /// 함정**이다. `probeAvailability: @escaping @Sendable (ToolSpec) async ->
    /// ModuleAvailability = { await LanguageToolchain.shared.availability(for: $0) }` 처럼
    /// 클로저를 기본 인자 값으로 주면, 다른 모듈(`OnboardingFeatureTests`)에서 이
    /// 파라미터를 생략해 크로스 모듈 기본 인자 생성자가 호출될 때만
    /// `freed pointer was not the last allocation` 로 테스트 프로세스가 죽었다. 같은
    /// 클로저를 호출부에서 **명시적으로** 넘기면(`RunnerKitTests.ToolchainProbeTests` 가
    /// 실제로 하는 것과 동일한 실행 경로) 10개 스펙을 전부 돌려도 멀쩡했다 — 원인은
    /// `async`+`@Sendable` 클로저를 기본 인자로 둔 `@MainActor` 격리 이니셜라이저의
    /// 크로스 모듈 호출 조합 쪽으로 좁혀지고, 이 패키지의 로직 버그가 아니라 그 조합
    /// 자체의 문제로 보인다. 재현을 더 좁히는 대신 그 조합 자체를 피한다.
    private let probeAvailability: (@Sendable (ToolSpec) async -> ModuleAvailability)?
    /// `nil` 이면 `copyInstallHint` 가 `SystemClipboard.write` 로 떨어진다. 위와 같은 함정
    /// 때문에 `nil` 기본값 + 폴백 분기를 쓴다.
    private let clipboardWriter: (@Sendable (String) -> Void)?

    public init(
        specs: [ToolSpec] = OnboardingModel.displayOrder,
        probeAvailability: (@Sendable (ToolSpec) async -> ModuleAvailability)? = nil,
        clipboardWriter: (@Sendable (String) -> Void)? = nil
    ) {
        self.specs = specs
        self.probeAvailability = probeAvailability
        self.clipboardWriter = clipboardWriter
        self.rows = specs.map {
            Row(
                id: $0.id,
                trackName: OnboardingModel.trackName(for: $0.language),
                toolName: $0.executableNames.first ?? $0.id,
                status: .scanning
            )
        }
    }

    /// 카탈로그 순서(`ToolchainCatalog.all`)가 아니라 **디자인의 행 순서**다 —
    /// `go, java, node, typescript` 구간이 다르다(Next.js 가 TypeScript 보다 앞).
    public static let displayOrder: [ToolSpec] = [
        ToolchainCatalog.python, ToolchainCatalog.sqlite, ToolchainCatalog.swift,
        ToolchainCatalog.rust, ToolchainCatalog.cpp, ToolchainCatalog.go,
        ToolchainCatalog.java, ToolchainCatalog.node, ToolchainCatalog.typescript,
        ToolchainCatalog.assembler,
    ]

    /// `LanguageID` → 화면에 보여줄 트랙 이름.
    public static func trackName(for language: LanguageID) -> String {
        switch language.rawValue {
        case "python": "Python"
        case "sql": "SQL"
        case "swift": "Swift"
        case "rust": "Rust"
        case "cpp": "C++"
        case "go": "Go"
        case "java": "Java"
        case "nextjs": "Next.js"
        case "typescript": "TypeScript"
        case "assembly": "Assembly"
        default: language.rawValue
        }
    }

    /// 실제 판정 결과에서만 계산한다 — 하드코딩 없음.
    public var summary: Summary {
        var installed = 0
        var missing = 0
        var problem = 0
        for row in rows {
            guard case let .resolved(availability) = row.status else { continue }
            switch availability {
            case .ready:
                installed += 1
            case .missing, .unsupported:
                missing += 1
            case .stub:
                problem += 1
            }
        }
        return Summary(installed: installed, missing: missing, problem: problem, total: rows.count)
    }

    /// 10개 트랙을 **순차로** 진단한다.
    ///
    /// `RunnerKitTests.ToolchainProbeTests.detectAllToolchains` 가 이미 검증한 것과 같은
    /// 실행 패턴(스펙을 하나씩 `await`)이라 안전하다는 근거가 있다. `withTaskGroup` 으로
    /// 10개를 동시에 돌리는 버전도 시도했지만 비교할 값어치가 없었다 — 이 머신에서
    /// 실측 결과가 보통 3~4초면 끝나(모든 후보가 타임아웃 없이 빠르게 응답) 순차 실행의
    /// 체감 비용이 크지 않고, 검증된 패턴을 벗어날 이유가 없었다.
    public func scan() async {
        isScanning = true
        defer { isScanning = false }
        for (index, spec) in specs.enumerated() {
            let availability = await resolveAvailability(for: spec)
            rows[index].status = .resolved(availability)
        }
        lastScanFinishedAt = Date()
    }

    private func resolveAvailability(for spec: ToolSpec) async -> ModuleAvailability {
        if let probeAvailability {
            await probeAvailability(spec)
        } else {
            await LanguageToolchain.shared.availability(for: spec)
        }
    }

    /// `installHint` 를 그대로 클립보드에 넣는다. **프로세스를 실행하지 않는다** —
    /// 설치는 언제나 사용자가 터미널에서 직접 한다.
    public func copyInstallHint(_ hint: String) {
        if let clipboardWriter {
            clipboardWriter(hint)
        } else {
            SystemClipboard.write(hint)
        }
    }
}
