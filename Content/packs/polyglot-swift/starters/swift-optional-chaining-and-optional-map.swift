final class Person {
    var name: String?
    var friend: Person?

    init(name: String?, friend: Person?) {
        self.name = name
        self.friend = friend
    }
}

func bestFriendName(of person: Person?) -> String {
    fatalError("여기를 구현해라")
}

func doubledScore(_ score: Int?) -> Int {
    fatalError("여기를 구현해라")
}

func parseCount(_ text: String?) -> Int? {
    fatalError("여기를 구현해라")
}
