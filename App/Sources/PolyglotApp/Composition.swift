internal import ContentKit
internal import DashboardFeature
internal import Foundation
internal import LearnCore
internal import LearnPersistence
internal import LessonFeature
internal import OnboardingFeature
internal import ReviewFeature

/// 앱의 **유일한** 조립 지점. 구체 타입을 아는 곳이 여기 하나뿐이라야
/// 화면들이 서로를 모른 채로 남는다.
///
/// 실패를 삼키지 않는다 — DB 를 못 열거나 팩을 못 읽으면 그 사실이 화면에 남아야 한다.
/// 조용히 빈 화면을 보여주면 "아직 아무것도 안 함" 과 구별되지 않는다.
@MainActor
final class Composition {
    enum PackState {
        case ready(ContentPack)
        case failed(String)
    }

    let database: Result<LearnDatabase, any Error>
    let pack: PackState

    let onboarding = OnboardingModel()
    private(set) lazy var dashboard: DashboardModel = makeDashboard()

    init() {
        database = Result { try LearnDatabase.open() }
        pack = Self.loadPack()
    }

    // MARK: - 콘텐츠 팩

    /// 개발 중에는 저장소의 `Content/packs/` 를, 배포본에서는 앱 번들 Resources 를 본다.
    /// `POLYGLOT_PACK_PATH` 로 덮을 수 있다.
    private static func loadPack() -> PackState {
        for url in packCandidates() {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                return .ready(try ContentPack(directory: url))
            } catch {
                return .failed("팩을 읽지 못했습니다 — \(url.lastPathComponent): \(error)")
            }
        }
        return .failed("콘텐츠 팩을 찾지 못했습니다. POLYGLOT_PACK_PATH 로 경로를 지정하십시오.")
    }

    private static func packCandidates() -> [URL] {
        var urls: [URL] = []
        if let override = ProcessInfo.processInfo.environment["POLYGLOT_PACK_PATH"], !override.isEmpty {
            urls.append(URL(fileURLWithPath: override))
        }
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("Content/packs/polyglot-mvp", isDirectory: true) {
            urls.append(bundled)
        }
        // 개발 실행 — 번들이 `App/.build/...` 안에 있으므로 저장소 루트로 거슬러 올라간다.
        var probe = Bundle.main.bundleURL
        for _ in 0..<8 {
            probe.deleteLastPathComponent()
            urls.append(probe.appendingPathComponent("Content/packs/polyglot-mvp", isDirectory: true))
        }
        return urls
    }

    // MARK: - 화면 조립

    private func makeDashboard() -> DashboardModel {
        // DB 를 못 열었으면 인메모리 페이크로 떨어진다. 화면이 죽는 것보다 낫고,
        // 실패 사실은 `databaseFailureNotice` 가 따로 알린다.
        guard case .success(let db) = database else { return DashboardModel() }
        return DashboardModel(
            progressStore: db.lessonProgressStore,
            cardStateStore: db.cardStateStore,
            reviewLogStore: db.reviewLogStore,
            lessonMetadata: packLessonMetadata(),
            lessonDirectory: packLessonDirectory()
        )
    }

    func makeReview() throws -> ReviewModel {
        guard case .success(let db) = database else {
            throw CompositionError.databaseUnavailable
        }
        return try ReviewModel.live(database: db)
    }

    func makeLesson(lessonID: LessonID) throws -> LessonModel {
        guard case .ready(let pack) = pack else { throw CompositionError.packUnavailable }
        return try LessonModel(pack: pack, lessonID: lessonID)
    }

    var databaseFailureNotice: String? {
        guard case .failure(let error) = database else { return nil }
        return "저장소를 열지 못했습니다 — 진도가 기록되지 않습니다: \(error)"
    }

    var packFailureNotice: String? {
        guard case .failed(let reason) = pack else { return nil }
        return reason
    }

    // MARK: - 팩에서 나오는 메타데이터

    /// 대시보드가 레슨 번호·제목을 팩에서 읽게 한다. 팩이 없으면 `nil` 을 돌려주고,
    /// 대시보드는 "제목 모름" 으로 정직하게 그린다.
    private func packLessonMetadata() -> (@Sendable (PackID, LessonID) -> DashboardModel.LessonMetadata?)? {
        guard case .ready(let pack) = pack else { return nil }
        // 사전으로 굳혀 넘긴다 — 클로저가 매 호출마다 배열을 훑으면 표 10행에서 반복된다.
        let byID = Dictionary(
            pack.manifest.lessons.map { ($0.stableID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return { _, lessonID in
            guard let entry = byID[lessonID] else { return nil }
            return DashboardModel.LessonMetadata(ordinal: entry.order, title: entry.title)
        }
    }

    private func packLessonDirectory() -> (@Sendable (LanguageID) -> [LessonID])? {
        guard case .ready(let pack) = pack else { return nil }
        // 언어별로 order 순 정렬해 굳힌다. 팩이 여러 언어를 담을 수 있으므로 그룹핑한다.
        let byLanguage = Dictionary(grouping: pack.manifest.lessons, by: \.language)
            .mapValues { $0.sorted { $0.order < $1.order }.map(\.stableID) }
        return { byLanguage[$0] ?? [] }
    }
}

enum CompositionError: Error, CustomStringConvertible {
    case databaseUnavailable
    case packUnavailable

    var description: String {
        switch self {
        case .databaseUnavailable: "저장소를 열지 못해 이 화면을 열 수 없습니다."
        case .packUnavailable: "콘텐츠 팩이 없어 이 화면을 열 수 없습니다."
        }
    }
}
