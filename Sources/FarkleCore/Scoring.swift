import Foundation

/// Face-count vector: `counts[0]` is how many dice show a 1, ... `counts[5]` how many show a 6.
public typealias FaceCounts = [Int]

/// KCD2 dice scoring. All scores are multiples of 50; `units` are scores divided by 50.
public enum Scoring {
    public static let unit = 50

    /// Score in points of a selection whose dice all belong to scoring units, or nil if any
    /// selected die cannot be part of a scoring unit. Uses the best partition of the dice.
    public static func score(_ counts: FaceCounts) -> Int? {
        guard let u = scoreUnits(counts) else { return nil }
        return u * unit
    }

    /// Same as `score` but in 50-point units. Table-driven for selections of up to six dice.
    public static func scoreUnits(_ counts: FaceCounts) -> Int? {
        let key = encode(counts)
        if key < table.count {
            let v = table[key]
            return v < 0 ? nil : Int(v)
        }
        return compute(counts)
    }

    /// Score of a list of faces (e.g. [1, 4, 4, 4, 5]).
    public static func score(faces: [Int]) -> Int? {
        score(faceCounts(faces))
    }

    public static func faceCounts(_ faces: [Int]) -> FaceCounts {
        var c = [Int](repeating: 0, count: 6)
        for f in faces { c[f - 1] += 1 }
        return c
    }

    /// Mixed-radix encoding with base 7 (each count 0...6).
    @inline(__always)
    static func encode(_ counts: FaceCounts) -> Int {
        var k = 0
        for c in counts { k = k * 7 + c }
        return k
    }

    private static let table: [Int16] = {
        var t = [Int16](repeating: -1, count: 117_649)
        var counts = [Int](repeating: 0, count: 6)
        func rec(_ i: Int, _ remaining: Int) {
            if i == 6 {
                if let s = compute(counts) { t[encode(counts)] = Int16(s) }
                return
            }
            for c in 0...remaining {
                counts[i] = c
                rec(i + 1, remaining - c)
            }
            counts[i] = 0
        }
        rec(0, 6)
        return t
    }()

    /// Best partition score (in units) or nil. Recursive; only used to build the table.
    static func compute(_ counts: FaceCounts) -> Int? {
        if counts.allSatisfy({ $0 == 0 }) { return 0 }
        var best: Int? = nil
        func consider(_ v: Int?) {
            if let v, v > (best ?? -1) { best = v }
        }
        // Straights
        if counts.allSatisfy({ $0 >= 1 }) {
            var rest = counts; for i in 0..<6 { rest[i] -= 1 }
            if let r = compute(rest) { consider(30 + r) }
        }
        if (0..<5).allSatisfy({ counts[$0] >= 1 }) {
            var rest = counts; for i in 0..<5 { rest[i] -= 1 }
            if let r = compute(rest) { consider(10 + r) }
        }
        if (1..<6).allSatisfy({ counts[$0] >= 1 }) {
            var rest = counts; for i in 1..<6 { rest[i] -= 1 }
            if let r = compute(rest) { consider(15 + r) }
        }
        // Groups of three or more of a kind
        for face in 1...6 where counts[face - 1] >= 3 {
            for k in 3...counts[face - 1] {
                var rest = counts; rest[face - 1] -= k
                if let r = compute(rest) { consider(groupUnits(face: face, count: k) + r) }
            }
        }
        // Singles
        if counts[0] >= 1 {
            var rest = counts; rest[0] -= 1
            if let r = compute(rest) { consider(2 + r) }
        }
        if counts[4] >= 1 {
            var rest = counts; rest[4] -= 1
            if let r = compute(rest) { consider(1 + r) }
        }
        return best
    }

    /// Units for `count` (>= 3) dice showing `face`.
    static func groupUnits(face: Int, count: Int) -> Int {
        let base = face == 1 ? 20 : face * 2
        return base << (count - 3)
    }

    /// Human description of the scoring units in a selection, e.g. "three 4s + 1 + 5".
    public static func describe(_ counts: FaceCounts) -> String {
        guard scoreUnits(counts) != nil else { return "not a scoring selection" }
        var parts: [String] = []
        var c = counts
        // Greedy explanation that matches the maximum partition for all sub-6 selections.
        if c.allSatisfy({ $0 >= 1 }) {
            parts.append("straight 1-6"); for i in 0..<6 { c[i] -= 1 }
        } else if (0..<5).allSatisfy({ c[$0] >= 1 }) && bestPrefersStraight(c, low: true) {
            parts.append("straight 1-5"); for i in 0..<5 { c[i] -= 1 }
        } else if (1..<6).allSatisfy({ c[$0] >= 1 }) && bestPrefersStraight(c, low: false) {
            parts.append("straight 2-6"); for i in 1..<6 { c[i] -= 1 }
        }
        for face in 1...6 where c[face - 1] >= 3 {
            let n = c[face - 1]
            let word = ["three", "four", "five", "six"][n - 3]
            parts.append("\(word) \(face)s")
            c[face - 1] = 0
        }
        if c[0] > 0 { parts.append(contentsOf: Array(repeating: "1", count: c[0])) }
        if c[4] > 0 { parts.append(contentsOf: Array(repeating: "5", count: c[4])) }
        return parts.joined(separator: " + ")
    }

    private static func bestPrefersStraight(_ counts: FaceCounts, low: Bool) -> Bool {
        var rest = counts
        for i in (low ? 0..<5 : 1..<6) { rest[i] -= 1 }
        guard let r = compute(rest), let full = compute(counts) else { return false }
        return (low ? 10 : 15) + r == full
    }
}
