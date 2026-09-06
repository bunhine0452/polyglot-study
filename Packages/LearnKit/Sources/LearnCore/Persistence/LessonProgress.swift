/// 레슨 하나의 6블록 시퀀스.
///
/// 개념 → 실행 예제 → 빈칸 → 테스트 과제 → 퀴즈 → 회고. 언어가 달라도 이 골격은 같다 —
/// 이질성은 `ResultPresenter` 와 `LanguageAdapter` 두 곳에만 가둔다.
public enum LessonBlockSequence {
    public static let count = 6
    public static var indices: Range<Int> { 0..<count }
    public static func contains(_ index: Int) -> Bool { indices.contains(index) }
}

public enum LessonStatus: String, Hashable, Sendable, Codable, CaseIterable {
    case notStarted
    case inProgress
    case completed
    /// 사용자가 건너뛴 레슨. `completed` 와 섞으면 진도율이 거짓말을 한다.
    case skipped
}

/// `lesson_progress` 한 행. PK 는 `(pack_id, lesson_id)`.
///
/// 시도 횟수 컬럼이 없는 것은 의도다 — `submission` 을 세면 나오는 값을 여기 이중 기록하면
/// 제출 보존 정책(실패 20건 상한)이 돌 때 두 값이 어긋난다.
public struct LessonProgress: Hashable, Sendable, Codable {
    public var packID: PackID
    public var lessonID: LessonID
    public var languageID: LanguageID
    public var status: LessonStatus
    /// 완료한 블록 인덱스. **항상 정렬·중복 제거된 상태**로 유지되며 JSON 배열로 저장된다.
    public var completedBlocks: [Int]
    public var currentBlockIndex: Int
    public var startedAt: EpochMilliseconds?
    public var lastActivityAt: EpochMilliseconds?
    public var completedAt: EpochMilliseconds?

    public init(
        packID: PackID,
        lessonID: LessonID,
        languageID: LanguageID,
        status: LessonStatus = .notStarted,
        completedBlocks: [Int] = [],
        currentBlockIndex: Int = 0,
        startedAt: EpochMilliseconds? = nil,
        lastActivityAt: EpochMilliseconds? = nil,
        completedAt: EpochMilliseconds? = nil
    ) {
        self.packID = packID
        self.lessonID = lessonID
        self.languageID = languageID
        self.status = status
        self.completedBlocks = completedBlocks.sorted()
        self.currentBlockIndex = currentBlockIndex
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.completedAt = completedAt
    }
}

extension LessonProgress {
    public var isFullyCompleted: Bool {
        Set(completedBlocks) == Set(LessonBlockSequence.indices)
    }

    /// 블록 하나를 완료 처리한 새 값을 만든다. **DB 를 모르는 순수 함수**라 페이크·GRDB 구현이 공유하고,
    /// 전이 규칙 자체를 단위 테스트할 수 있다.
    ///
    /// 규칙
    /// - `notStarted` 는 첫 완료에서 `inProgress` 로 가고 `startedAt` 이 박힌다.
    /// - 6개가 다 차면 `completed` 로 가고 `completedAt` 이 박힌다.
    /// - `skipped` 는 건드리지 않는다 — 건너뛴 레슨에 진도를 다시 쌓는 건 사용자 명시적 행동이어야 한다.
    /// - 범위 밖 인덱스는 무시한다. CHECK 제약이 어차피 거부하므로 여기서 조용히 떨어뜨린다.
    public func completing(block index: Int, at timestamp: EpochMilliseconds) -> LessonProgress {
        guard LessonBlockSequence.contains(index), status != .skipped else { return self }

        var next = self
        if !next.completedBlocks.contains(index) {
            next.completedBlocks = (next.completedBlocks + [index]).sorted()
        }
        next.lastActivityAt = timestamp
        if next.startedAt == nil { next.startedAt = timestamp }
        next.currentBlockIndex = min(
            LessonBlockSequence.count - 1,
            max(next.currentBlockIndex, index + 1)
        )

        if next.isFullyCompleted {
            next.status = .completed
            if next.completedAt == nil { next.completedAt = timestamp }
        } else {
            next.status = .inProgress
            next.completedAt = nil
        }
        return next
    }
}
