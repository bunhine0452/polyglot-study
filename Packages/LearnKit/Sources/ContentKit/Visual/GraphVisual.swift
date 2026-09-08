/// 그래프 장면의 정적 정보와 프레임들.
///
/// BFS·DFS·다익스트라가 이 장면을 쓴다. **트리도 여기다** — 트리는 부모·자식이 겹치지
/// 않도록 좌표를 저작해 둔 그래프일 뿐이라, 트리 전용 렌더러를 따로 두지 않는다. 노드가
/// 좌표를 갖고 있어야 하는 이유도 그것이다: 배치를 렌더러가 매번 계산하게 두면 "트리는
/// 계층으로, 일반 그래프는 힘-기반으로" 처럼 규칙이 장면마다 갈리고, 사전 저작
/// 시각화라는 전제와도 어긋난다 — 저작자가 원하는 배치를 저작 시점에 확정해 둔다.
public struct GraphVisual: Hashable, Sendable {
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]
    public var frames: [GraphFrame]

    /// 간선이 선언된 노드만 가리키고, 모든 프레임의 노드·간선·거리 참조가 정적 정보
    /// 범위 안에 있고, 자막이 비지 않았을 때만 만들어진다.
    public init(nodes: [GraphNode], edges: [GraphEdge], frames: [GraphFrame])
        throws(VisualFrameSetError)
    {
        var nodeIDs: Set<String> = []
        for node in nodes {
            guard nodeIDs.insert(node.id).inserted else { throw .duplicateNodeID(node.id) }
        }
        for edge in edges {
            guard nodeIDs.contains(edge.from), nodeIDs.contains(edge.to) else {
                throw .staticEdgeUnknownNode(from: edge.from, to: edge.to)
            }
        }
        guard !frames.isEmpty else { throw .noFrames }

        for (frameIndex, frame) in frames.enumerated() {
            guard !frame.caption.isEmpty else { throw .emptyCaption(frameIndex: frameIndex) }
            for state in frame.nodeStates {
                guard nodeIDs.contains(state.id) else {
                    throw .unknownNode(frameIndex: frameIndex, nodeID: state.id)
                }
            }
            for state in frame.edgeStates {
                guard GraphVisual.edgeExists(from: state.from, to: state.to, in: edges) else {
                    throw .unknownEdge(frameIndex: frameIndex, from: state.from, to: state.to)
                }
            }
            for distance in frame.distances {
                guard nodeIDs.contains(distance.id) else {
                    throw .unknownNode(frameIndex: frameIndex, nodeID: distance.id)
                }
            }
        }

        self.nodes = nodes
        self.edges = edges
        self.frames = frames
    }

    /// 방향 없는 간선은 저작된 순서를 안 가린다 — BFS 가 A-B 간선을 B 에서 A 방향으로
    /// 밟았다고 해서, 저작자가 그 순간마다 `from: B, to: A` 로 다시 등록해야 한다면
    /// 저작이 피곤해진다.
    private static func edgeExists(from: String, to: String, in edges: [GraphEdge]) -> Bool {
        edges.contains { edge in
            (edge.from == from && edge.to == to)
                || (!edge.directed && edge.from == to && edge.to == from)
        }
    }
}

/// 그래프 노드 하나. 좌표는 시각화 전체에서 고정이다 — 프레임은 좌표를 바꾸지 않고
/// 역할만 바꾼다.
public struct GraphNode: Hashable, Sendable, Codable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double

    public init(id: String, label: String, x: Double, y: Double) {
        self.id = id
        self.label = label
        self.x = x
        self.y = y
    }
}

/// 간선 하나. `weight` 는 다익스트라에만 필요하고 BFS·DFS 는 nil 로 둔다.
public struct GraphEdge: Hashable, Sendable {
    public var from: String
    public var to: String
    public var weight: Double?
    /// 방향 그래프인가. 트리의 부모→자식처럼 방향이 의미를 가지면 true.
    public var directed: Bool

    public init(from: String, to: String, weight: Double? = nil, directed: Bool = false) {
        self.from = from
        self.to = to
        self.weight = weight
        self.directed = directed
    }
}

