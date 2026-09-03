import Foundation
import FarkleCore

// Quick timing harness: `swift run -c release farkle-bench [goal]`
let goal = Int(CommandLine.arguments.dropFirst().first ?? "4000") ?? 4000
let G = goal / 50
func time<T>(_ label: String, _ body: () -> T) -> T {
    let t = Date()
    let r = body()
    print(String(format: "%@: %.3fs", label, Date().timeIntervalSince(t)))
    return r
}
let names = ["Weighted die", "Pie die", "Favourable die", "Odd die", "Heavenly Kingdom die", "Saint Antiochus' die"]
let hard = DiceSet(names.map { DieType.named($0)! })
let model = time("model (6 distinct)") { TurnModel(set: hard) }
print("states \(model.stateCount), groups \(model.outcomes.reduce(0) { $0 + $1.count }), options \(model.outcomes.reduce(0) { $0 + $1.reduce(0) { $0 + $1.options.count } })")
let table = time("expected-score DP") { TurnSolver.solveExpectedScore(model: model, cap: G) }
print("E[turn] = \(table.value(t: 0, state: model.fullState) * 50)")
let ordinary = TurnModel(set: .allOrdinary)
let win = time("win table vs ordinary") { GameSolver.solve(me: model, opponent: ordinary, goal: G) }
print("P(win from 0-0) = \(win.probabilityIWin(myScore: 0, oppScore: 0, myTurn: true))")
let rolled = (0..<6).map { RolledDie(position: $0, face: [1, 2, 3, 4, 5, 6][$0]) }
let advice = time("advice") { RollAdvisor.advise(model: model, winTable: win, myScore: 500, oppScore: 900, turnPoints: 0, rolled: rolled) }
print("best: \(advice.best!.description) -> \(advice.best!.bestAction.rawValue)")
let inv: [DieType: Int] = Dictionary(uniqueKeysWithValues: DieType.catalog.filter { !$0.isUniform }.prefix(10).map { ($0, 1) })
print("candidates: \(SetOptimizer.candidates(inventory: inv).count)")
let ranked = time("rank 10-die inventory") { SetOptimizer.rank(inventory: inv, goal: goal) }
for c in ranked { print(String(format: "  %.1f%%  E=%.0f  bust=%.1f%%  %@", (c.winProbability ?? 0) * 100, c.expectedTurnScore, c.openingBust * 100, c.set.summary)) }
