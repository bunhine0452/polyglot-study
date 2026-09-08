import Foundation
import Testing

@testable import ContentKit

/// 장면 셋 각각을 프로그램적으로 만들 때 쓰는 최소 건강한 값. 검증 테스트는 한
/// 지점씩만 망가뜨린다 — ``PackManifestTests`` 와 같은 이유로, "이 에러가 이
/// 결함 때문"이라는 대응이 흔들리지 않게 하기 위해서다.
private func healthyArrayVisual() throws -> ArrayVisual {
    try ArrayVisual(
        values: [1, 3, 5, 7, 9],
        frames: [
            ArrayFrame(
                caption: "탐색 시작 — lo=0, hi=4",
                pointers: [ArrayPointer(name: "lo", index: 0), ArrayPointer(name: "hi", index: 4)]),
            ArrayFrame(
                caption: "왼쪽 절반을 제외한다",
                pointers: [ArrayPointer(name: "mid", index: 2)],
                segments: [ArraySegment(role: .excluded, start: 0, end: 1)]),
        ])
}

private func healthyGraphVisual() throws -> GraphVisual {
    try GraphVisual(
        nodes: [
            GraphNode(id: "a", label: "A", x: 0, y: 0),
            GraphNode(id: "b", label: "B", x: 1, y: 0),
            GraphNode(id: "c", label: "C", x: 2, y: 0),
        ],
        edges: [
            GraphEdge(from: "a", to: "b"),
            GraphEdge(from: "b", to: "c"),
        ],
        frames: [
            GraphFrame(
                caption: "A 에서 시작한다",
                nodeStates: [
                    GraphNodeState(id: "a", role: .current), GraphNodeState(id: "b", role: .frontier),
                ]),
            GraphFrame(
                caption: "B 를 방문한다",
                nodeStates: [
                    GraphNodeState(id: "a", role: .visited), GraphNodeState(id: "b", role: .current),
                ],
                edgeStates: [GraphEdgeState(from: "a", to: "b", role: .settled)],
                distances: [GraphNodeDistance(id: "b", value: 1)]),
        ])
}

private func healthyTableVisual() throws -> TableVisual {
    try TableVisual(
        rowHeaders: ["item0", "item1"],
        columnHeaders: ["w0", "w1", "w2"],
        frames: [
            TableFrame(caption: "무게 0 열은 항상 0", cells: [TableCell(row: 0, column: 0, value: 0, role: .base)]),
            TableFrame(
                caption: "1번 품목까지, 위 칸을 참조해 채운다",
                cells: [
                    TableCell(row: 0, column: 0, value: 0, role: .filled),
                    TableCell(
                        row: 1, column: 0, value: 0, role: .current,
                        from: [TableCellRef(row: 0, column: 0)]),
                ]),
        ])
}

/// 클로저가 던진 에러를 ``VisualFrameSetError`` 로 좁혀 돌려준다. 다른 타입의 에러가
/// 나오면 그 자체가 버그이므로 테스트를 실패시킨다.
private func captured(_ body: () throws -> Void) -> VisualFrameSetError? {
    do {
        try body()
        return nil
    } catch let error as VisualFrameSetError {
        return error
    } catch {
        Issue.record("VisualFrameSetError 가 아닌 에러가 나왔다: \(error)")
        return nil
    }
}

// MARK: - 배열 장면

@Suite("ArrayVisual 검증 — 깨진 방식마다 다른 에러")
struct ArrayVisualValidationTests {
    @Test("건강한 배열 시각화는 통과한다")
    func healthyPasses() throws {
        _ = try healthyArrayVisual()
    }

    @Test("프레임이 0개면 실패한다")
    func noFrames() {
        #expect(captured { _ = try ArrayVisual(values: [1, 2, 3], frames: []) } == .noFrames)
    }

    @Test("자막이 빈 문자열이면 실패한다")
    func emptyCaption() {
        let error = captured {
            _ = try ArrayVisual(values: [1, 2, 3], frames: [ArrayFrame(caption: "")])
        }
        #expect(error == .emptyCaption(frameIndex: 0))
    }

