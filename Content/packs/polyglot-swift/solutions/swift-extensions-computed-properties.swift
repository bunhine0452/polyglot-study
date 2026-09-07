extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }

    var squared: Int {
        return self * self
    }
}

extension String {
    var wordCount: Int {
        let words = split(separator: " ")
        if hasPrefix(" ") {
            return max(words.count - 1, 0)
        }
        return words.count
    }
}
