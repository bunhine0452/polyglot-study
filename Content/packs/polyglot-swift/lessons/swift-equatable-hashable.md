@Concept(id: equatable-hashable-conformance) {
구조체나 클래스는 기본적으로 **==** 로 비교할 수 없다. **Equatable** 을 채택하고 **static func == (lhs:rhs:)** 를 구현하면 **==** 와 **!=** 가 동작하게 되어, 두 값이 같은지를 내가 정한 기준으로 판단할 수 있다. **Set** 이나 딕셔너리의 키로 쓰려면 **Hashable** 도 채택해야 하는데, 이때 **func hash(into:)** 를 구현해 **hasher.combine(...)** 으로 값의 구성 요소를 넣어 준다. 해시의 규칙은 하나다 — **==** 로 같다고 나오는 두 값은 반드시 같은 해시값을 가져야 하므로, 보통 **==** 에서 비교하는 프로퍼티를 그대로 **combine** 한다.
}

@Example(id: point-hashable-example, language: swift, expected: expected/swift-equatable-hashable.txt) {
2차원 점 구조체에 **Equatable** 과 **Hashable** 을 직접 채택한 뒤, 같음 비교와 **Set** 담기를 확인한다.

```swift
struct Point: Hashable {
    let x: Int
    let y: Int

    static func == (lhs: Point, rhs: Point) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

let a = Point(x: 1, y: 2)
let b = Point(x: 1, y: 2)
let c = Point(x: 3, y: 4)
print(a == b)
print(a == c)
print(a != c)

var points: Set<Point> = [a, b, c]
print(points.count)

points.insert(Point(x: 1, y: 2))
print(points.count)
print(points.contains(Point(x: 3, y: 4)))
```
}

@Blank(id: tag-hashable-blank, language: swift) {
태그 구조체의 같음 비교와 해시 구현에서 빠진 부분을 채워라.

```swift
struct Tag: Hashable {
    let name: String
    let id: Int

    static func ___1___(lhs: Tag, rhs: Tag) -> Bool {
        lhs.name == rhs.name && lhs.id == rhs.id
    }

    func ___2___(into hasher: ___3___) {
        hasher.combine(name)
        hasher.combine(id)
    }
}
```

@Answer(slot: 1) {
`==`
}

@Answer(slot: 2) {
`hash`
}

@Answer(slot: 3) {
`inout Hasher`
}
}

@Task(id: point3d-hashable-task, language: swift, starter: starters/swift-equatable-hashable.swift, tests: tests/swift-equatable-hashable.swift, solution: solutions/swift-equatable-hashable.swift) {
3차원 점 구조체 **Point3D** 가 **Hashable** 을 채택하도록 **==** 와 **hash(into:)** 를 구현하고, 배열에서 중복을 제거한 개수를 세는 함수 **uniqueCount(_:)** 를 완성하라. 같음은 **x**, **y**, **z** 세 값이 모두 같을 때만 참이다. **uniqueCount** 는 **Set** 을 이용해 서로 다른 점의 개수를 반환한다.

@Hint {
== 연산자는 lhs 와 rhs 의 세 프로퍼티가 각각 같은지 && 로 묶어 비교하면 된다.
}

@Hint {
hash(into:) 안에서는 == 에서 비교한 프로퍼티를 hasher.combine 으로 모두 넣는다.
}

@Hint {
uniqueCount 는 배열을 Set 으로 바꾸면 중복이 자동으로 사라진다는 점을 이용한다.
}
}

@Quiz(id: hash-consistency-quiz, answer: still-correct-slower) {
@Question {
구조체의 hash(into:) 에서 == 로 비교하는 프로퍼티 중 일부만 hasher.combine 에 넣었다. 어떤 일이 벌어질까?
}

@Choice(id: still-correct-slower) {
같은 값은 여전히 같은 해시를 가지므로 Set 의 동작은 올바르지만, 다른 값들이 해시 충돌을 일으킬 가능성이 커진다.
}

@Choice(id: compile-error) {
Hashable 을 채택하려면 모든 저장 프로퍼티를 combine 해야 하므로 컴파일 오류가 난다.
}

@Choice(id: equality-breaks) {
== 의 결과가 달라져서 같은 값끼리도 다르다고 판정된다.
}

@Explanation {
해시의 유일한 규칙은 같은 값이 같은 해시를 가지는 것이고, 이는 combine 한 프로퍼티만으로도 유지된다. 하지만 combine 을 적게 하면 서로 다른 값들이 같은 해시로 몰려 충돌이 잦아지고 Set 의 탐색이 느려질 수 있다. 반대로 == 로 같은 값을 다른 해시로 만들면 Set 이 절대로 틀리므로 그건 하면 안 된다.
}
}

@Reflection(id: equatable-hashable-reflection) {
@Prompt(id: equality-criteria) {
Point3D 의 같음을 x 와 y 만 비교하고 z 는 무시하도록 바꾼다면, hash(into:) 는 어떻게 바꿔야 할까? 이유와 함께 설명해 보라.
}

@Prompt(id: value-vs-reference) {
구조체는 프로퍼티 값이 같으면 같은 값으로 취급할 수 있지만, 클래스 인스턴스는 어떤 기준으로 같음을 정의하는 게 자연스러울까?
}

@Prompt(id: set-benefit) {
배열에서 중복을 제거할 때 필터와 클로저로 직접 비교하는 방법과 Set 을 쓰는 방법을 비교해 보라. Hashable 채택이 어떤 차이를 만드는가?
}
}
