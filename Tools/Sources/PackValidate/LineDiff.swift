internal import Foundation

/// 기대 stdout 과 실제 stdout 의 **줄 단위** 차이.
///
/// 바이트가 다르다는 사실만으로는 아무도 못 고친다. 모델에게 돌려줄 때도 마찬가지라
/// 어느 줄이 어떻게 다른지가 증거에 그대로 실려야 한다.
public enum LineDiff {
    /// LCS DP 를 돌릴 최대 줄 수. 넘으면 첫 불일치 지점만 보고한다 —
    /// 수천 줄짜리 출력에서 O(n·m) 표를 채우는 비용이 진단의 값어치를 넘는다.
    static let maxLinesForFullDiff = 400

    /// 컨텍스트 줄 수.
    static let context = 2

    public static func render(
        expected: [String],
        actual: [String],
        expectedLabel: String,
        actualLabel: String
    ) -> String {
        var out = "--- 기대: \(expectedLabel)\n+++ 실제: \(actualLabel)\n"
        if expected.count > maxLinesForFullDiff || actual.count > maxLinesForFullDiff {
            out += firstDifference(expected: expected, actual: actual)
            return out
        }
        let script = editScript(expected, actual)
        out += hunks(script)
        return out
    }

    // MARK: - 편집 스크립트

    enum Op: Equatable {
        case same(String, expectedLine: Int, actualLine: Int)
        case removed(String, expectedLine: Int)
        case added(String, actualLine: Int)
    }

    static func editScript(_ a: [String], _ b: [String]) -> [Op] {
        let n = a.count
        let m = b.count
        // lcs[i][j] = a[i...] 와 b[j...] 의 최장 공통 부분수열 길이.
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    lcs[i][j] =
                        a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }

        var ops: [Op] = []
        var i = 0
        var j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                ops.append(.same(a[i], expectedLine: i + 1, actualLine: j + 1))
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                ops.append(.removed(a[i], expectedLine: i + 1))
                i += 1
            } else {
                ops.append(.added(b[j], actualLine: j + 1))
                j += 1
            }
        }
        while i < n {
            ops.append(.removed(a[i], expectedLine: i + 1))
            i += 1
        }
        while j < m {
            ops.append(.added(b[j], actualLine: j + 1))
            j += 1
        }
        return ops
    }

    // MARK: - 헝크 조립

    private static func hunks(_ script: [Op]) -> String {
        let changed = script.indices.filter {
            if case .same = script[$0] { return false }
            return true
        }
        guard !changed.isEmpty else { return "(줄 단위 차이가 없다 — 후행 공백이나 인코딩을 보라)\n" }

        var ranges: [ClosedRange<Int>] = []
        for index in changed {
            let lower = max(0, index - context)
            let upper = min(script.count - 1, index + context)
            if var last = ranges.last, last.upperBound + 1 >= lower {
                last = last.lowerBound...max(last.upperBound, upper)
                ranges[ranges.count - 1] = last
            } else {
                ranges.append(lower...upper)
            }
        }

        var out = ""
        for range in ranges {
            out += "@@ 기대 \(startLine(script, range, expected: true))행 / 실제 "
            out += "\(startLine(script, range, expected: false))행 @@\n"
            for index in range {
                switch script[index] {
                case .same(let text, _, _): out += "  \(text)\n"
                case .removed(let text, _): out += "- \(text)\n"
                case .added(let text, _): out += "+ \(text)\n"
                }
            }
        }
        return out
    }

    private static func startLine(_ script: [Op], _ range: ClosedRange<Int>, expected: Bool) -> Int {
        for index in range {
            switch script[index] {
            case .same(_, let e, let a): return expected ? e : a
            case .removed(_, let e): if expected { return e }
            case .added(_, let a): if !expected { return a }
            }
        }
        return 0
    }

    // MARK: - 큰 출력용 폴백

    private static func firstDifference(expected: [String], actual: [String]) -> String {
        let count = min(expected.count, actual.count)
        for index in 0..<count where expected[index] != actual[index] {
            return """
                @@ \(index + 1)행에서 처음 갈린다 (출력이 커서 전체 diff 를 생략한다) @@
                - \(expected[index])
                + \(actual[index])

                """
        }
        return """
            @@ \(count + 1)행부터 길이가 다르다 — 기대 \(expected.count)행, 실제 \(actual.count)행 @@

            """
    }
}
