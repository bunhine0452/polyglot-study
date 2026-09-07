func uniqueSorted(_ words: [String]) -> [String] {
    return Set(words).sorted()
}

func unionTags(_ a: Set<String>, _ b: Set<String>) -> Set<String> {
    return a.union(b)
}

func commonTags(_ a: Set<String>, _ b: Set<String>) -> Set<String> {
    return a.intersection(b)
}

func hasTag(_ tags: Set<String>, _ tag: String) -> Bool {
    return tags.contains(tag)
}
