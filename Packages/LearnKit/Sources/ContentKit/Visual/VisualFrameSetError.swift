/// 시각화 프레임 세트가 거부되는 이유. **깨진 방식마다 케이스가 다르다** — ``PackManifestError``
/// 와 같은 이유다. 하나로 뭉치면 "시각화가 잘못됐습니다"만 남고, 사이드카를 손으로
/// 저작하는 사람(또는 `lessongen`)이 어느 프레임의 어느 값을 고칠지 알 수 없다.
///
/// 이 타입 하나가 디코딩 실패와 검증 실패를 함께 나른다. `ArrayVisual`·`GraphVisual`·
/// `TableVisual` 의 검증 초기화자가 이 에러를 던지고, 그 초기화자를 부르는 자리가 바로
/// `Decodable.init(from:)` 이므로 JSON 을 디코딩하는 순간 의미 검증까지 이미 끝나 있다.
/// `PackManifest` 처럼 "디코딩은 모양만 보고, `validate()` 는 따로 불러라" 로 가지 않은
/// 이유는 쓰임이 다르기 때문이다 — 매니페스트는 굽는 도구가 값을 조립하는 중간 상태를
/// 가질 수 있지만, 시각화는 재생기가 프레임을 순서대로 그대로 그리는 완성품만 존재해야
/// 한다. 반쯤 깨진 값이 만들어질 수 있는 창을 아예 열지 않는다.
public enum VisualFrameSetError: Error, Hashable, Sendable, CustomStringConvertible {
    /// `schemaVersion` 이 1 미만이다.
    case invalidSchemaVersion(Int)
    /// `id` 가 비어 있다. 사이드카 파일 이름이 `visuals/<id>.json` 이므로 빈 id 는
    /// 애초에 어느 파일도 가리키지 못하는 시각화를 만든다.
    case emptyID
    /// `kind` 가 array·graph·table 중 하나가 아니다. 나머지 필드를 어떤 모양으로 읽을지가
    /// 여기서 갈리므로, 값 검사보다 먼저 디코딩 단계에서 던진다.
    case unknownKind(String)
    /// 프레임이 하나도 없다. 정적 정보만 있고 이야기가 없는 시각화는 재생기에 걸 것이 없다.
    case noFrames
    /// 프레임의 자막이 빈 문자열이다. 그림만으로는 "왜 지금 이 상태인가" 가 남지 않는다.
    case emptyCaption(frameIndex: Int)

    // MARK: - 배열 장면

    /// 이름 붙은 포인터가 정적 배열 범위 밖을 가리킨다.
    case arrayIndexOutOfRange(frameIndex: Int, pointer: String, index: Int, count: Int)
    /// 강조·제외 구간의 양끝이 배열 범위 밖이거나 뒤집혀 있다(`start > end`).
    case arraySegmentOutOfRange(frameIndex: Int, start: Int, end: Int, count: Int)
    /// 프레임이 실은 배열의 길이가 시작 배열과 다르다.
    case arrayFrameValueCountMismatch(frameIndex: Int, expected: Int, found: Int)

    // MARK: - 그래프 장면

    /// 같은 노드 id 가 정적 노드 목록에 두 번 있다.
    case duplicateNodeID(String)
    /// 정적 간선이 선언되지 않은 노드를 가리킨다.
    case staticEdgeUnknownNode(from: String, to: String)
    /// 프레임의 노드 역할·거리가 정적 노드 목록에 없는 id 를 가리킨다.
    case unknownNode(frameIndex: Int, nodeID: String)
    /// 프레임의 간선 역할이 정적 간선 목록에 없는 `(from, to)` 를 가리킨다.
    case unknownEdge(frameIndex: Int, from: String, to: String)

    // MARK: - 표 장면

    /// 행 또는 열 머리글이 비어 있다 — 칸이 하나도 없는 표.
    case emptyTable
    /// 채워진 칸 또는 그 칸이 참조하는 칸이 표 범위 밖이다.
    case cellOutOfBounds(frameIndex: Int, row: Int, column: Int, rows: Int, columns: Int)

    public var description: String {
        switch self {
        case .invalidSchemaVersion(let value):
            "schemaVersion 은 1 이상의 정수여야 한다: \(value)"
        case .emptyID:
            "id 가 비어 있다"
        case .unknownKind(let raw):
            "kind 는 array·graph·table 중 하나여야 한다: \(raw)"
        case .noFrames:
            "frames 가 비어 있다 — 프레임이 없는 시각화는 재생할 수 없다"
        case .emptyCaption(let frameIndex):
            "frames[\(frameIndex)].caption 이 비어 있다"
        case .arrayIndexOutOfRange(let frameIndex, let pointer, let index, let count):
            "frames[\(frameIndex)] 의 포인터 `\(pointer)`(\(index)) 가 배열 범위(0..<\(count)) 밖이다"
        case .arraySegmentOutOfRange(let frameIndex, let start, let end, let count):
            "frames[\(frameIndex)] 의 구간 [\(start), \(end)] 이 배열 범위(0..<\(count)) 밖이거나 뒤집혔다"
        case .arrayFrameValueCountMismatch(let frameIndex, let expected, let found):
            "frames[\(frameIndex)] 이 실은 배열 길이가 \(found) 다 — 시작 배열과 같은 \(expected) 여야 한다"
        case .duplicateNodeID(let id):
            "노드 id 가 중복이다: \(id)"
        case .staticEdgeUnknownNode(let from, let to):
            "간선 (\(from) -> \(to)) 이 선언되지 않은 노드를 가리킨다"
        case .unknownNode(let frameIndex, let nodeID):
            "frames[\(frameIndex)] 이 없는 노드 id `\(nodeID)` 를 가리킨다"
        case .unknownEdge(let frameIndex, let from, let to):
            "frames[\(frameIndex)] 이 없는 간선 (\(from) -> \(to)) 을 가리킨다"
        case .emptyTable:
            "rowHeaders·columnHeaders 가 비어 있다 — 칸이 없는 표"
        case .cellOutOfBounds(let frameIndex, let row, let column, let rows, let columns):
            "frames[\(frameIndex)] 의 칸 (\(row), \(column)) 이 표 범위(\(rows)x\(columns)) 밖이다"
        }
    }
}
