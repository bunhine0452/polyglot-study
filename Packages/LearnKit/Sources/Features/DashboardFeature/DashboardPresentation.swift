public import DesignSystem
public import LearnCore

// MARK: - 진도 칸

/// 완료 수 · 총수 → 진도 칸 배열.
///
/// `SegmentedProgress` 에도 같은 규칙의 편의 이니셜라이저가 있지만, 조립된 칸 배열을
/// 밖에서 읽는 `cellStates` 는 `DesignSystem` 내부 접근이다. 대시보드는 **부여된 진도**가
/// 어느 칸을 채우는지를 렌더 없이 단언해야 하므로(`{#progress-cell-states}`) 배열을
/// 모델에서 만들어 프리미티브에 넘긴다 — 프리미티브는 그리기만 한다.
public enum ProgressCells {
    /// - Parameter showsCurrent: `completed` 번째 칸을 "현재" 로 표시할지. 트랙을 아직 열지
    ///   않았거나 다 끝냈으면 `false` — 없는 현재 위치를 지어내지 않는다.
    public static func build(completed: Int, total: Int, showsCurrent: Bool) -> [ProgressCellState] {
        let total = max(0, total)
        let done = max(0, min(completed, total))
        return (0..<total).map { index in
            if index < done { return .done }
            if index == done, showsCurrent { return .current }
            return .future
        }
    }
}

// MARK: - 트랙 행

/// 트랙 한 줄이 지금 어떤 상태인가. 표의 이름 옆 라벨이 이것 하나로 결정된다.
public enum TrackStage: Hashable, Sendable, CaseIterable {
    /// 콘텐츠는 있는데 아직 한 번도 열지 않았다. **진도 칸이 하나도 채워지지 않는다** —
    /// 부여된 진도는 트랙을 연 사람에게만 준다.
    case notStarted
    /// 오리엔테이션만 완료된 상태. 디자인의 Python 행.
    case justStarted
    /// 진행 중.
    case active
    /// 콘텐츠 준비 중인 7트랙. 흐리게 그린다.
    case comingSoon

    public var label: String {
        switch self {
        case .notStarted: "아직 시작 안 함"
        case .justStarted: "방금 시작"
        case .active: "활성"
        case .comingSoon: "준비 중"
        }
    }

    /// 잉크로 그릴지 흐리게 그릴지. 준비 중 7트랙만 흐리다(`{#screen-dashboard}`).
    public var isDimmed: Bool { self == .comingSoon }
}

/// "이어서" 가 가리키는 자리가 **멈춘 레슨**인지 **다음 레슨**인지.
///
/// 둘을 나누는 이유는 자이가르닉 효과 때문이다 — 화면 최상단 카드에 올라갈 자격이 있는
/// 것은 열린 채로 남은 레슨뿐이다. 아직 열지 않은 다음 레슨은 미완성 긴장이 아니다.
public enum ResumeKind: Hashable, Sendable {
    /// 블록 도중에 멈춘 레슨. `blockIndex` 는 0-기반 진행 중 블록.
    case open(blockIndex: Int, completedBlocks: Int)
    /// 아직 열지 않은 다음 레슨.
    case next
}

/// 트랙 하나의 "이어서" 자리.
public struct ResumePoint: Hashable, Sendable, Identifiable {
    public let languageID: LanguageID
    public let trackName: String
    /// 이 레슨이 사는 팩. 조립 루트가 레슨을 열려면 팩까지 알아야 한다 — 트랙마다
    /// 팩이 다르므로 `lessonID` 만으로는 어느 팩을 읽을지가 정해지지 않는다.
    public let packID: PackID
    public let lessonID: LessonID
    /// 팩 안에서의 1-기반 순번. 팩 메타데이터가 없으면 `nil` — 없는 번호를 지어내지 않는다.
    public let lessonOrdinal: Int?
    /// 레슨 제목. 팩 메타데이터가 없으면 `lessonID` 문자열 그대로다.
    public let lessonTitle: String
    public let lessonTotal: Int
    public let kind: ResumeKind
    public let lastActivityAt: EpochMillis?

