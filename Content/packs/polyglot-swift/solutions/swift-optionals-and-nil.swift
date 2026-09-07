func lookupAge(_ ages: [String: Int], name: String) -> String {
    if let age = ages[name] {
        return "\(name): \(age)살"
    } else {
        return "\(name): 나이를 모릅니다"
    }
}
