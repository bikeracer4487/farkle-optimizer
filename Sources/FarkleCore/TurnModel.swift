import Foundation

/// A single legal way to respond to a roll: hold some dice worth `units` and be left with `next`.
/// `next == 0` (no dice left) means hot dice: the player rolls all six again.
public struct RollOption: Hashable, Sendable {
    public let next: Int32
    public let units: Int32
}

/// All roll outcomes that offer exactly the same options, merged.
public struct OutcomeGroup: Sendable {
    public let probability: Double
    /// Sorted, deduplicated. Empty means the roll busted.
    public let options: [RollOption]
}

/// Precomputed roll structure for a six-die set. Dice with identical face weights are
/// interchangeable, so a "state" is just how many dice of each kind remain to be rolled.
public struct TurnModel: Sendable {
    public let set: DiceSet
    /// Distinct face-weight kinds in the set.
    public let kinds: [DieType]
    /// Kind index of each die in `set.dice`.
    public let kindOfDie: [Int]
    /// How many dice of each kind the full set has.
    public let kindCounts: [Int]
    let radix: [Int]
    public let stateCount: Int
    public let fullState: Int
    /// Indexed by state. Index 0 (no dice) is empty.
    public let outcomes: [[OutcomeGroup]]
    public let bustProbability: [Double]
    public let diceRemaining: [Int]

    public init(set: DiceSet) {
        self.set = set
        var kinds: [DieType] = []
        var kindOfDie: [Int] = []
        var kindCounts: [Int] = []
        for die in set.dice {
            if let k = kinds.firstIndex(where: { $0.weights == die.weights }) {
                kindOfDie.append(k)
                kindCounts[k] += 1
            } else {
                kinds.append(die)
                kindOfDie.append(kinds.count - 1)
                kindCounts.append(1)
            }
        }
        self.kinds = kinds
        self.kindOfDie = kindOfDie
        self.kindCounts = kindCounts
        var radix: [Int] = []
        var r = 1
        for c in kindCounts { radix.append(r); r *= (c + 1) }
        self.radix = radix
        self.stateCount = r
        self.fullState = r - 1

        let combos: [[[(counts: FaceCounts, prob: Double)]]] = kinds.enumerated().map { (k, die) in
            (0...kindCounts[k]).map { n in TurnModel.faceCombos(die: die, n: n) }
        }

        var outcomes: [[OutcomeGroup]] = Array(repeating: [], count: r)
        var bust = [Double](repeating: 1, count: r)
        var remaining = [Int](repeating: 0, count: r)
        for state in 1..<r {
            let counts = TurnModel.decode(state, radix: radix, kindCounts: kindCounts)
            remaining[state] = counts.reduce(0, +)
            let groups = TurnModel.enumerate(state: state, counts: counts, combos: combos, radix: radix, kindCounts: kindCounts)
            outcomes[state] = groups
            bust[state] = groups.first { $0.options.isEmpty }?.probability ?? 0
        }
        self.outcomes = outcomes
        self.bustProbability = bust
        self.diceRemaining = remaining
    }

    // MARK: State encoding

    public func stateIndex(kindCounts counts: [Int]) -> Int {
        var s = 0
        for (k, c) in counts.enumerated() { s += c * radix[k] }
        return s
    }

    public func kindCounts(of state: Int) -> [Int] {
        TurnModel.decode(state, radix: radix, kindCounts: kindCounts)
    }

    /// State reached when the dice at the given positions of `set.dice` are still unrolled.
    public func state(remainingDice positions: [Int]) -> Int {
        var counts = [Int](repeating: 0, count: kinds.count)
        for p in positions { counts[kindOfDie[p]] += 1 }
        return stateIndex(kindCounts: counts)
    }

    static func decode(_ state: Int, radix: [Int], kindCounts: [Int]) -> [Int] {
        var counts = [Int](repeating: 0, count: kindCounts.count)
        var s = state
        for k in stride(from: kindCounts.count - 1, through: 0, by: -1) {
            counts[k] = s / radix[k]
            s %= radix[k]
        }
        return counts
    }

    // MARK: Enumeration

    /// Every face-count vector for `n` dice of one kind, with its probability.
    static func faceCombos(die: DieType, n: Int) -> [(counts: FaceCounts, prob: Double)] {
        let p = die.probabilities
        var result: [(FaceCounts, Double)] = []
        var counts = [Int](repeating: 0, count: 6)
        func rec(_ face: Int, _ left: Int, _ prob: Double, _ ways: Double, _ placed: Int) {
            if face == 5 {
                counts[5] = left
                if left > 0 && p[5] == 0 { return }
                // multinomial coefficient = n! / prod(c!) accumulated as binomials
                let w = ways * binomial(placed + left, left)
                result.append((counts, w * prob * pow(p[5], Double(left))))
                return
            }
            for c in 0...left {
                if c > 0 && p[face] == 0 { break }
                counts[face] = c
                rec(face + 1, left - c, prob * pow(p[face], Double(c)), ways * binomial(placed + c, c), placed + c)
            }
            counts[face] = 0
        }
        rec(0, n, 1, 1, 0)
        return result.map { (counts: $0.0, prob: $0.1) }
    }

