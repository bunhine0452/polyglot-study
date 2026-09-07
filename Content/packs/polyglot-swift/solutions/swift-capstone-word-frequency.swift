enum AnalyzerError: Error, Equatable {
    case emptyInput
    case invalidLimit
}

struct WordFrequency: Equatable {
    let word: String
    let count: Int
}

protocol FrequencyAnalyzer {
    func analyze(_ text: String, top limit: Int) throws -> [WordFrequency]
}

struct BasicAnalyzer: FrequencyAnalyzer {
    func analyze(_ text: String, top limit: Int) throws -> [WordFrequency] {
        guard limit >= 1 else {
            throw AnalyzerError.invalidLimit
        }
        let words = text.lowercased().split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else {
            throw AnalyzerError.emptyInput
        }
        var counts: [String: Int] = [:]
        for word in words {
            counts[String(word), default: 0] += 1
        }
        let ranked = counts.sorted { left, right in
            if left.value != right.value {
                return left.value > right.value
            }
            return left.key < right.key
        }
        return ranked.prefix(limit).map { WordFrequency(word: $0.key, count: $0.value) }
    }
}
