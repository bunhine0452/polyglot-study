final class Person {
    var name: String?
    var friend: Person?

    init(name: String?, friend: Person?) {
        self.name = name
        self.friend = friend
    }
}

func bestFriendName(of person: Person?) -> String {
    person?.friend?.name ?? "친구 없음"
}

func doubledScore(_ score: Int?) -> Int {
    score.map { $0 * 2 } ?? 0
}

func parseCount(_ text: String?) -> Int? {
    text.flatMap { Int($0) }
}
