import Foundation
import Observation
import FarkleCore

struct DieSlot: Equatable {
    var face: Int? = nil
    var held = false
}

enum Screen: String, CaseIterable, Identifiable {
    case bag = "Dice Bag"
    case table = "The Table"
    var id: String { rawValue }
}

@MainActor
@Observable
final class AppModel {
    // MARK: Dice bag
    var screen: Screen = .bag
    var inventory: [String: Int] { didSet { persist() } }
    var goal: Int { didSet { persist(); recomputeOdds() } }
    var candidates: [SetCandidate] = []
    var rankingProgress: Double? = nil
    var searchedSetCount = 0

    // MARK: Active set and odds
    private(set) var activeSet: DiceSet { didSet { persist() } }
    private(set) var turnModel: TurnModel?
    private(set) var winTable: WinTable?
    private var oddsGeneration = 0

    // MARK: Match state
    var myScore = 0 { didSet { refreshAdvice() } }
    var oppScore = 0 { didSet { refreshAdvice() } }
    var turnPoints = 0 { didSet { refreshAdvice() } }
    var slots: [DieSlot] = Array(repeating: DieSlot(), count: 6) { didSet { refreshAdvice() } }
    private(set) var advice: Advice?
    private var adviceGeneration = 0

    private let defaults = UserDefaults.standard
    private var demoMode = false

    init() {
        let storedInventory = (defaults.dictionary(forKey: "inventory") as? [String: Int]) ?? [:]
        inventory = storedInventory.filter { DieType.named($0.key) != nil }
        let g = defaults.integer(forKey: "goal")
        goal = g > 0 ? g : 2000
        let names = defaults.stringArray(forKey: "activeSet") ?? []
        let dice = names.compactMap { DieType.named($0) }
        activeSet = dice.count == 6 ? DiceSet(dice) : .allOrdinary
        recomputeOdds()
        if let demo = ProcessInfo.processInfo.environment["FARKLE_DEMO"] { loadDemo(startOnBag: demo == "bag") }
    }

    /// Populated state for screenshots and manual testing (FARKLE_DEMO=1 or FARKLE_DEMO=bag).
    private func loadDemo(startOnBag: Bool) {
        demoMode = true
        inventory = ["Weighted die": 1, "Pie die": 2, "Favourable die": 1, "Odd die": 1, "Heavenly Kingdom die": 1, "Hugo's Die": 1]
        activeSet = DiceSet(filling: ["Weighted die", "Pie die", "Pie die", "Favourable die"].compactMap { DieType.named($0) })
        myScore = 650
        oppScore = 1200
        screen = .table
        slots = [DieSlot(face: 1), DieSlot(face: 3), DieSlot(face: 4), DieSlot(face: 5), DieSlot(face: 2), DieSlot(face: 2)]
        recomputeOdds()
        if startOnBag { screen = .bag; rankSets() }
    }

    private func persist() {
        guard !demoMode else { return }
        defaults.set(inventory, forKey: "inventory")
        defaults.set(goal, forKey: "goal")
        defaults.set(activeSet.dice.map(\.name), forKey: "activeSet")
    }

    // MARK: Inventory

    func count(of die: DieType) -> Int { inventory[die.name] ?? 0 }

    func setCount(_ n: Int, for die: DieType) {
        inventory[die.name] = max(0, min(6, n))
        if inventory[die.name] == 0 { inventory.removeValue(forKey: die.name) }
    }

    var ownedSpecialCount: Int { inventory.values.reduce(0, +) }

    func rankSets() {
        guard rankingProgress == nil else { return }
        rankingProgress = 0
        let inv: [DieType: Int] = Dictionary(uniqueKeysWithValues: inventory.compactMap { k, v in
            DieType.named(k).map { ($0, v) }
        })
        let goal = self.goal
        searchedSetCount = SetOptimizer.candidates(inventory: inv, goal: goal).count
        Task.detached(priority: .userInitiated) {
            let ranked = SetOptimizer.rank(inventory: inv, goal: goal, topK: 8) { frac in
                Task { @MainActor in self.rankingProgress = frac }
            }
            await MainActor.run {
                self.candidates = ranked
                self.rankingProgress = nil
            }
        }
    }

    // MARK: Active set

    func activate(_ set: DiceSet) {
        activeSet = set
        newTurn()
        recomputeOdds()
    }

    private func recomputeOdds() {
        oddsGeneration += 1
        let gen = oddsGeneration
        let set = activeSet
        let G = max(1, goal / Scoring.unit)
        turnModel = nil
        winTable = nil
        advice = nil
        Task.detached(priority: .userInitiated) {
            let model = TurnModel(set: set)
            let table = GameSolver.solve(me: model, opponent: TurnModel(set: .allOrdinary), goal: G)
            await MainActor.run {
                guard self.oddsGeneration == gen else { return }
                self.turnModel = model
                self.winTable = table
                self.refreshAdvice()
            }
        }
    }

    /// Probability of winning from the current scores at the start of my turn.
    var winChanceNow: Double? {
        winTable?.probabilityIWin(myScore: myScore / Scoring.unit, oppScore: oppScore / Scoring.unit, myTurn: true)
    }

    // MARK: Match

    var rolledPositions: [Int] { slots.indices.filter { !slots[$0].held } }
    var allHeld: Bool { rolledPositions.isEmpty }
    var rollIsComplete: Bool { rolledPositions.allSatisfy { slots[$0].face != nil } }

    func cycleFace(at position: Int) {
        let f = slots[position].face ?? 0
        slots[position].face = f % 6 + 1
    }

    func toggleHeld(at position: Int) {
        slots[position].held.toggle()
    }

    func newTurn() {
        turnPoints = 0
        slots = Array(repeating: DieSlot(), count: 6)
    }

    func bank() {
        myScore += turnPoints
        newTurn()
    }

    func bust() { newTurn() }

    /// Hot dice: keep the turn points and put all six dice back on the table.
    func rollAllSix() {
        slots = Array(repeating: DieSlot(), count: 6)
    }

    /// Hold the recommended dice and add their points to the turn.
    func applyBest() {
        guard let best = advice?.best else { return }
        if best.hotDice && best.positions.isEmpty { rollAllSix(); return }
        var s = slots
        for p in best.positions { s[p].held = true }
        // Clear the faces of dice that stay on the table; they are about to be rolled again.
        for p in s.indices where !s[p].held { s[p].face = nil }
        turnPoints += best.points
        slots = s
    }

    private func refreshAdvice() {
        adviceGeneration += 1
        let gen = adviceGeneration
        guard let model = turnModel, let table = winTable, rollIsComplete else { advice = nil; return }
        let rolled = rolledPositions.map { RolledDie(position: $0, face: slots[$0].face!) }
        let (i, j, t) = (myScore, oppScore, turnPoints)
        Task.detached(priority: .userInitiated) {
            let a = RollAdvisor.advise(model: model, winTable: table, myScore: i, oppScore: j, turnPoints: t, rolled: rolled)
            await MainActor.run {
                guard self.adviceGeneration == gen else { return }
                self.advice = a
            }
        }
    }
}
