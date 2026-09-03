import XCTest
@testable import FarkleCore

final class SolverTests: XCTestCase {
    func testOrdinaryModelStates() {
        let m = TurnModel(set: .allOrdinary)
        XCTAssertEqual(m.kinds.count, 1)
        XCTAssertEqual(m.stateCount, 7)
        XCTAssertEqual(m.fullState, 6)
        for s in 1...6 {
            let mass = m.outcomes[s].reduce(0) { $0 + $1.probability }
            XCTAssertEqual(mass, 1, accuracy: 1e-9, "state \(s)")
        }
        // One ordinary die: scores on a 1 or a 5.
        XCTAssertEqual(m.bustProbability[1], 4.0 / 6.0, accuracy: 1e-9)
        // Six ordinary dice bust when only 2/3/4/6 show with no triple: 1440/46656 (no three-pairs rule).
        XCTAssertEqual(m.bustProbability[6], 1440.0 / 46656.0, accuracy: 1e-9)
    }

    func testMixedModelMassAndHotDice() {
        let set = DiceSet(filling: [DieType.named("Weighted die")!, DieType.named("Pie die")!, DieType.named("Pie die")!])
        let m = TurnModel(set: set)
        XCTAssertEqual(m.kinds.count, 3)
        XCTAssertEqual(m.stateCount, 2 * 3 * 4)
        for s in 1..<m.stateCount {
            let mass = m.outcomes[s].reduce(0) { $0 + $1.probability }
            XCTAssertEqual(mass, 1, accuracy: 1e-9)
        }
        // Rolling only the Weighted die: hot dice option with 2 units (a 1) exists.
        let weightedPos = set.dice.firstIndex { $0.name == "Weighted die" }!
        let weightedOnly = m.state(remainingDice: [weightedPos])
        let groups = m.outcomes[weightedOnly]
        let one = groups.first { $0.options.contains(RollOption(next: 0, units: 2)) }
        XCTAssertNotNil(one)
        XCTAssertEqual(one!.probability, 10.0 / 15.0, accuracy: 1e-9)
    }

    func testExpectedScoreIsReasonableAndWeightedIsBetter() {
        let ordinary = TurnModel(set: .allOrdinary)
        let t = TurnSolver.solveExpectedScore(model: ordinary, cap: 200)
        let e = t.value(t: 0, state: ordinary.fullState) * 50
        XCTAssertGreaterThan(e, 350)
        XCTAssertLessThan(e, 750)
        let weighted = TurnModel(set: DiceSet(filling: Array(repeating: DieType.named("Weighted die")!, count: 6)))
        let tw = TurnSolver.solveExpectedScore(model: weighted, cap: 200)
        XCTAssertGreaterThan(tw.value(t: 0, state: weighted.fullState) * 50, e * 2)
    }

    func testDistributionMassConservation() {
        let m = TurnModel(set: .allOrdinary)
        let table = TurnSolver.solveExpectedScore(model: m, cap: 40)
        for cap in [1, 5, 20, 40] {
            let d = TurnSolver.distribution(model: m, table: table, cap: cap)
            let total = d.bust + d.win + (1..<cap).reduce(0) { $0 + d.banked[$1] }
            XCTAssertEqual(total, 1, accuracy: 1e-9, "cap \(cap)")
        }
        let d1 = TurnSolver.distribution(model: m, table: table, cap: 1)
        XCTAssertEqual(d1.win, 1 - m.bustProbability[6], accuracy: 1e-9)
    }

