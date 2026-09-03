import Foundation

/// Backward-induction values for one player's turn: `value(t, state)` is the expected reward
/// when the turn total is `t` units and `state` dice remain to be rolled.
public struct ValueTable: Sendable {
    public let cap: Int
    public let stateCount: Int
    /// Reward for banking a turn total of x units, x in 0...cap (index cap = reached the goal).
    public let bankReward: [Double]
    public let bustReward: Double
    /// values[t * stateCount + state] for t in 0..<cap
    public let values: [Double]

    @inline(__always)
    public func value(t: Int, state: Int) -> Double { values[t * stateCount + state] }
}

/// Distribution of a turn's banked result when the player needs `cap` units to win.
public struct TurnDistribution: Sendable {
    public let cap: Int
    public let bust: Double
    /// banked[x] for 1 <= x < cap (index 0 unused)
    public let banked: [Double]
    /// Probability the turn reaches the goal.
    public let win: Double

    public var expectedUnits: Double {
        var e = 0.0
        for x in 1..<cap { e += Double(x) * banked[x] }
        return e + Double(cap) * win
    }
}

public enum TurnSolver {
    /// Solves the turn for a generic terminal reward. `bankReward(x)` receives x clamped to `cap`.
    public static func solve(model: TurnModel, cap: Int, bustReward: Double,
                             bankReward: (Int) -> Double) -> ValueTable {
        precondition(cap >= 1)
        let n = model.stateCount
        let full = model.fullState
        let bank = (0...cap).map(bankReward)
        var values = [Double](repeating: 0, count: cap * n)
        values.withUnsafeMutableBufferPointer { v in
            for t in stride(from: cap - 1, through: 0, by: -1) {
                for state in 1..<n {
                    var total = 0.0
                    for group in model.outcomes[state] {
                        if group.options.isEmpty { total += group.probability * bustReward; continue }
                        var best = -Double.infinity
                        for o in group.options {
                            let x = t + Int(o.units)
                            var val: Double
                            if x >= cap {
                                val = bank[cap]
                            } else {
                                val = bank[x]
                                let next = o.next == 0 ? full : Int(o.next)
                                let cont = v[x * n + next]
                                if cont > val { val = cont }
                            }
                            if val > best { best = val }
                        }
                        total += group.probability * best
                    }
                    v[t * n + state] = total
                }
            }
        }
        return ValueTable(cap: cap, stateCount: n, bankReward: bank, bustReward: bustReward, values: values)
    }

    /// Expected-score objective: bank reward is the banked total itself (capped at the goal).
    public static func solveExpectedScore(model: TurnModel, cap: Int) -> ValueTable {
        solve(model: model, cap: cap, bustReward: 0) { Double($0) }
    }

    /// Forward pass: follows the policy implied by `table` but banks immediately whenever a hold
    /// can reach `cap` units, and returns the distribution of the banked result.
    public static func distribution(model: TurnModel, table: ValueTable, cap: Int,
                                    startState: Int? = nil, startT: Int = 0) -> TurnDistribution {
        precondition(cap >= 1 && cap <= table.cap)
        let n = model.stateCount
        let full = model.fullState
        let start = startState ?? full
        var mass = [Double](repeating: 0, count: cap * n)
        var banked = [Double](repeating: 0, count: cap)
        var bust = 0.0
        var win = 0.0
        if startT >= cap { return TurnDistribution(cap: cap, bust: 0, banked: banked, win: 1) }
        mass[startT * n + start] = 1
        let bank = table.bankReward
        for t in startT..<cap {
            for state in 1..<n {
                let m = mass[t * n + state]
                if m == 0 { continue }
                for group in model.outcomes[state] {
                    let p = m * group.probability
                    if group.options.isEmpty { bust += p; continue }
                    var xMax = 0
                    for o in group.options { xMax = max(xMax, t + Int(o.units)) }
                    if xMax >= cap { win += p; continue }
                    var bestVal = -Double.infinity
                    var bestX = 0
                    var bestNext = -1   // -1 = bank
                    for o in group.options {
                        let x = t + Int(o.units)
                        let next = o.next == 0 ? full : Int(o.next)
                        let b = bank[x]
                        let c = table.value(t: x, state: next)
                        if b >= c {
                            if b > bestVal { bestVal = b; bestX = x; bestNext = -1 }
                        } else if c > bestVal { bestVal = c; bestX = x; bestNext = next }
                    }
                    if bestNext < 0 { banked[bestX] += p } else { mass[bestX * n + bestNext] += p }
                }
            }
        }
        return TurnDistribution(cap: cap, bust: bust, banked: banked, win: win)
    }

    /// Distributions for every cap 1...goal, computed in parallel.
    public static func distributions(model: TurnModel, goal: Int) -> [TurnDistribution?] {
        let table = solveExpectedScore(model: model, cap: goal)
        var result = [TurnDistribution?](repeating: nil, count: goal + 1)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: goal) { i in
            let cap = goal - i   // big caps first for better load balance
            let d = distribution(model: model, table: table, cap: cap)
            lock.lock(); result[cap] = d; lock.unlock()
        }
        return result
    }
}