    @Test("포인터 인덱스가 배열 범위 밖이면 실패한다")
    func pointerOutOfRange() {
        let error = captured {
            _ = try ArrayVisual(
                values: [1, 2, 3],
                frames: [ArrayFrame(caption: "x", pointers: [ArrayPointer(name: "hi", index: 9)])])
        }
        #expect(error == .arrayIndexOutOfRange(frameIndex: 0, pointer: "hi", index: 9, count: 3))
    }

    @Test("구간이 뒤집혀 있으면(start > end) 실패한다")
    func invertedSegment() {
        let error = captured {
            _ = try ArrayVisual(
                values: [1, 2, 3, 4, 5],
                frames: [
                    ArrayFrame(
                        caption: "x", segments: [ArraySegment(role: .highlighted, start: 3, end: 1)])
                ])
        }
        #expect(error == .arraySegmentOutOfRange(frameIndex: 0, start: 3, end: 1, count: 5))
    }

    @Test("구간 끝이 배열 범위 밖이면 실패한다")
    func segmentOutOfRange() {
        let error = captured {
            _ = try ArrayVisual(
                values: [1, 2, 3, 4, 5],
                frames: [
                    ArrayFrame(
                        caption: "x", segments: [ArraySegment(role: .highlighted, start: 0, end: 5)])
                ])
        }
        #expect(error == .arraySegmentOutOfRange(frameIndex: 0, start: 0, end: 5, count: 5))
    }
}

// MARK: - 그래프 장면

@Suite("GraphVisual 검증 — 깨진 방식마다 다른 에러")
struct GraphVisualValidationTests {
    @Test("건강한 그래프 시각화는 통과한다 — 트리도 좌표 붙은 그래프일 뿐이다")
    func healthyPasses() throws {
        _ = try healthyGraphVisual()
    }

    @Test("같은 노드 id 가 두 번 선언되면 실패한다")
    func duplicateNodeID() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [
                    GraphNode(id: "a", label: "A", x: 0, y: 0),
                    GraphNode(id: "a", label: "A2", x: 1, y: 1),
                ],
                edges: [],
                frames: [GraphFrame(caption: "x")])
        }
        #expect(error == .duplicateNodeID("a"))
    }

    @Test("정적 간선이 선언되지 않은 노드를 가리키면 실패한다")
    func staticEdgeUnknownNode() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0)],
                edges: [GraphEdge(from: "a", to: "ghost")],
                frames: [GraphFrame(caption: "x")])
        }
        #expect(error == .staticEdgeUnknownNode(from: "a", to: "ghost"))
    }

    @Test("프레임이 없는 노드 id 를 가리키면 실패한다")
    func unknownNodeInFrame() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0)],
                edges: [],
                frames: [GraphFrame(caption: "x", nodeStates: [GraphNodeState(id: "ghost", role: .visited)])])
        }
        #expect(error == .unknownNode(frameIndex: 0, nodeID: "ghost"))
    }

    @Test("거리 값이 없는 노드 id 를 가리켜도 같은 에러로 실패한다")
    func unknownNodeInDistance() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0)],
                edges: [],
                frames: [GraphFrame(caption: "x", distances: [GraphNodeDistance(id: "ghost", value: 1)])])
        }
        #expect(error == .unknownNode(frameIndex: 0, nodeID: "ghost"))
    }

    @Test("프레임이 정적 간선 목록에 없는 간선을 가리키면 실패한다")
    func unknownEdgeInFrame() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0), GraphNode(id: "b", label: "B", x: 1, y: 0)],
                edges: [],
                frames: [
                    GraphFrame(caption: "x", edgeStates: [GraphEdgeState(from: "a", to: "b", role: .settled)])
                ])
        }
        #expect(error == .unknownEdge(frameIndex: 0, from: "a", to: "b"))
    }

    @Test("무방향 간선은 프레임이 반대 방향으로 참조해도 통과한다")
    func undirectedEdgeIgnoresOrder() throws {
        _ = try GraphVisual(
            nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0), GraphNode(id: "b", label: "B", x: 1, y: 0)],
            edges: [GraphEdge(from: "a", to: "b", directed: false)],
            frames: [
                GraphFrame(caption: "x", edgeStates: [GraphEdgeState(from: "b", to: "a", role: .settled)])
            ])
    }

    @Test("방향 간선은 반대 방향 참조를 거부한다")
    func directedEdgeRejectsReversedOrder() {
        let error = captured {
            _ = try GraphVisual(
                nodes: [GraphNode(id: "a", label: "A", x: 0, y: 0), GraphNode(id: "b", label: "B", x: 1, y: 0)],
                edges: [GraphEdge(from: "a", to: "b", directed: true)],
                frames: [
                    GraphFrame(caption: "x", edgeStates: [GraphEdgeState(from: "b", to: "a", role: .settled)])
                ])
        }
        #expect(error == .unknownEdge(frameIndex: 0, from: "b", to: "a"))
    }
}

