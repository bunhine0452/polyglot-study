public import DesignSystem
public import LearnCore
public import Observation

/// 트랙 화면의 상태 모델 — 트랙 하나를 골라 **그 트랙의 레슨 목록**을 보는 자리.
///
/// 대시보드와 같은 타깃에 있는 이유는 둘이 같은 어휘를 쓰기 때문이다 —
/// `TrackCatalog`·`TrackDescriptor`·`ProgressCells`·`LessonProgressStore`. 화면을 나눈다고
/// 이 넷을 두 번 정의하면 같은 트랙이 두 화면에서 다르게 보인다.
///
/// 대시보드와 **역할이 다르다.** 대시보드는 "지금 이어서 할 것 하나" 를 가리키고,
/// 여기는 "이 트랙에 무엇이 있고 어디까지 했나" 를 전부 펼친다. 임의의 레슨으로 들어가는
/// 유일한 길이 여기다.
///
/// 모듈 기본 격리가 `MainActor` 다(`Package.swift` 의 `uiSettings`).
@Observable
public final class TracksModel {
    /// 레슨 한 줄.
    public struct LessonRow: Identifiable, Hashable, Sendable {
        public let ref: LessonRef
        /// 트랙 안 1-기반 순번. 팩 메타가 없으면 목록 위치로 채운다.
        public let ordinal: Int
        public let title: String
        public let status: LessonStatus
        /// 완료한 블록 수(0…6).
        public let completedBlocks: Int
        /// 진행 중 블록의 0-기반 인덱스. 열지 않았으면 0.
        public let blockIndex: Int

        public var id: String { "\(ref.packID.rawValue)/\(ref.lessonID.rawValue)" }

        /// `01` … `12`. 자릿수를 맞춰야 제목 시작점이 행마다 어긋나지 않는다.
        public var ordinalLabel: String { ordinal < 10 ? "0\(ordinal)" : "\(ordinal)" }

        public var isOpen: Bool { status == .inProgress }

        /// **자이가르닉** — 대시보드의 "이어서" 카드와 같은 규칙이다. 진행 중 블록은
        /// 채우지 않고 빈 윤곽 칸으로 남긴다.
        public var blockCells: [ProgressCellState] {
            ProgressCells.build(
                completed: completedBlocks,
                total: LessonBlockSequence.count,
                showsCurrent: isOpen
            )
        }

        /// 상태 열 한 줄. 진행 중이면 어디서 멈췄는지까지 적는다.
        public var statusLabel: String {
            switch status {
            case .completed: "완료"
            case .inProgress:
                "블록 \(blockIndex + 1) / \(LessonBlockSequence.count)"
            case .skipped: "건너뜀"
            case .notStarted: "아직 안 함"
            }
        }
    }

    /// 트랙 하나 — 왼쪽 목록의 한 줄이자 오른쪽 본문의 내용.
    public struct Track: Identifiable, Hashable, Sendable {
        public let descriptor: TrackDescriptor
        /// `order` 순. 콘텐츠가 없는 트랙은 빈 배열이다.
        public let lessons: [LessonRow]

        public var id: String { descriptor.id }
        public var name: String { descriptor.name }
        public var languageID: LanguageID { descriptor.languageID }
        public var hasContent: Bool { descriptor.hasContent }

        public var completedLessons: Int { lessons.count { $0.status == .completed } }

        /// "3 / 12" — 콘텐츠가 있는 트랙만. 없는 트랙은 계획 총수를 말한다.
        public var progressLabel: String {
            hasContent
                ? "\(completedLessons) / \(descriptor.lessonTotal)"
                : "\(descriptor.lessonTotal) 레슨"
        }

        public var caption: String { hasContent ? "" : "준비 중" }
    }

    // MARK: - 관측 상태

    public private(set) var tracks: [Track] = []
    /// 지금 보고 있는 트랙. 콘텐츠가 있는 첫 트랙이 기본값이다.
    public var selection: LanguageID?
    public private(set) var isLoading = false
    /// 진도 읽기가 실패했다. 실패를 "아직 아무것도 안 함" 으로 그리지 않기 위한 플래그.
    public private(set) var lastLoadFailed = false

    public var selectedTrack: Track? {
        guard let selection else { return tracks.first { $0.hasContent } }
        return tracks.first { $0.languageID == selection }
    }

    // MARK: - 주입

    private let packIDs: [PackID]
    private let catalog: [TrackDescriptor]
    private let progressStore: any LessonProgressStore
    private let lessonMetadata: (@Sendable (PackID, LessonID) -> DashboardModel.LessonMetadata?)?
    private let lessonDirectory: (@Sendable (LanguageID) -> [LessonRef])?

    public init(
        packIDs: [PackID] = [DashboardModel.defaultPackID],
        catalog: [TrackDescriptor] = TrackCatalog.all,
        progressStore: (any LessonProgressStore)? = nil,
        lessonMetadata: (@Sendable (PackID, LessonID) -> DashboardModel.LessonMetadata?)? = nil,
        lessonDirectory: (@Sendable (LanguageID) -> [LessonRef])? = nil
    ) {
        self.packIDs = packIDs
        self.catalog = catalog
        self.progressStore = progressStore ?? InMemoryStores().lessonProgress
        self.lessonMetadata = lessonMetadata
        self.lessonDirectory = lessonDirectory
        self.tracks = catalog.map { Track(descriptor: $0, lessons: []) }
    }

    // MARK: - 적재

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let progress = await progressByRef() else {
            lastLoadFailed = true
            return
        }
        lastLoadFailed = false
        tracks = catalog.map { descriptor in
            Track(
                descriptor: descriptor,
                lessons: rows(for: descriptor.languageID, progress: progress)
            )
        }
        if selection == nil || !tracks.contains(where: { $0.languageID == selection }) {
            selection = tracks.first { $0.hasContent }?.languageID
        }
    }

    /// 선택을 바꾼다. 콘텐츠가 없는 트랙은 고를 수 없다 — 빈 목록을 보여줄 이유가 없다.
    public func select(_ languageID: LanguageID) {
        guard tracks.contains(where: { $0.languageID == languageID && $0.hasContent }) else {
            return
        }
        selection = languageID
    }

    // MARK: - 조립

    private func rows(
        for languageID: LanguageID,
        progress: [LessonRef: LessonProgress]
    ) -> [LessonRow] {
        guard let directory = lessonDirectory?(languageID) else { return [] }
        return directory.enumerated().map { offset, ref in
            let metadata = lessonMetadata?(ref.packID, ref.lessonID)
            let record = progress[ref]
            return LessonRow(
                ref: ref,
                ordinal: metadata?.ordinal ?? offset + 1,
                title: metadata?.title ?? ref.lessonID.rawValue,
                status: record?.status ?? .notStarted,
                completedBlocks: record?.completedBlocks.count ?? 0,
                blockIndex: min(
                    record?.currentBlockIndex ?? 0, LessonBlockSequence.count - 1)
            )
        }
    }

    /// `nil` 이면 읽기 자체가 실패한 것이다. 대시보드와 같은 규칙 — 팩 하나라도 못 읽으면
    /// 전체가 실패다.
    private func progressByRef() async -> [LessonRef: LessonProgress]? {
        var merged: [LessonRef: LessonProgress] = [:]
        for packID in packIDs {
            guard let list = try? await progressStore.progressList(packID: packID) else {
                return nil
            }
            for record in list {
                merged[LessonRef(packID: record.packID, lessonID: record.lessonID)] = record
            }
        }
        return merged
    }
}
