import ContentKit
import Foundation
import SwiftUI
import Testing

@testable import DesignSystem
@testable import LessonFeature

/// ``ContentKit`` 의 정본 모델 조립에 쓰는 고정 값들. 생성자가 검증을 하므로 throws 다.
/// `design/AlgorithmLesson.dc.html` 의 이진 탐색 예시(배열 `[2,5,8,12,16,23,38,56,72,91]`,
/// target `16`)를 그대로 옮긴다.
private enum VisualFixture {
    static func binarySearch() throws -> ArrayVisual {
        try ArrayVisual(
            values: [2, 5, 8, 12, 16, 23, 38, 56, 72, 91],
            frames: [
                ArrayFrame(
                    caption: "lo = 0, hi = 9 에서 탐색을 시작합니다.",
                    pointers: [ArrayPointer(name: "lo", index: 0), ArrayPointer(name: "hi", index: 9)]
                ),
                ArrayFrame(
                    caption: "xs[2] = 8 은 16보다 작습니다. 왼쪽 절반에는 답이 없으니 버리고 lo 를 3으로 옮깁니다.",
                    pointers: [
                        ArrayPointer(name: "lo", index: 0), ArrayPointer(name: "mid", index: 2),
                        ArrayPointer(name: "hi", index: 5),
                    ],
                    segments: [
                        ArraySegment(role: .highlighted, start: 2, end: 2),
                        ArraySegment(role: .excluded, start: 5, end: 9),
                    ]
                ),
                ArrayFrame(
                    caption: "xs[4] = 16 을 찾았습니다.",
                    pointers: [ArrayPointer(name: "mid", index: 4)],
                    segments: [
                        ArraySegment(role: .highlighted, start: 4, end: 4),
                        ArraySegment(role: .excluded, start: 0, end: 2),
                        ArraySegment(role: .excluded, start: 5, end: 9),
                    ]
                ),
            ])
    }

    static func bfs() throws -> GraphVisual {
        let nodes = [
            GraphNode(id: "A", label: "A", x: 0, y: 0),
            GraphNode(id: "B", label: "B", x: 1, y: 0),
            GraphNode(id: "C", label: "C", x: 2, y: 0),
            GraphNode(id: "D", label: "D", x: 1, y: 1),
        ]
        let edges = [
            GraphEdge(from: "A", to: "B"),
            GraphEdge(from: "B", to: "C"),
            GraphEdge(from: "A", to: "D", weight: 4),
        ]
        return try GraphVisual(
            nodes: nodes, edges: edges,
            frames: [
                GraphFrame(
                    caption: "A 에서 시작합니다.",
                    nodeStates: [GraphNodeState(id: "A", role: .current)],
                    distances: [GraphNodeDistance(id: "A", value: 0)]
                ),
                GraphFrame(
                    caption: "B 를 frontier 에 넣습니다.",
                    nodeStates: [
                        GraphNodeState(id: "A", role: .visited),
                        GraphNodeState(id: "B", role: .frontier),
                    ],
                    edgeStates: [GraphEdgeState(from: "A", to: "B", role: .current)],
                    distances: [GraphNodeDistance(id: "A", value: 0), GraphNodeDistance(id: "B", value: 1)]
                ),
                GraphFrame(
                    caption: "B 를 확정합니다.",
                    nodeStates: [
                        GraphNodeState(id: "A", role: .settled),
                        GraphNodeState(id: "B", role: .settled),
                    ],
                    edgeStates: [GraphEdgeState(from: "A", to: "B", role: .settled)]
                ),
            ])
    }

    static func knapsack() throws -> TableVisual {
        try TableVisual(
            rowHeaders: ["0", "1", "2"],
            columnHeaders: ["0", "1"],
            frames: [
                TableFrame(caption: "기저 칸을 채웁니다.", cells: [
                    TableCell(row: 0, column: 0, value: 0, role: .base)
                ]),
                TableFrame(
                    caption: "(1,0) 은 (0,0) 을 보고 채워집니다.",
                    cells: [
                        TableCell(row: 0, column: 0, value: 0, role: .filled),
                        TableCell(
                            row: 1, column: 0, value: 5, role: .current,
                            from: [TableCellRef(row: 0, column: 0)]),
                    ]),
            ])
    }
}

@Suite("시각화 재생기 · 그림자 모델")
struct VisualPlayerModelTests {
    @Test("프레임이 자기 값을 안 실었으면 시작 배열이 그대로 나온다")
    func arrayValuesFallBackToStart() throws {
        let visual = try VisualFixture.binarySearch()
        #expect(visual.values(at: 0) == visual.values)
        #expect(visual.values(at: 1) == visual.values)
    }

    @Test("프레임이 자기 값을 실었으면 그것이 나온다")
    func arrayValuesUseFrameOverride() throws {
        let visual = try ArrayVisual(
            values: [3, 1, 2],
            frames: [
                ArrayFrame(caption: "정렬 전"),
                ArrayFrame(caption: "한 번 스왑", values: [1, 3, 2]),
            ])
        #expect(visual.values(at: 0) == [3, 1, 2])
        #expect(visual.values(at: 1) == [1, 3, 2])
    }

    @Test("범위 밖 프레임 인덱스는 시작 배열로 떨어진다")
    func arrayValuesOutOfRangeFallsBack() throws {
        let visual = try VisualFixture.binarySearch()
        #expect(visual.values(at: 99) == visual.values)
    }

