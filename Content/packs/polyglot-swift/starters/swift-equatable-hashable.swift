struct Point3D: Hashable {
    let x: Int
    let y: Int
    let z: Int

    static func == (lhs: Point3D, rhs: Point3D) -> Bool {
        fatalError("여기를 구현해라")
    }

    func hash(into hasher: inout Hasher) {
        fatalError("여기를 구현해라")
    }
}

func uniqueCount(_ points: [Point3D]) -> Int {
    fatalError("여기를 구현해라")
}