    func testWinTableSymmetricGame() {
        let m = TurnModel(set: .allOrdinary)
        let w = GameSolver.solve(me: m, opponent: m, goal: 40)
        let first = w.probabilityIWin(myScore: 0, oppScore: 0, myTurn: true)
        XCTAssertGreaterThan(first, 0.5)
        XCTAssertLessThan(first, 0.65)
        // Symmetric players: P(me wins | my turn) == 1 - P(opp wins | their turn) at mirrored scores.
        let a = w.probabilityIWin(myScore: 10, oppScore: 20, myTurn: true)
        let b = 1 - w.probabilityIWin(myScore: 20, oppScore: 10, myTurn: false)
        XCTAssertEqual(a, b, accuracy: 1e-9)
        // Being ahead is better.
        XCTAssertGreaterThan(w.probabilityIWin(myScore: 30, oppScore: 0, myTurn: true),
                             w.probabilityIWin(myScore: 0, oppScore: 30, myTurn: true))
        // Near the goal, win probability approaches 1.
        XCTAssertGreaterThan(w.probabilityIWin(myScore: 39, oppScore: 0, myTurn: true), 0.95)
    }

    func testAdvisorBanksWhenBankWins() {
        let m = TurnModel(set: .allOrdinary)
        let w = GameSolver.solve(me: m, opponent: m, goal: 40)
        // 1900 points, need 100: roll shows a 1.
        let rolled = [RolledDie(position: 0, face: 1), RolledDie(position: 1, face: 2), RolledDie(position: 2, face: 3),
                      RolledDie(position: 3, face: 4), RolledDie(position: 4, face: 6), RolledDie(position: 5, face: 6)]
        let a = RollAdvisor.advise(model: m, winTable: w, myScore: 1900, oppScore: 0, turnPoints: 0, rolled: rolled)
        XCTAssertEqual(a.best?.bestAction, .scoreAndPass)
        XCTAssertEqual(a.best?.passWin, 1)
        XCTAssertEqual(a.best?.positions, [0])
    }

    func testAdvisorPrefersContinuingEarlyWithSmallHold() {
        let m = TurnModel(set: .allOrdinary)
        let w = GameSolver.solve(me: m, opponent: m, goal: 60)
        // Opening roll with one 1 and junk: hold the 1 and keep rolling.
        let rolled = [RolledDie(position: 0, face: 1), RolledDie(position: 1, face: 2), RolledDie(position: 2, face: 3),
                      RolledDie(position: 3, face: 4), RolledDie(position: 4, face: 6), RolledDie(position: 5, face: 6)]
        let a = RollAdvisor.advise(model: m, winTable: w, myScore: 0, oppScore: 0, turnPoints: 0, rolled: rolled)
        XCTAssertEqual(a.best?.positions, [0])
        XCTAssertEqual(a.best?.bestAction, .scoreAndContinue)
        // A bust roll is reported as such.
        let bust = [RolledDie(position: 0, face: 2), RolledDie(position: 1, face: 2), RolledDie(position: 2, face: 3),
                    RolledDie(position: 3, face: 4), RolledDie(position: 4, face: 6), RolledDie(position: 5, face: 6)]
        XCTAssertTrue(RollAdvisor.advise(model: m, winTable: w, myScore: 0, oppScore: 0, turnPoints: 0, rolled: bust).bustedRoll)
    }

    func testAdvisorHotDice() {
        let m = TurnModel(set: .allOrdinary)
        let w = GameSolver.solve(me: m, opponent: m, goal: 60)
        let a = RollAdvisor.advise(model: m, winTable: w, myScore: 0, oppScore: 0, turnPoints: 1500, rolled: [])
        XCTAssertEqual(a.evaluations.count, 1)
        XCTAssertTrue(a.best!.hotDice)
        XCTAssertNotNil(a.best!.continueWin)
    }

    func testSetOptimizerRanksWeightedAboveOrdinary() {
        let inv: [DieType: Int] = [DieType.named("Weighted die")!: 1, DieType.named("Hugo's Die")!: 1]
        let sets = SetOptimizer.candidates(inventory: inv)
        XCTAssertEqual(sets.count, 2) // ordinary only, and 1 weighted (Hugo's is uniform)
        let ranked = SetOptimizer.rank(inventory: inv, goal: 2000, topK: 4)
        XCTAssertEqual(ranked.first?.set.dice.first?.name, "Weighted die")
        XCTAssertGreaterThan(ranked.first!.winProbability!, ranked.last!.winProbability!)
    }
}