    static func binomial(_ n: Int, _ k: Int) -> Double {
        if k == 0 || k == n { return 1 }
        var r = 1.0
        for i in 1...k { r = r * Double(n - k + i) / Double(i) }
        return r
    }

    /// Option-set groups for one state.
    static func enumerate(state: Int, counts: [Int], combos: [[[(counts: FaceCounts, prob: Double)]]],
                          radix: [Int], kindCounts: [Int]) -> [OutcomeGroup] {
        var e = OutcomeEnumerator(counts: counts, combos: combos, radix: radix)
        e.run()
        return e.groupProb.map { OutcomeGroup(probability: $0.value, options: $0.key) }
            .sorted { $0.probability > $1.probability }
    }
}

/// Closure-free enumeration of every roll outcome of a state and the options it offers.
private struct OutcomeEnumerator {
    let counts: [Int]
    let combos: [[[(counts: FaceCounts, prob: Double)]]]
    let radix: [Int]
    let kindCount: Int
    var perKind: [FaceCounts]
    var total = [Int](repeating: 0, count: 6)
    var sel = [Int](repeating: 0, count: 6)
    var removed: [Int]
    /// best units per next state for the current outcome; -1 = none
    var best: [Int32]
    var touched: [Int32] = []
    var optionsBuffer: [RollOption] = []
    var groupProb: [[RollOption]: Double] = [:]

    init(counts: [Int], combos: [[[(counts: FaceCounts, prob: Double)]]], radix: [Int]) {
        self.counts = counts
        self.combos = combos
        self.radix = radix
        self.kindCount = counts.count
        self.perKind = Array(repeating: [], count: counts.count)
        self.removed = [Int](repeating: 0, count: counts.count)
        var n = 1
        for (k, c) in counts.enumerated() { n += c * radix[k] }
        self.best = [Int32](repeating: -1, count: n)
        touched.reserveCapacity(64)
    }

    mutating func run() { outcome(kind: 0, prob: 1) }

    private mutating func outcome(kind k: Int, prob: Double) {
        if k == kindCount { finish(prob); return }
        for combo in combos[k][counts[k]] {
            perKind[k] = combo.counts
            outcome(kind: k + 1, prob: prob * combo.prob)
        }
    }

    private mutating func finish(_ prob: Double) {
        for f in 0..<6 {
            var t = 0
            for k in 0..<kindCount { t += perKind[k][f] }
            total[f] = t
        }
        selectFaces(0)
        optionsBuffer.removeAll(keepingCapacity: true)
        for next in touched {
            optionsBuffer.append(RollOption(next: next, units: best[Int(next)]))
            best[Int(next)] = -1
        }
        touched.removeAll(keepingCapacity: true)
        optionsBuffer.sort()
        groupProb[optionsBuffer, default: 0] += prob
    }

    private mutating func selectFaces(_ f: Int) {
        if f == 6 {
            guard let units = Scoring.scoreUnits(sel), units > 0 else { return }
            distribute(face: 0, units: Int32(units))
            return
        }
        for c in 0...total[f] { sel[f] = c; selectFaces(f + 1) }
        sel[f] = 0
    }

    private mutating func distribute(face f: Int, units: Int32) {
        if f == 6 {
            var next = 0
            for k in 0..<kindCount { next += (counts[k] - removed[k]) * radix[k] }
            let old = best[next]
            if old < 0 { touched.append(Int32(next)); best[next] = units }
            else if units > old { best[next] = units }
            return
        }
        if sel[f] == 0 { distribute(face: f + 1, units: units); return }
        assign(kind: 0, face: f, left: sel[f], units: units)
    }

    private mutating func assign(kind k: Int, face f: Int, left: Int, units: Int32) {
        if k == kindCount { if left == 0 { distribute(face: f + 1, units: units) }; return }
        let avail = perKind[k][f]
        for take in 0...min(avail, left) {
            removed[k] += take
            assign(kind: k + 1, face: f, left: left - take, units: units)
            removed[k] -= take
        }
    }
}

extension RollOption: Comparable {
    public static func < (a: RollOption, b: RollOption) -> Bool { (a.next, a.units) < (b.next, b.units) }
}
