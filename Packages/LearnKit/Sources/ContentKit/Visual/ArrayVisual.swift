/// 배열 장면의 정적 정보와 프레임들.
///
/// 정렬(버블·병합·퀵)·이진 탐색·투 포인터·슬라이딩 윈도우가 전부 이 장면 하나를 쓴다.
/// 넷 다 "인덱스로 배열 하나를 훑으며 포인터를 움직인다"는 같은 모양이라서 장면을
/// 나눌 이유가 없다 — 렌더러 하나가 포인터 이름과 구간 역할만 보고 그린다.
public struct ArrayVisual: Hashable, Sendable {
    /// 시작 배열. 값이 움직이지 않는 시각화(이진 탐색·투 포인터·슬라이딩 윈도우)에서는
    /// 프레임이 이 배열을 그대로 쓰고 포인터·구간만 옮겨 다닌다.
    ///
    /// **정렬은 값이 움직이는 것이 핵심이다.** 그래서 프레임은 자기 `values` 를 선택적으로
    /// 실을 수 있다(``ArrayFrame/values``). 없으면 이 배열이다 — 훑기 시각화의 사이드카가
    /// 프레임마다 같은 배열을 반복해 적지 않아도 된다.
    public var values: [Int]
    public var frames: [ArrayFrame]

    /// 모든 프레임의 포인터·구간이 `values` 범위 안에 있고 자막이 비지 않았을 때만
    /// 만들어진다.
    public init(values: [Int], frames: [ArrayFrame]) throws(VisualFrameSetError) {
        guard !frames.isEmpty else { throw .noFrames }
        for (frameIndex, frame) in frames.enumerated() {
            guard !frame.caption.isEmpty else { throw .emptyCaption(frameIndex: frameIndex) }
            // 정렬은 원소를 **자리바꿈**할 뿐 개수를 바꾸지 않는다. 길이가 달라진 프레임은
            // 저작 실수다 — 길이가 흔들리면 포인터 검증의 기준 자체가 프레임마다 달라진다.
            if let frameValues = frame.values, frameValues.count != values.count {
                throw .arrayFrameValueCountMismatch(
                    frameIndex: frameIndex, expected: values.count, found: frameValues.count)
            }
            for pointer in frame.pointers {
                guard values.indices.contains(pointer.index) else {
                    throw .arrayIndexOutOfRange(
                        frameIndex: frameIndex, pointer: pointer.name, index: pointer.index,
                        count: values.count)
                }
            }
            for segment in frame.segments {
                let inBounds =
                    segment.start <= segment.end && values.indices.contains(segment.start)
                    && values.indices.contains(segment.end)
                guard inBounds else {
                    throw .arraySegmentOutOfRange(
                        frameIndex: frameIndex, start: segment.start, end: segment.end,
                        count: values.count)
                }
            }
        }
        self.values = values
        self.frames = frames
    }
}

extension ArrayVisual {
    /// `frameIndex` 시점의 배열. 프레임이 자기 값을 안 실었으면 시작 배열이다.
    ///
    /// 재생기가 이 한 곳만 부르게 해서 "프레임 값이 있으면 그것, 없으면 원본" 규칙이
    /// 뷰마다 다시 쓰이지 않게 한다.
    public func values(at frameIndex: Int) -> [Int] {
        guard frames.indices.contains(frameIndex) else { return values }
        return frames[frameIndex].values ?? values
    }
}

/// 이름 붙은 인덱스 하나. `lo`·`mid`·`hi`, 이진 탐색의 `left`·`right`, 투 포인터의
/// `slow`·`fast` 같은 것들. 이름을 자유 문자열로 둔 이유는 알고리즘마다 관용적인
/// 이름이 다르고, 그 이름 자체가 자막 없이도 학습자에게 신호를 주기 때문이다.
public struct ArrayPointer: Hashable, Sendable, Codable {
    public var name: String
    public var index: Int

    public init(name: String, index: Int) {
        self.name = name
        self.index = index
    }
}