// MARK: - 표 장면

@Suite("TableVisual 검증 — 깨진 방식마다 다른 에러")
struct TableVisualValidationTests {
    @Test("건강한 표 시각화는 통과한다")
    func healthyPasses() throws {
        _ = try healthyTableVisual()
    }

    @Test("행·열 머리글이 비어 있으면 실패한다")
    func emptyTable() {
        let error = captured {
            _ = try TableVisual(rowHeaders: [], columnHeaders: ["w0"], frames: [TableFrame(caption: "x")])
        }
        #expect(error == .emptyTable)
    }

    @Test("채워진 칸이 표 범위 밖이면 실패한다")
    func cellOutOfBounds() {
        let error = captured {
            _ = try TableVisual(
                rowHeaders: ["r0"], columnHeaders: ["c0"],
                frames: [TableFrame(caption: "x", cells: [TableCell(row: 5, column: 0, value: 1, role: .base)])])
        }
        #expect(error == .cellOutOfBounds(frameIndex: 0, row: 5, column: 0, rows: 1, columns: 1))
    }

    @Test("참조 칸(from)이 표 범위 밖이면 실패한다")
    func referenceCellOutOfBounds() {
        let error = captured {
            _ = try TableVisual(
                rowHeaders: ["r0", "r1"], columnHeaders: ["c0"],
                frames: [
                    TableFrame(
                        caption: "x",
                        cells: [
                            TableCell(
                                row: 1, column: 0, value: 1, role: .current,
                                from: [TableCellRef(row: 9, column: 0)])
                        ])
                ])
        }
        #expect(error == .cellOutOfBounds(frameIndex: 0, row: 9, column: 0, rows: 2, columns: 1))
    }
}


/// 아웃라인의 배열 계열 12편 중 5편이 정렬이다 — 값이 자리를 바꾸는 것이 그 레슨의
/// 핵심이라, 프레임이 자기 배열을 실을 수 있어야 한다.
@Suite("배열 장면 — 값이 움직이는 정렬")
struct ArrayVisualSwapTests {
    @Test("프레임이 자기 배열을 실으면 그 시점의 값이 된다")
    func framesCarryTheirOwnValues() throws {
        let visual = try ArrayVisual(
            values: [5, 2, 9],
            frames: [
                ArrayFrame(caption: "시작 — 아직 정렬 전이다"),
                ArrayFrame(
                    caption: "5 와 2 를 맞바꾼다",
                    values: [2, 5, 9],
                    segments: [ArraySegment(role: .highlighted, start: 0, end: 1)]),
            ])

        // 값을 안 실은 프레임은 시작 배열 그대로다 — 훑기 시각화가 장황해지지 않는 이유.
        #expect(visual.values(at: 0) == [5, 2, 9])
        #expect(visual.values(at: 1) == [2, 5, 9])
    }

    @Test("프레임 배열의 길이가 다르면 throw — 정렬은 자리바꿈이지 크기 변경이 아니다")
    func lengthMismatchThrows() throws {
        #expect(throws: VisualFrameSetError.self) {
            try ArrayVisual(
                values: [5, 2, 9],
                frames: [ArrayFrame(caption: "원소가 하나 늘었다", values: [2, 5, 9, 11])])
        }
    }

    @Test("값을 안 실은 프레임은 JSON 에 values 키를 남기지 않는다")
    func omittedValuesStayOmitted() throws {
        let data = try JSONEncoder().encode(ArrayFrame(caption: "훑는 중"))
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("values"))
    }
}