/// 그래프 장면에서 노드·간선이 가질 수 있는 역할. 노드와 간선이 같은 어휘를 공유한다 —
/// "지금 막 확정된 노드"와 "그 확정을 만든 간선"이 같은 프레임에서 같은 뜻(`settled`)을
/// 갖는 편이, 노드 전용·간선 전용 어휘를 따로 두는 것보다 저작자가 외울 게 적다.
public enum GraphRole: String, Hashable, Sendable, Codable, CaseIterable {
    /// 아직 방문하지 않았지만 다음 후보로 큐·스택·우선순위 큐에 들어와 있다.
    case frontier
    /// 지금 이 프레임에서 처리 중이다.
    case current
    /// 이미 방문했다.
    case visited
    /// 최종 답으로 확정됐다 — 다익스트라의 최단 거리 확정, BFS 트리의 완성된 간선 등.
    case settled
}

/// 노드 하나의 프레임별 역할.
public struct GraphNodeState: Hashable, Sendable, Codable {
    public var id: String
    public var role: GraphRole

    public init(id: String, role: GraphRole) {
        self.id = id
        self.role = role
    }
}

/// 간선 하나의 프레임별 역할.
public struct GraphEdgeState: Hashable, Sendable, Codable {
    public var from: String
    public var to: String
    public var role: GraphRole

    public init(from: String, to: String, role: GraphRole) {
        self.from = from
        self.to = to
        self.role = role
    }
}

/// 노드 하나의 수치. 다익스트라의 "지금까지 알려진 최단 거리"가 전형적인 예다.
public struct GraphNodeDistance: Hashable, Sendable, Codable {
    public var id: String
    public var value: Double

    public init(id: String, value: Double) {
        self.id = id
        self.value = value
    }
}

/// 그래프 장면의 프레임 하나. 이전 프레임과의 **차이**가 아니라 이 시점의 전체 상태다 —
/// 재생기가 임의의 프레임으로 뛰어도 그 앞 프레임을 순서대로 다시 재생할 필요가 없다.
public struct GraphFrame: Hashable, Sendable {
    public var caption: String
    public var nodeStates: [GraphNodeState]
    public var edgeStates: [GraphEdgeState]
    public var distances: [GraphNodeDistance]

    public init(
        caption: String,
        nodeStates: [GraphNodeState] = [],
        edgeStates: [GraphEdgeState] = [],
        distances: [GraphNodeDistance] = []
    ) {
        self.caption = caption
        self.nodeStates = nodeStates
        self.edgeStates = edgeStates
        self.distances = distances
    }
}

// MARK: - Codable

extension GraphEdge: Codable {
    private enum CodingKeys: String, CodingKey { case from, to, weight, directed }

    /// `directed` 를 생략하면 무방향으로 본다 — BFS·DFS·다익스트라가 흔히 쓰는 무방향
    /// 그래프의 모든 간선마다 `directed: false` 를 적어야 한다면 사이드카가 장황해진다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        directed = try container.decodeIfPresent(Bool.self, forKey: .directed) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encode(directed, forKey: .directed)
    }
}

extension GraphFrame: Codable {
    private enum CodingKeys: String, CodingKey { case caption, nodeStates, edgeStates, distances }

    /// `nodeStates`·`edgeStates`·`distances` 를 생략하면 빈 배열로 본다 — 다익스트라가
    /// 아니면 거리를 아예 안 실을 프레임이 많고, 노드 역할만 바뀌고 간선은 그대로인
    /// 프레임도 흔하다. 매번 셋 다 적어야 한다면 사이드카가 장황해진다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caption = try container.decode(String.self, forKey: .caption)
        nodeStates = try container.decodeIfPresent([GraphNodeState].self, forKey: .nodeStates) ?? []
        edgeStates = try container.decodeIfPresent([GraphEdgeState].self, forKey: .edgeStates) ?? []
        distances = try container.decodeIfPresent([GraphNodeDistance].self, forKey: .distances) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caption, forKey: .caption)
        try container.encode(nodeStates, forKey: .nodeStates)
        try container.encode(edgeStates, forKey: .edgeStates)
        try container.encode(distances, forKey: .distances)
    }
}

extension GraphVisual: Codable {
    private enum CodingKeys: String, CodingKey { case nodes, edges, frames }

    /// 모양만 읽고 곧바로 검증 초기화자에 넘긴다 — 값 자체가 틀렸으면 여기서 이미
    /// 던진다. ``PackManifest`` 처럼 "일단 다 담고 나중에 `validate()`" 로 가지 않는
    /// 이유는 ``VisualFrameSetError`` 문서에 적었다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nodes = try container.decode([GraphNode].self, forKey: .nodes)
        let edges = try container.decode([GraphEdge].self, forKey: .edges)
        let frames = try container.decode([GraphFrame].self, forKey: .frames)
        try self.init(nodes: nodes, edges: edges, frames: frames)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
        try container.encode(frames, forKey: .frames)
    }
}
