struct Point3D: Hashable {
    let x: Int
    let y: Int
    let z: Int

    static func == (lhs: Point3D, rhs: Point3D) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }
}

func uniqueCount(_ points: [Point3D]) -> Int {
    Set(points).count
}
