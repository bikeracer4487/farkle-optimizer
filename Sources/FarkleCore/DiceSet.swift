import Foundation

/// The six dice a player brings to the table.
public struct DiceSet: Hashable, Sendable, Codable {
    /// Exactly six dice, kept in a canonical order (special dice first, alphabetical, ordinary last).
    public let dice: [DieType]

    public init(_ dice: [DieType]) {
        precondition(dice.count == 6, "a dice set has six dice")
        self.dice = dice.sorted { a, b in
            if a.isOrdinary != b.isOrdinary { return !a.isOrdinary }
            return a.name < b.name
        }
    }

    /// Builds a set from any number (0...6) of special dice, filling the rest with ordinary dice.
    public init(filling special: [DieType]) {
        precondition(special.count <= 6)
        self.init(special + Array(repeating: DieType.ordinary, count: 6 - special.count))
    }

    public static let allOrdinary = DiceSet(filling: [])

    /// Distinct dice with their multiplicity, in canonical order.
    public var grouped: [(type: DieType, count: Int)] {
        var result: [(type: DieType, count: Int)] = []
        for d in dice {
            if let last = result.last, last.type == d {
                result[result.count - 1].count += 1
            } else {
                result.append((d, 1))
            }
        }
        return result
    }

    public var summary: String {
        grouped.map { $0.count > 1 ? "\($0.count)× \($0.type.name)" : $0.type.name }.joined(separator: ", ")
    }
}
