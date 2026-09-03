import Foundation

/// Win probabilities for a race to `goal` units between "me" and an opponent.
public struct WinTable: Sendable {
    public let goal: Int
    /// meToMove[i * goal + j]: probability I win when I am about to roll with my score i, opponent j.
    let meToMove: [Double]
    /// oppToMove[j * goal + i]: probability the OPPONENT wins when they are about to roll.
    let oppToMove: [Double]

    /// Probability that I win, given my score `i` and opponent score `j` (units) and whose turn it is.
    public func probabilityIWin(myScore i: Int, oppScore j: Int, myTurn: Bool) -> Double {
        if i >= goal { return 1 }
        if j >= goal { return 0 }
        return myTurn ? meToMove[i * goal + j] : 1 - oppToMove[j * goal + i]
    }
}

public enum GameSolver {
    public static func solve(me: TurnModel, opponent: TurnModel, goal G: Int) -> WinTable {
        precondition(G >= 1)
        let dMe = TurnSolver.distributions(model: me, goal: G)
        let dOpp = TurnSolver.distributions(model: opponent, goal: G)
        var pMe = [Double](repeating: 0, count: G * G)
        var pOpp = [Double](repeating: 0, count: G * G)
        for i in stride(from: G - 1, through: 0, by: -1) {
            let c = G - i
            let dm = dMe[c]!
            for j in stride(from: G - 1, through: 0, by: -1) {
                let c2 = G - j
                let dop = dOpp[c2]!
                // My successful turns: bank x < c leaves opponent to move at (j, i + x).
                var a0 = dm.win
                for x in 1..<c { a0 += dm.banked[x] * (1 - pOpp[j * G + (i + x)]) }
                var b0 = dop.win
                for x in 1..<c2 { b0 += dop.banked[x] * (1 - pMe[i * G + (j + x)]) }
                let alpha = dm.bust, beta = dop.bust
                let a = (a0 + alpha - alpha * b0 - alpha * beta) / (1 - alpha * beta)
                let b = b0 + beta * (1 - a)
                pMe[i * G + j] = a
                pOpp[j * G + i] = b
            }
        }
        return WinTable(goal: G, meToMove: pMe, oppToMove: pOpp)
    }
}