    public var id: String { "\(languageID.rawValue)/\(packID.rawValue)/\(lessonID.rawValue)" }

    /// 이 레슨을 여는 데 필요한 전부.
    public var ref: LessonRef { LessonRef(packID: packID, lessonID: lessonID) }

    public init(
        languageID: LanguageID,
        trackName: String,
        packID: PackID,
        lessonID: LessonID,
        lessonOrdinal: Int?,
        lessonTitle: String,
        lessonTotal: Int,
        kind: ResumeKind,
        lastActivityAt: EpochMillis?
    ) {
        self.languageID = languageID
        self.trackName = trackName
        self.packID = packID
        self.lessonID = lessonID
        self.lessonOrdinal = lessonOrdinal
        self.lessonTitle = lessonTitle
        self.lessonTotal = lessonTotal
        self.kind = kind
        self.lastActivityAt = lastActivityAt
    }

    /// 멈춘 레슨인가. 최상단 "이어서" 카드의 후보 판정.
    public var isOpen: Bool {
        if case .open = kind { return true }
        return false
    }

    /// 완료한 블록 수. 아직 열지 않은 레슨은 0.
    public var completedBlocks: Int {
        if case let .open(_, completed) = kind { return completed }
        return 0
    }

    /// 진행 중 블록의 0-기반 인덱스. 아직 열지 않은 레슨은 0(= 첫 블록).
    public var blockIndex: Int {
        if case let .open(index, _) = kind { return index }
        return 0
    }

    public var blockName: String? { LessonBlockNames.name(at: blockIndex) }

    /// **자이가르닉** — 진행 중 블록은 채우지 않고 빈 윤곽 칸으로 남긴다.
    /// 완료 블록만 잉크로 채워지므로 "여기까지 했고 여기서 멈췄다" 가 한눈에 보인다.
    public var blockCells: [ProgressCellState] {
        ProgressCells.build(
            completed: completedBlocks,
            total: LessonBlockSequence.count,
            showsCurrent: isOpen
        )
    }

    public var remainingBlocks: Int { max(0, LessonBlockSequence.count - completedBlocks) }

    /// 남은 블록 하나에 잡는 시간. 토큰에 없는 값이라 여기서 고정한다 —
    /// 디자인 실측(`남은 블록 3 · 약 15분`)에서 역산한 5분이다.
    public static let minutesPerBlock = 5

    public var remainingMinutes: Int { remainingBlocks * Self.minutesPerBlock }

    /// "07 값 타입과 참조 타입" — 순번을 모르면 제목만.
    ///
    /// 자릿수를 맞추는 것은 장식이 아니다. 표의 "이어서" 열이 모노가 아닌 산스라
    /// 한 자리와 두 자리가 섞이면 제목 시작점이 행마다 어긋난다.
    public var headline: String {
        guard let lessonOrdinal else { return lessonTitle }
        let padded = lessonOrdinal < 10 ? "0\(lessonOrdinal)" : "\(lessonOrdinal)"
        return "\(padded) \(lessonTitle)"
    }

    /// "블록 4 / 6 · 테스트 과제". 아직 열지 않은 레슨은 `nil`.
    public var blockLine: String? {
        guard isOpen, let blockName else { return nil }
        return "블록 \(blockIndex + 1) / \(LessonBlockSequence.count) · \(blockName)"
    }
}

/// 트랙 표의 한 행.
public struct TrackRow: Identifiable, Hashable, Sendable {
    public let descriptor: TrackDescriptor
    public let stage: TrackStage
    /// 화면에 보이는 완료 레슨 수. **부여된 진도가 반영된 값**이다.
    public let completedLessons: Int
    /// 저장소에 실제로 `completed` 로 기록된 레슨 수. 부여분이 빠진 원본.
    public let recordedLessons: Int
    /// 칸 수는 언제나 `descriptor.lessonTotal` 과 같다(`{#screen-dashboard}` 완료 기준).
    public let cells: [ProgressCellState]
    public let resume: ResumePoint?
    /// 오늘 이 트랙에서 도착한 복습 수. 준비 중 트랙은 `nil` — 0 과 다르다.
    public let dueToday: Int?
    public let toolchain: TrackToolchainStatus

