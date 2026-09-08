/// 알고리즘 시각화 프레임 모델 v1 의 최상위 타입.
///
/// 시각화는 **사전 저작된 프레임 배열**이다. 학습자 코드를 계측해 뽑지 않는다 —
/// 계측기를 언어마다 새로 만들어야 해서 지금 범위 밖이고, 애초에 시각화는 개념에
/// 붙어 있어 풀이 언어와 무관해야 한다(레슨 화면에서 풀이 언어를 바꿔도 시각화는
/// 그대로 있어야 하는 이유). 그래서 이 타입은 팩 사이드카(`visuals/<id>.json`)가 담는
/// 값 그대로이고, 재생기는 `frames` 를 순서대로 훑기만 한다.
///
/// 장면은 셋뿐이다 — 배열·그래프·표. 트리는 그래프의 특수한 경우일 뿐이다: 부모·자식이
/// 겹치지 않도록 좌표를 저작해 둔 그래프이지, 트리 전용 렌더러가 필요한 게 아니다.
public struct VisualFrameSet: Hashable, Sendable {
    /// 이 앱이 이해하는 스키마 버전. ``PackManifest/currentSchemaVersion`` 과 같은 자리다.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// 사이드카 파일 이름(`visuals/<id>.json`)과 같아야 하는 식별자. 레슨의 `@Visualize`
    /// 디렉티브가 이 값으로 파일을 찾는다.
    public var id: String
    public var scene: VisualScene

    /// 검증을 통과한 값만 만든다. `values`·`nodes`/`edges`·`rowHeaders`/`columnHeaders`
    /// 같은 장면별 정적 정보와 프레임은 `scene` 을 만드는 시점에 이미 검증이 끝나 있으므로,
    /// 여기서는 `schemaVersion` 과 `id` 만 본다.
    public init(
        schemaVersion: Int = VisualFrameSet.currentSchemaVersion,
        id: String,
        scene: VisualScene
    ) throws(VisualFrameSetError) {
        guard schemaVersion >= 1 else { throw .invalidSchemaVersion(schemaVersion) }
        guard !id.isEmpty else { throw .emptyID }
        self.schemaVersion = schemaVersion
        self.id = id
        self.scene = scene
    }
}

/// 프레임 세트가 덮는 장면 셋. 렌더러가 이 값으로 어느 뷰를 그릴지 고른다.
public enum VisualSceneKind: String, Hashable, Sendable, Codable, CaseIterable {
    case array, graph, table
}

/// 장면별 정적 정보와 프레임 배열을 하나로 묶는다. 각 케이스의 연관 값은 이미 자기
/// 초기화자 안에서 검증이 끝난 ``ArrayVisual``·``GraphVisual``·``TableVisual`` 이다 —
/// 그래서 이 열거형 자체는 더 검증할 것이 없다.
public enum VisualScene: Hashable, Sendable {
    case array(ArrayVisual)
    case graph(GraphVisual)
    case table(TableVisual)

    public var kind: VisualSceneKind {
        switch self {
        case .array: .array
        case .graph: .graph
        case .table: .table
        }
    }

    /// 장면과 무관하게 프레임 개수. 재생기의 눈금·경계 판정이 이 값만 있으면 된다.
    ///
    /// 여기 두는 이유는 재생기가 장면 종류를 알 필요가 없게 하기 위해서다 — 장면이
    /// 하나 더 늘어도 재생기의 이동 로직은 그대로다.
    public var frameCount: Int {
        switch self {
        case .array(let visual): visual.frames.count
        case .graph(let visual): visual.frames.count
        case .table(let visual): visual.frames.count
        }
    }

    /// `index` 프레임의 자막. 범위 밖이면 `nil`.
    ///
    /// 자막은 세 장면 모두 필수라(빈 문자열도 거부된다) 장면을 갈라 보지 않고 한 곳에서
    /// 꺼낼 수 있다 — 재생기가 그림 아래 한 줄을 그리는 데 이것만 있으면 된다.
    public func caption(at index: Int) -> String? {
        switch self {
        case .array(let visual): visual.frames.indices.contains(index)
            ? visual.frames[index].caption : nil
        case .graph(let visual): visual.frames.indices.contains(index)
            ? visual.frames[index].caption : nil
        case .table(let visual): visual.frames.indices.contains(index)
            ? visual.frames[index].caption : nil
        }
    }
}

// MARK: - Codable

extension VisualFrameSet: Codable {
    /// `kind` 가 스펙상 세 번째로 적히지만, JSON 객체는 키 순서를 보장하지 않으므로
    /// 여기서는 순서가 아니라 키 이름으로만 찾는다.
    private enum RootKeys: String, CodingKey { case schemaVersion, id, kind }

    /// `kind` 로 나머지 필드의 모양을 정한 뒤, **같은 디코더**를 장면 타입에 다시 넘긴다.
    /// 장면별 정적 필드(`values` 대 `nodes`/`edges` 대 `rowHeaders`/`columnHeaders`)가
    /// 최상위에 평평하게 널려 있어야 사이드카 JSON 을 손으로 쓰기 쉬워지기 때문이다 —
    /// `scene` 이라는 중첩 키를 하나 더 두면 저작자가 괄호를 한 겹 더 맞춰야 한다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: RootKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let id = try container.decode(String.self, forKey: .id)
        let kindRaw = try container.decode(String.self, forKey: .kind)
        guard let kind = VisualSceneKind(rawValue: kindRaw) else {
            throw VisualFrameSetError.unknownKind(kindRaw)
        }

        let scene: VisualScene
        switch kind {
        case .array: scene = .array(try ArrayVisual(from: decoder))
        case .graph: scene = .graph(try GraphVisual(from: decoder))
        case .table: scene = .table(try TableVisual(from: decoder))
        }
        try self.init(schemaVersion: schemaVersion, id: id, scene: scene)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: RootKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(scene.kind, forKey: .kind)
        switch scene {
        case .array(let visual): try visual.encode(to: encoder)
        case .graph(let visual): try visual.encode(to: encoder)
        case .table(let visual): try visual.encode(to: encoder)
        }
    }
}
