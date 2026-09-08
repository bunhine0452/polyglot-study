import Foundation
import Testing

@testable import ContentKit

/// 네 장면 계열(배열·그래프·표, 트리는 그래프로 표현)을 덮는 최소 건강한 사이드카 JSON.
/// `VisualFrameSetTests.swift` 의 프로그램적 검증과 달리, 여기서는 **JSON 문자열을
/// 그대로 디코딩**해 사이드카 저작자가 실제로 마주치는 경로(`JSONDecoder`)를 검증한다.
private let healthyArrayJSON = """
    {
      "schemaVersion": 1,
      "id": "binary-search-v1",
      "kind": "array",
      "values": [1, 3, 5, 7, 9, 11],
      "frames": [
        {
          "caption": "탐색 시작 — lo=0, hi=5",
          "pointers": [{"name": "lo", "index": 0}, {"name": "hi", "index": 5}],
          "segments": []
        },
        {
          "caption": "mid=2 의 값 5 는 목표(9)보다 작다 — 왼쪽 절반을 제외한다",
          "pointers": [
            {"name": "lo", "index": 3}, {"name": "mid", "index": 2}, {"name": "hi", "index": 5}
          ],
          "segments": [{"role": "excluded", "start": 0, "end": 2}]
        }
      ]
    }
    """

private let healthyGraphJSON = """
    {
      "schemaVersion": 1,
      "id": "bfs-v1",
      "kind": "graph",
      "nodes": [
        {"id": "a", "label": "A", "x": 0, "y": 0},
        {"id": "b", "label": "B", "x": 1, "y": 0},
        {"id": "c", "label": "C", "x": 2, "y": 0}
      ],
      "edges": [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}],
      "frames": [
        {
          "caption": "A 에서 시작한다",
          "nodeStates": [{"id": "a", "role": "current"}, {"id": "b", "role": "frontier"}],
          "edgeStates": [],
          "distances": []
        },
        {
          "caption": "B 를 방문하고 C 를 프론티어에 넣는다",
          "nodeStates": [
            {"id": "a", "role": "visited"}, {"id": "b", "role": "current"}, {"id": "c", "role": "frontier"}
          ],
          "edgeStates": [{"from": "a", "to": "b", "role": "settled"}],
          "distances": []
        }
      ]
    }
    """

private let healthyTableJSON = """
    {
      "schemaVersion": 1,
      "id": "knapsack-v1",
      "kind": "table",
      "rowHeaders": ["item0", "item1"],
      "columnHeaders": ["w0", "w1", "w2"],
      "frames": [
        {
          "caption": "0번 품목까지, 무게 0인 칸은 항상 0",
          "cells": [{"row": 0, "column": 0, "value": 0, "role": "base"}]
        },
        {
          "caption": "1번 품목까지, 위 칸을 참조해 채운다",
          "cells": [
            {"row": 0, "column": 0, "value": 0, "role": "filled"},
            {
              "row": 1, "column": 0, "value": 0, "role": "current",
              "from": [{"row": 0, "column": 0}]
            }
          ]
        }
      ]
    }
    """

private func decode(_ json: String) throws -> VisualFrameSet {
    try JSONDecoder().decode(VisualFrameSet.self, from: Data(json.utf8))
}

private func decodeError(_ json: String) -> VisualFrameSetError? {
    do {
        _ = try decode(json)
        return nil
    } catch let error as VisualFrameSetError {
        return error
    } catch {
        Issue.record("VisualFrameSetError 가 아닌 에러가 나왔다: \(error)")
        return nil
    }
}

@Suite("VisualFrameSet 디코딩 — 네 장면 표본이 각각 파싱된다")
struct VisualFrameSetDecodingTests {
    @Test("array 표본이 파싱되고 kind 가 array 다")
    func decodesArray() throws {
        let set = try decode(healthyArrayJSON)
        #expect(set.id == "binary-search-v1")
        #expect(set.scene.kind == .array)
        guard case .array(let visual) = set.scene else {
            Issue.record("array 로 디코딩되지 않았다")
            return
        }
        #expect(visual.values == [1, 3, 5, 7, 9, 11])
        #expect(visual.frames.count == 2)
    }

    @Test("graph 표본이 파싱되고 kind 가 graph 다 — 트리와 같은 표현이다")
    func decodesGraph() throws {
        let set = try decode(healthyGraphJSON)
        #expect(set.scene.kind == .graph)
        guard case .graph(let visual) = set.scene else {
            Issue.record("graph 로 디코딩되지 않았다")
            return
        }
        #expect(visual.nodes.count == 3)
        #expect(visual.edges.count == 2)
    }

    @Test("table 표본이 파싱되고 kind 가 table 이다")
    func decodesTable() throws {
        let set = try decode(healthyTableJSON)
        #expect(set.scene.kind == .table)
        guard case .table(let visual) = set.scene else {
            Issue.record("table 로 디코딩되지 않았다")
            return
        }
        #expect(visual.rowCount == 2)
        #expect(visual.columnCount == 3)
    }