    public var id: String { descriptor.id }
    public var name: String { descriptor.name }
    public var languageID: LanguageID { descriptor.languageID }
    public var lessonTotal: Int { descriptor.lessonTotal }

    /// **화면이 부여한 진도인가.** 저장소에 완료 기록이 하나도 없는데 첫 칸이 채워져
    /// 있는 상태다. 트랙을 연 순간 오리엔테이션을 완료로 세지만, 그 사실을 숨기지 않는다
    /// (`orientationCredit`).
    public var isEndowed: Bool { recordedLessons == 0 && completedLessons == 1 }

    /// 채워진 칸이 오리엔테이션 하나뿐인가. 저장소가 01 을 완료로 들고 있든(앱이 트랙을
    /// 열 때 기록한 경우) 화면이 부여했든 같은 상태이고, 같은 문구를 낸다.
    public var orientationCredit: Bool {
        completedLessons == 1 && !(resume?.isOpen ?? false)
    }

    /// "7 / 24".
    public var progressLabel: String { "\(completedLessons) / \(lessonTotal)" }

    /// 준비 중 트랙의 진도 열 문구 — "26 레슨 · 콘텐츠 준비 중".
    public var pendingContentLabel: String { "\(lessonTotal) 레슨 · 콘텐츠 준비 중" }

    /// "이어서" 열의 두 번째 줄.
    public var resumeCaption: String? {
        if let blockLine = resume?.blockLine { return blockLine }
        if orientationCredit { return "01 오리엔테이션은 완료로 기록됨" }
        return nil
    }

    public init(
        descriptor: TrackDescriptor,
        stage: TrackStage,
        completedLessons: Int,
        recordedLessons: Int,
        cells: [ProgressCellState],
        resume: ResumePoint?,
        dueToday: Int?,
        toolchain: TrackToolchainStatus
    ) {
        self.descriptor = descriptor
        self.stage = stage
        self.completedLessons = completedLessons
        self.recordedLessons = recordedLessons
        self.cells = cells
        self.resume = resume
        self.dueToday = dueToday
        self.toolchain = toolchain
    }
}

// MARK: - 오늘의 복습

/// 오늘의 복습 카드가 그리는 값 전부.
public struct ReviewSummary: Hashable, Sendable {
    /// 트랙 하나의 오늘 도착 수.
    public struct TrackCount: Hashable, Sendable, Identifiable {
        public let name: String
        public let count: Int
        public var id: String { name }

        public init(name: String, count: Int) {
            self.name = name
            self.count = count
        }
    }

    /// 트랙별 도착 수. 큰 것부터.
    public let perTrack: [TrackCount]
    public let total: Int
    /// **축적 프레이밍** — 연속 학습일. 0 이면 라벨을 내지 않는다.
    /// 여기에 만료·경고 개념은 없다. `streakDays` 는 늘기만 하거나 다시 1부터 센다.
    public let streakDays: Int

    /// 카드 한 장에 잡는 시간(초). 디자인 실측(`12장 · 약 8분`)에서 역산했다.
    public static let secondsPerCard = 40

    public init(perTrack: [TrackCount], total: Int, streakDays: Int) {
        self.perTrack = perTrack
        self.total = total
        self.streakDays = streakDays
    }

    public var estimatedMinutes: Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total * Self.secondsPerCard) / 60).rounded()))
    }

    /// "Swift 7 · SQL 4 · Python 1 · 약 8분". 도착한 복습이 없으면 `nil`.
    public var breakdownLine: String? {
        guard total > 0 else { return nil }
        let parts = perTrack.filter { $0.count > 0 }.map { "\($0.name) \($0.count)" }
        return (parts + ["약 \(estimatedMinutes)분"]).joined(separator: " · ")
    }

    /// **"14일째".** 위협 문구를 만들지 않는다 — 끊긴다는 말도, 남은 시간도 없다.
    /// 쌓인 것만 센다.
    public var streakLabel: String? {
        streakDays > 0 ? "\(streakDays)일째" : nil
    }
}
