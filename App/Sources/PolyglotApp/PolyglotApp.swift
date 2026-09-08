internal import Foundation
internal import DashboardFeature
internal import ContentKit
internal import DesignSystem
internal import EditorFeature
internal import LearnCore
internal import LessonFeature
internal import OnboardingFeature
internal import ReviewFeature
internal import SwiftUI

/// 앱 타깃의 **유일한** 컴파일 소스. 화면은 전부 LearnKit 안에 있고 여기서는 셸만 세운다.
@main
struct PolyglotApp: App {
    @State private var selection: ShellDestination = Self.initialDestination

    /// 디버그용 시작 목적지. 스냅샷으로 특정 화면을 굽거나, 개발 중 매번 클릭하지 않기 위해.
    /// 값이 없거나 이상하면 조용히 `.today` 로 떨어진다 — 릴리스 동작에 영향을 주지 않는다.
    private static var initialDestination: ShellDestination {
        ProcessInfo.processInfo.environment["POLYGLOT_START_DESTINATION"]
            .flatMap(ShellDestination.init(rawValue:)) ?? .today
    }

    init() {
        // 화면이 그려지기 전에 — AppFont.resolvedSans/resolvedMono 는 첫 접근 시 1회
        // 평가되는 static let 이라, 그보다만 먼저면 된다. {#plex-font-bundling}
        FontRegistration.registerBundledFonts()
        Snapshot.captureAndTerminateIfRequested()
    }

    var body: some Scene {
        WindowGroup("Polyglot") {
            RootView(selection: $selection)
        }
        // 아트보드 실측 1440×900.
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        // 시스템 크롬(신호등·타이틀바·메뉴바)은 OS 가 그린다. 숨기면 신호등이 사이드바
        // 브랜드 블록 위로 겹친다 — 디자인에 그 자리가 없다.
        .commands { UpdatesCommands() }
    }
}

private struct RootView: View {
    @Binding var selection: ShellDestination

    /// 조립은 한 번만. 툴체인 감지는 서브프로세스를 10번 띄우고 DB·팩도 여기서 한 번 연다.
    @State private var composition = Composition()
    /// 레슨은 사이드바 목적지가 아니라 대시보드에서 밀려 들어온다.
    @State private var openLesson: OpenLesson?
    /// 에디터는 레슨의 과제 블록에서 밀려 들어온다. 닫으면 그 레슨으로 돌아간다.
    @State private var openEditor: EditorModel?
    @State private var screenError: String?

    var body: some View {
        AppShell(selection: $selection, badge: badge) { destination in
            ShellContent {
                ShellHeader(destination.title, trailing: Self.today)
                notices
                content(for: destination)
            }
        }
        .frame(minWidth: 1040, minHeight: 680)
        // 업데이트 프로브({#sparkle-updates} 검증). 환경 변수가 없으면 즉시 반환한다.
        // App.init() 이 아니라 여기인 이유: SPUUpdater 는 실행 루프를 요구한다.
        .task { SparkleProbe.startIfRequested() }
        .task { openStartLessonIfRequested() }
    }

    /// 아직 데이터 계층이 셸에 붙지 않았다. 배지가 붙을 자리만 비워 둔다 —
    /// 화면이 생기면 여기서 실제 카운트를 넘긴다.
    @ViewBuilder
    private func content(for destination: ShellDestination) -> some View {
        if let editor = openEditor {
            // 에디터는 레슨 위에 얹힌다 — 뒤로 가면 열려 있던 레슨이 그대로 남아 있다.
            EditorView(model: editor) { openEditor = nil }
        } else if let lesson = openLesson {
            LessonView(model: lesson.model) { openLesson = nil }
        } else {
            switch destination {
            case .today:
                DashboardView(
                    model: composition.dashboard,
                    onResume: { open($0.ref) },
                    onOpenTrack: openTrack
                )
            case .tracks:
                TracksView(model: composition.tracks, onOpen: open)
            case .review:
                reviewScreen
            case .scratch:
                // 채점이 없는 자유 실행 화면. 레슨의 에디터와 같은 실행기를 타지만
                // 숨은 테스트도 제출도 없다.
                ScratchView(model: composition.scratch)
            case .toolchain:
                // 목 데이터가 아니라 RunnerKit 의 ToolchainProbe 가 이 머신을 실제로 훑은 결과.
                OnboardingView(model: composition.onboarding)
            }
        }
    }

