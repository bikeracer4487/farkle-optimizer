import Foundation

/// A die lying on the table after a roll: its position in the set and the face it shows.
public struct RolledDie: Hashable, Sendable {
    public let position: Int
    public let face: Int
    public init(position: Int, face: Int) { self.position = position; self.face = face }
}

public enum TurnAction: String, Sendable {
    case scoreAndContinue = "Score and Continue"
    case scoreAndPass = "Score and Pass"
}

/// One legal response to the roll, evaluated.
public struct HoldEvaluation: Sendable, Identifiable {
    public var id: String { positions.map(String.init).joined(separator: ",") }
    /// Positions (in the set) of the dice to hold.
    public let positions: [Int]
    public let points: Int
    public let description: String
    /// Win probability if these dice are held and the turn is banked.
    public let passWin: Double
    /// Win probability if these dice are held and the rest are rolled again (nil when banking wins outright).
    public let continueWin: Double?
    /// Probability that the next roll busts, if continuing.
    public let bustIfContinue: Double
    public let diceLeftIfContinue: Int
    /// True when holding these dice means all six are held (roll all six again).
    public let hotDice: Bool

    public var bestAction: TurnAction {
        if let c = continueWin, c > passWin { return .scoreAndContinue }
        return .scoreAndPass
    }
    public var bestWin: Double { max(passWin, continueWin ?? 0) }
}

public struct Advice: Sendable {
    public let evaluations: [HoldEvaluation]      // best first
    public let bustedRoll: Bool
    /// Win probability from the start of the turn, for context.
    public let winBeforeRoll: Double
    public var best: HoldEvaluation? { evaluations.first }
}

public enum RollAdvisor {
    /// - Parameters:
    ///   - myScore, oppScore, goal: in points
    ///   - turnPoints: points already secured this turn (held dice)
    ///   - remainingPositions: positions in `model.set.dice` not yet held (the dice that were rolled)
    ///   - rolled: faces for exactly those positions. Empty means all six are held (hot dice question).
    public static func advise(model: TurnModel, winTable: WinTable, myScore: Int, oppScore: Int,
                              turnPoints: Int, rolled: [RolledDie]) -> Advice {
        let G = winTable.goal
        let i0 = myScore / Scoring.unit
        let j0 = oppScore / Scoring.unit
        let t0 = turnPoints / Scoring.unit
        let cap = max(1, G - i0)
        let bustReward = winTable.probabilityIWin(myScore: i0, oppScore: j0, myTurn: false)
        let bankReward: (Int) -> Double = { x in
            x >= cap ? 1 : winTable.probabilityIWin(myScore: i0 + x, oppScore: j0, myTurn: false)
        }
        let table = TurnSolver.solve(model: model, cap: cap, bustReward: bustReward, bankReward: bankReward)
        let full = model.fullState
        let winBefore = t0 < cap ? table.value(t: t0, state: full) : 1

        var evals: [HoldEvaluation] = []
        if rolled.isEmpty {
            // Hot dice: everything is held; roll all six or bank.
            let pass = bankReward(min(t0, cap))
            let cont: Double? = t0 < cap ? table.value(t: t0, state: full) : nil
            evals.append(HoldEvaluation(positions: [], points: 0, description: "all six dice held",
                                        passWin: pass, continueWin: cont,
                                        bustIfContinue: model.bustProbability[full],
                                        diceLeftIfContinue: 6, hotDice: true))
            return Advice(evaluations: evals, bustedRoll: false, winBeforeRoll: winBefore)
        }

        var seen: Set<RollOption> = []
        let n = rolled.count
        for mask in 1..<(1 << n) {
            var faces: [Int] = []
            var held: [Int] = []
            var leftPositions: [Int] = []
            for (k, die) in rolled.enumerated() {
                if mask & (1 << k) != 0 { faces.append(die.face); held.append(die.position) }
                else { leftPositions.append(die.position) }
            }
            let counts = Scoring.faceCounts(faces)
            guard let units = Scoring.scoreUnits(counts), units > 0 else { continue }
            var next = model.state(remainingDice: leftPositions)
            let hot = next == 0
            if hot { next = full }
            let key = RollOption(next: Int32(hot ? 0 : next), units: Int32(units))
            if !seen.insert(key).inserted { continue }
            let x = t0 + units
            let pass = bankReward(min(x, cap))
            let cont: Double? = x < cap ? table.value(t: x, state: next) : nil
            evals.append(HoldEvaluation(positions: held, points: units * Scoring.unit,
                                        description: Scoring.describe(counts),
                                        passWin: pass, continueWin: cont,
                                        bustIfContinue: model.bustProbability[next],
                                        diceLeftIfContinue: model.diceRemaining[next], hotDice: hot))
        }
        evals.sort { a, b in
            if a.bestWin != b.bestWin { return a.bestWin > b.bestWin }
            return a.points > b.points
        }
        return Advice(evaluations: evals, bustedRoll: evals.isEmpty, winBeforeRoll: winBefore)
    }
}
