import Foundation

public struct SetCandidate: Sendable, Identifiable {
    public var id: String { self.set.summary }
    public let set: DiceSet
    /// Expected points banked per turn from a fresh roll (goal-capped).
    public let expectedTurnScore: Double
    /// Probability the opening roll of six busts.
    public let openingBust: Double
    /// Probability of beating an ordinary-dice opponent from 0-0, rolling first.
    public var winProbability: Double?
}

public enum SetOptimizer {
    /// Above this many candidate sets, the search is narrowed to the strongest individual dice.
    public static let exhaustiveLimit = 600
    /// How many distinct die kinds survive the narrowing.
    public static let narrowedKinds = 8

    /// Every distinct set buildable from the inventory (non-uniform special dice only), ordinary fill.
    /// Large inventories are narrowed to the `narrowedKinds` dice with the best solo value.
    public static func candidates(inventory: [DieType: Int], goal: Int = 2000) -> [DiceSet] {
        var types = inventory
            .filter { $0.value > 0 && !$0.key.isUniform }
            .map { (type: $0.key, count: min($0.value, 6)) }
            .sorted { $0.type.name < $1.type.name }
        if countSets(types.map(\.count)) > exhaustiveLimit {
            let G = max(1, goal / Scoring.unit)
            let solo = types.map { t -> Double in
                let m = TurnModel(set: DiceSet(filling: [t.type]))
                return TurnSolver.solveExpectedScore(model: m, cap: G).value(t: 0, state: m.fullState)
            }
            let keep = Set(solo.indices.sorted { solo[$0] > solo[$1] }.prefix(narrowedKinds))
            types = types.indices.filter { keep.contains($0) }.map { types[$0] }
        }
        var sets: [DiceSet] = []
        var chosen: [DieType] = []
        func rec(_ i: Int) {
            if i == types.count { sets.append(DiceSet(filling: chosen)); return }
            let room = 6 - chosen.count
            for n in 0...min(room, types[i].count) {
                if n > 0 { chosen.append(contentsOf: Array(repeating: types[i].type, count: n)) }
                rec(i + 1)
                if n > 0 { chosen.removeLast(n) }
            }
        }
        rec(0)
        // Sets whose dice have identical weights are equivalent; keep one of each.
        var seenWeights: Set<[[Int]]> = []
        return sets.filter { seenWeights.insert($0.dice.map(\.weights)).inserted }
    }

    /// Number of ways to pick at most six dice given per-kind counts.
    static func countSets(_ counts: [Int]) -> Int {
        var ways = [Int](repeating: 0, count: 7); ways[0] = 1
        for c in counts {
            var next = [Int](repeating: 0, count: 7)
            for used in 0...6 where ways[used] > 0 {
                for n in 0...min(c, 6 - used) { next[used + n] += ways[used] }
            }
            ways = next
        }
        return ways.reduce(0, +)
    }

    /// Ranks sets: all candidates by expected turn score, then the best `topK` re-ranked by win probability.
    public static func rank(inventory: [DieType: Int], goal goalPoints: Int, topK: Int = 8,
                            progress: (@Sendable (Double) -> Void)? = nil) -> [SetCandidate] {
        let G = max(1, goalPoints / Scoring.unit)
        let sets = candidates(inventory: inventory, goal: goalPoints)
        var scored = [SetCandidate?](repeating: nil, count: sets.count)
        let lock = NSLock()
        var done = 0
        DispatchQueue.concurrentPerform(iterations: sets.count) { idx in
            let model = TurnModel(set: sets[idx])
            let table = TurnSolver.solveExpectedScore(model: model, cap: G)
            let c = SetCandidate(set: sets[idx],
                                 expectedTurnScore: table.value(t: 0, state: model.fullState) * Double(Scoring.unit),
                                 openingBust: model.bustProbability[model.fullState])
            lock.lock()
            scored[idx] = c
            done += 1
            let frac = Double(done) / Double(sets.count) * 0.6
            lock.unlock()
            progress?(frac)
        }
        var ranked = scored.compactMap { $0 }.sorted { $0.expectedTurnScore > $1.expectedTurnScore }
        let top = Array(ranked.prefix(topK))
        ranked = []
        let opponent = TurnModel(set: .allOrdinary)
        var withWin = [SetCandidate?](repeating: nil, count: top.count)
        var done2 = 0
        DispatchQueue.concurrentPerform(iterations: top.count) { idx in
            var c = top[idx]
            let model = TurnModel(set: c.set)
            let table = GameSolver.solve(me: model, opponent: opponent, goal: G)
            c.winProbability = table.probabilityIWin(myScore: 0, oppScore: 0, myTurn: true)
            lock.lock()
            withWin[idx] = c
            done2 += 1
            let frac = 0.6 + Double(done2) / Double(top.count) * 0.4
            lock.unlock()
            progress?(frac)
        }
        return withWin.compactMap { $0 }.sorted { ($0.winProbability ?? 0) > ($1.winProbability ?? 0) }
    }
}