    /// 복습 모델은 DB 를 요구하므로 조립이 실패할 수 있다. 실패를 빈 화면으로 숨기지 않는다.
    @ViewBuilder
    private var reviewScreen: some View {
        if let model = try? composition.makeReview() {
            ReviewView(model: model)
        } else {
            LabelText("복습을 열 수 없습니다 — 저장소를 확인하십시오.")
        }
    }

    /// 조립 실패는 화면 위에 남긴다. 조용히 비어 있으면 "아직 아무것도 안 함" 과 구별되지 않는다.
    @ViewBuilder
    private var notices: some View {
        let messages = [composition.databaseFailureNotice, composition.packFailureNotice, screenError]
            .compactMap { $0 }
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(messages, id: \.self) { MonoText($0, size: .label, color: Palette.fail) }
            }
        }
    }

    /// 레슨 하나를 연다. 대시보드의 "이어서" 와 트랙 화면의 목록이 같은 문으로 들어온다.
    private func open(_ ref: LessonRef) {
        do {
            let model = try composition.makeLesson(ref) { task in
                // 레슨 모델이 자기를 연 셸을 모르게 하려고 클로저로 되쏜다.
                // 열기에 실패하면 조용히 아무 일도 일어나지 않으면 안 된다 —
                // "에디터에서 열기" 를 눌렀는데 화면이 그대로면 앱이 고장 난 것처럼 보인다.
                openEditorScreen(ref: ref, task: task)
            }
            openLesson = OpenLesson(ref: ref, model: model)
            openEditor = nil
            screenError = nil
        } catch {
            screenError = "\(error)"
        }
    }

    /// 대시보드의 트랙 행을 눌렀다 — 트랙 화면으로 옮겨 그 트랙을 편다.
    private func openTrack(_ languageID: LanguageID) {
        composition.tracks.select(languageID)
        openLesson = nil
        openEditor = nil
        selection = .tracks
    }

    private func openEditorScreen(ref: LessonRef, task: TaskBlock) {
        guard let lesson = openLesson else { return }
        do {
            openEditor = try composition.makeEditor(ref, lesson: lesson.model, task: task)
            screenError = nil
        } catch {
            screenError = "\(error)"
        }
    }

    /// 디버그용 시작 레슨. `POLYGLOT_START_LESSON=<packID>/<lessonID>` 로 레슨을 열고,
    /// `POLYGLOT_START_EDITOR=1` 이면 그 레슨의 과제 블록까지 가서 에디터를 연다.
    ///
    /// `POLYGLOT_START_DESTINATION` 과 같은 자리의 장치다 — 스냅샷으로 특정 화면을 굽거나
    /// 개발 중 매번 클릭하지 않기 위해서다. 값이 이상하면 조용히 아무 일도 하지 않는다.
    private func openStartLessonIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let raw = environment["POLYGLOT_START_LESSON"], !raw.isEmpty else { return }
        let parts = raw.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else {
            screenError = "POLYGLOT_START_LESSON 은 <packID>/<lessonID> 형식이어야 합니다: \(raw)"
            return
        }
        open(LessonRef(packID: PackID(String(parts[0])), lessonID: LessonID(String(parts[1]))))
        guard environment["POLYGLOT_START_EDITOR"] == "1", let lesson = openLesson else { return }
        // 과제 블록까지 걸어간다 — `advance()` 는 한 칸씩만 움직인다(스텝바가 진도를 뜻한다).
        if let index = lesson.model.blocks.firstIndex(where: { $0.kind == .task }) {
            while lesson.model.activeIndex < index { lesson.model.advance() }
        }
        lesson.model.openEditor()
    }

    private func badge(for destination: ShellDestination) -> String? {
        // 지금 배지를 낼 수 있는 곳은 툴체인뿐이다 — 나머지는 화면 안에서 이미 보인다.
        guard destination == .toolchain else { return nil }
        let unresolved = composition.onboarding.summary.missing + composition.onboarding.summary.problem
        return unresolved > 0 ? String(unresolved) : nil
    }

    private static let today: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: Date())
    }()
}

/// 열려 있는 레슨과 그것이 온 팩. 에디터를 조립하려면 팩까지 알아야 한다.
private struct OpenLesson {
    let ref: LessonRef
    let model: LessonModel
}