/// 배열 구간의 의미. 렌더러가 칠할 색이 아니라 "왜 이 구간이 보이는가"만 담는다 —
/// 색은 나중에 붙는 렌더러의 몫이다.
public enum ArraySegmentRole: String, Hashable, Sendable, Codable, CaseIterable {
    /// 지금 눈여겨봐야 하는 구간 — 비교 중인 두 원소, 슬라이딩 윈도우의 현재 창.
    case highlighted
    /// 더 이상 답이 될 수 없어 결과에서 빠진 구간 — 이진 탐색이 좁혀낸 절반.
    case excluded
}

/// 양끝을 포함하는 인덱스 구간 하나에 역할을 붙인 것.
public struct ArraySegment: Hashable, Sendable, Codable {
    public var role: ArraySegmentRole
    public var start: Int
    public var end: Int

    public init(role: ArraySegmentRole, start: Int, end: Int) {
        self.role = role
        self.start = start
        self.end = end
    }
}

/// 배열 장면의 프레임 하나. 이전 프레임과의 **차이**가 아니라 이 시점의 전체 상태를
/// 담는다 — 재생기가 임의의 프레임으로 곧장 뛰어도(스크럽) 그 앞의 모든 프레임을
/// 순서대로 재생해 상태를 누적할 필요가 없게 하기 위해서다.
public struct ArrayFrame: Hashable, Sendable {
    /// 이 프레임이 왜 지금 이 상태인지. 그림만으로는 안 남는 정보라 필수다.
    public var caption: String
    /// 이 시점의 배열. `nil` 이면 ``ArrayVisual/values`` 그대로다.
    ///
    /// 정렬처럼 원소가 자리를 바꾸는 시각화만 채운다. 개수는 원본과 같아야 한다.
    public var values: [Int]?
    public var pointers: [ArrayPointer]
    public var segments: [ArraySegment]

    public init(
        caption: String,
        values: [Int]? = nil,
        pointers: [ArrayPointer] = [],
        segments: [ArraySegment] = []
    ) {
        self.caption = caption
        self.values = values
        self.pointers = pointers
        self.segments = segments
    }
}

// MARK: - Codable

extension ArrayFrame: Codable {
    private enum CodingKeys: String, CodingKey { case caption, values, pointers, segments }

    /// `pointers`·`segments` 를 생략하면 빈 배열로 본다 — 포인터도 강조 구간도 없는
    /// "그냥 지금은 이 상태다" 프레임을 적을 때마다 빈 배열 두 개를 타이핑해야 한다면
    /// 사이드카가 장황해진다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caption = try container.decode(String.self, forKey: .caption)
        values = try container.decodeIfPresent([Int].self, forKey: .values)
        pointers = try container.decodeIfPresent([ArrayPointer].self, forKey: .pointers) ?? []
        segments = try container.decodeIfPresent([ArraySegment].self, forKey: .segments) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caption, forKey: .caption)
        // `nil` 은 아예 적지 않는다 — 훑기 시각화의 사이드카에 `"values": null` 이 프레임마다
        // 깔리면 "값이 바뀌는 시각화" 로 오해하기 쉽다.
        try container.encodeIfPresent(values, forKey: .values)
        try container.encode(pointers, forKey: .pointers)
        try container.encode(segments, forKey: .segments)
    }
}

extension ArrayVisual: Codable {
    private enum CodingKeys: String, CodingKey { case values, frames }

    /// 모양만 읽고 곧바로 검증 초기화자에 넘긴다 — 값 자체가 틀렸으면 여기서 이미
    /// 던진다. ``PackManifest`` 처럼 "일단 다 담고 나중에 `validate()`" 로 가지 않는
    /// 이유는 ``VisualFrameSetError`` 문서에 적었다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let values = try container.decode([Int].self, forKey: .values)
        let frames = try container.decode([ArrayFrame].self, forKey: .frames)
        try self.init(values: values, frames: frames)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values, forKey: .values)
        try container.encode(frames, forKey: .frames)
    }
}