    @Test("장면의 frameCount 는 각 장면의 frames.count 다")
    func sceneFrameCount() throws {
        #expect(VisualScene.array(try VisualFixture.binarySearch()).frameCount == 3)
        #expect(VisualScene.graph(try VisualFixture.bfs()).frameCount == 3)
        #expect(VisualScene.table(try VisualFixture.knapsack()).frameCount == 2)
    }

    @Test("장면의 caption(at:) 이 세 장면 다 같은 자리에서 자막을 꺼낸다")
    func sceneCaption() throws {
        let array = VisualScene.array(try VisualFixture.binarySearch())
        #expect(array.caption(at: 2) == "xs[4] = 16 을 찾았습니다.")

        let graph = VisualScene.graph(try VisualFixture.bfs())
        #expect(graph.caption(at: 0) == "A 에서 시작합니다.")

        let table = VisualScene.table(try VisualFixture.knapsack())
        #expect(table.caption(at: 1) == "(1,0) 은 (0,0) 을 보고 채워집니다.")
    }

    @Test("kind 가 케이스와 일치한다")
    func sceneKind() throws {
        #expect(VisualScene.array(try VisualFixture.binarySearch()).kind == .array)
        #expect(VisualScene.graph(try VisualFixture.bfs()).kind == .graph)
        #expect(VisualScene.table(try VisualFixture.knapsack()).kind == .table)
    }
}

/// 뷰 계층이 실제로 조립돼 비트맵까지 가는지만 본다 — 픽셀 색은 단언하지 않는다.
/// `DashboardRenderTests` 와 같은 관용구다.
@Suite("시각화 재생기 · 렌더 조립")
struct VisualPlayerRenderTests {
    @Test("배열 장면이 비트맵까지 렌더된다")
    func arraySceneRenders() throws {
        let view = ArraySceneView(visual: try VisualFixture.binarySearch(), frameIndex: 1)
        let renderer = ImageRenderer(content: view.frame(width: 460, height: 100))
        let image = try #require(renderer.nsImage)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("그래프 장면이 비트맵까지 렌더된다")
    func graphSceneRenders() throws {
        let view = GraphSceneView(visual: try VisualFixture.bfs(), frameIndex: 1)
        let renderer = ImageRenderer(content: view.frame(width: 460, height: 220))
        #expect(renderer.nsImage != nil)
    }

    @Test("표 장면이 비트맵까지 렌더된다")
    func tableSceneRenders() throws {
        let view = TableSceneView(visual: try VisualFixture.knapsack(), frameIndex: 1)
        let renderer = ImageRenderer(content: view.frame(width: 200, height: 140))
        #expect(renderer.nsImage != nil)
    }

    @Test("재생기 전체가 세 장면 다 비트맵까지 렌더된다")
    func playerRendersAllSceneKinds() throws {
        let scenes: [(String, VisualScene)] = [
            ("array", .array(try VisualFixture.binarySearch())),
            ("graph", .graph(try VisualFixture.bfs())),
            ("table", .table(try VisualFixture.knapsack())),
        ]
        for (id, scene) in scenes {
            let frameSet = try VisualFrameSet(id: id, scene: scene)
            let view = VisualPlayerView(frameSet)
            let renderer = ImageRenderer(content: view.frame(width: 460, height: 420))
            let image = try #require(renderer.nsImage, "\(id) 장면이 렌더되지 않았다")
            #expect(image.size.width > 0)
        }
    }

    @Test("빈 자막이 없는 배열 픽스처는 매 프레임에서 caption 이 비지 않는다")
    func captionsAreNeverEmpty() throws {
        let visual = try VisualFixture.binarySearch()
        for index in visual.frames.indices {
            #expect(!visual.frames[index].caption.isEmpty)
        }
    }
}

/// 키보드만으로 프레임을 앞뒤로 옮길 수 있어야 한다는 것이 이 기능의 완료 기준이다.
/// 이 저장소에 실제 `NSApplication` 이벤트 루프를 태워 키 입력을 흉내 내는 관용구가 없어서
/// (헤드리스 `swift test` 에는 창이 없다), `PrimitivesSealingTests` 가 금지 API를 검증하는
/// 것과 같은 방식으로 — 소스에 필요한 `.keyboardShortcut` 호출이 실제로 있는지 본다.
@Suite("시각화 재생기 · 키보드 이동")
struct VisualPlayerKeyboardShortcutTests {
    static var sourceText: String {
        get throws {
            let path = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // .../Tests/DesignSystemTests
                .deletingLastPathComponent()  // .../Tests
                .deletingLastPathComponent()  // .../LearnKit
                .appendingPathComponent("Sources/Features/LessonFeature/Visualization/VisualPlayerView.swift")
            return try String(contentsOf: path, encoding: .utf8)
        }
    }

    @Test("좌우 화살표가 이전/다음에 붙어 있다")
    func arrowKeysStepFrames() throws {
        let source = try Self.sourceText
        #expect(source.contains(".keyboardShortcut(.leftArrow"))
        #expect(source.contains(".keyboardShortcut(.rightArrow"))
    }

    @Test("Home/End 가 처음/끝에 붙어 있다")
    func homeEndJumpToBounds() throws {
        let source = try Self.sourceText
        #expect(source.contains(".keyboardShortcut(.home"))
        #expect(source.contains(".keyboardShortcut(.end"))
    }

    @Test("스페이스가 재생/일시정지에 붙어 있다")
    func spaceTogglesPlayback() throws {
        let source = try Self.sourceText
        #expect(source.contains(".keyboardShortcut(.space"))
    }
}
