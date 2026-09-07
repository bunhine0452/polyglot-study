import Testing
@testable import Solution

@Test func equalPointsCompareTrue() {
    #expect(Point3D(x: 1, y: 2, z: 3) == Point3D(x: 1, y: 2, z: 3))
}

@Test func differentZCompareFalse() {
    #expect(Point3D(x: 1, y: 2, z: 3) != Point3D(x: 1, y: 2, z: 4))
}

@Test func differentXCompareFalse() {
    #expect(Point3D(x: 0, y: 0, z: 0) != Point3D(x: 1, y: 0, z: 0))
}

@Test func uniqueCountOfEmptyArray() {
    #expect(uniqueCount([]) == 0)
}

@Test func uniqueCountCountsDuplicatesOnce() {
    let pts = [
        Point3D(x: 1, y: 1, z: 1),
        Point3D(x: 1, y: 1, z: 1),
        Point3D(x: 2, y: 1, z: 1),
        Point3D(x: 2, y: 2, z: 1)
    ]
    #expect(uniqueCount(pts) == 3)
}