    @Test("인코딩 뒤 다시 디코딩해도 같은 값이다 — 왕복이 안전하다")
    func roundTrips() throws {
        let original = try decode(healthyGraphJSON)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VisualFrameSet.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("VisualFrameSet 디코딩 — 다섯 결함이 서로 다른 에러로 실패한다")
struct VisualFrameSetBrokenInputTests {
    @Test("1. 프레임이 0개면 디코딩이 실패한다")
    func noFrames() {
        let error = decodeError(
            """
            {"schemaVersion": 1, "id": "empty-v1", "kind": "array", "values": [1, 2, 3], "frames": []}
            """)
        #expect(error == .noFrames)
    }

    @Test("2. 자막이 빈 문자열이면 디코딩이 실패한다")
    func emptyCaption() {
        let error = decodeError(
            """
            {
              "schemaVersion": 1, "id": "blank-caption-v1", "kind": "array",
              "values": [1, 2, 3],
              "frames": [{"caption": "", "pointers": [], "segments": []}]
            }
            """)
        #expect(error == .emptyCaption(frameIndex: 0))
    }

    @Test("3. 포인터가 정적 배열 범위 밖을 가리키면 디코딩이 실패한다")
    func indexOutOfRange() {
        let error = decodeError(
            """
            {
              "schemaVersion": 1, "id": "oob-v1", "kind": "array",
              "values": [1, 2, 3],
              "frames": [
                {"caption": "x", "pointers": [{"name": "hi", "index": 99}], "segments": []}
              ]
            }
            """)
        #expect(error == .arrayIndexOutOfRange(frameIndex: 0, pointer: "hi", index: 99, count: 3))
    }

    @Test("4. 프레임이 없는 노드 id 를 가리키면 디코딩이 실패한다")
    func unknownNodeID() {
        let error = decodeError(
            """
            {
              "schemaVersion": 1, "id": "ghost-node-v1", "kind": "graph",
              "nodes": [{"id": "a", "label": "A", "x": 0, "y": 0}],
              "edges": [],
              "frames": [
                {
                  "caption": "x",
                  "nodeStates": [{"id": "ghost", "role": "visited"}],
                  "edgeStates": [], "distances": []
                }
              ]
            }
            """)
        #expect(error == .unknownNode(frameIndex: 0, nodeID: "ghost"))
    }

    @Test("5. kind 가 array·graph·table 이 아니면 디코딩이 실패한다")
    func unknownKind() {
        let error = decodeError(
            """
            {"schemaVersion": 1, "id": "mystery-v1", "kind": "tree", "frames": []}
            """)
        #expect(error == .unknownKind("tree"))
    }

    @Test("다섯 결함이 서로 다른 에러이고 서로 다른 설명 문구를 낸다")
    func allFiveAreDistinct() {
        let errors = [
            decodeError(
                """
                {"schemaVersion": 1, "id": "e1", "kind": "array", "values": [1], "frames": []}
                """),
            decodeError(
                """
                {
                  "schemaVersion": 1, "id": "e2", "kind": "array", "values": [1],
                  "frames": [{"caption": "", "pointers": [], "segments": []}]
                }
                """),
            decodeError(
                """
                {
                  "schemaVersion": 1, "id": "e3", "kind": "array", "values": [1],
                  "frames": [{"caption": "x", "pointers": [{"name": "p", "index": 5}], "segments": []}]
                }
                """),
            decodeError(
                """
                {
                  "schemaVersion": 1, "id": "e4", "kind": "graph",
                  "nodes": [{"id": "a", "label": "A", "x": 0, "y": 0}], "edges": [],
                  "frames": [
                    {"caption": "x", "nodeStates": [{"id": "ghost", "role": "visited"}],
                     "edgeStates": [], "distances": []}
                  ]
                }
                """),
            decodeError(
                """
                {"schemaVersion": 1, "id": "e5", "kind": "tree", "frames": []}
                """),
        ]
        let nonNil = errors.compactMap { $0 }
        #expect(nonNil.count == 5)
        #expect(Set(nonNil).count == 5)
        #expect(Set(nonNil.map(\.description)).count == 5)
    }

    @Test("id 가 비어 있으면 실패한다")
    func emptyID() {
        let error = decodeError(
            """
            {
              "schemaVersion": 1, "id": "", "kind": "array", "values": [1],
              "frames": [{"caption": "x", "pointers": [], "segments": []}]
            }
            """)
        #expect(error == .emptyID)
    }

    @Test("schemaVersion 이 0 이하면 실패한다")
    func invalidSchemaVersion() {
        let error = decodeError(
            """
            {
              "schemaVersion": 0, "id": "e", "kind": "array", "values": [1],
              "frames": [{"caption": "x", "pointers": [], "segments": []}]
            }
            """)
        #expect(error == .invalidSchemaVersion(0))
    }
}
