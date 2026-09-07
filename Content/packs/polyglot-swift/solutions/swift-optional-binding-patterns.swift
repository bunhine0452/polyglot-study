func gradeLabel(_ score: Int?) -> String {
    guard let score = score else {
        return "점수 없음"
    }
    return "점수: \(score)"
}

func normalize(_ score: Int?) -> Int {
    score ?? 0
}
