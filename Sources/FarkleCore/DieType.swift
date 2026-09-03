import Foundation

/// A kind of die in Kingdom Come: Deliverance 2, described by the relative weight of each face.
public struct DieType: Hashable, Sendable, Identifiable, Codable {
    public let name: String
    /// Relative weights for faces 1...6.
    public let weights: [Int]

    public var id: String { name }

    public init(name: String, weights: [Int]) {
        precondition(weights.count == 6, "a die needs six face weights")
        precondition(weights.reduce(0, +) > 0, "a die needs at least one positive weight")
        self.name = name
        self.weights = weights
    }

    public var totalWeight: Int { weights.reduce(0, +) }

    /// Probability of each face 1...6 (index 0 = face 1).
    public var probabilities: [Double] {
        let total = Double(totalWeight)
        return weights.map { Double($0) / total }
    }

    public func probability(ofFace face: Int) -> Double {
        probabilities[face - 1]
    }

    public var isOrdinary: Bool { name == DieType.ordinary.name }

    /// True when every face is equally likely (behaves exactly like an ordinary die).
    public var isUniform: Bool { Set(weights).count == 1 }

    public static let ordinary = DieType(name: "Ordinary die", weights: [1, 1, 1, 1, 1, 1])

    /// Every die in the game, in alphabetical order, from the KCD2 dice weight table.
    public static let catalog: [DieType] = [
        DieType(name: "Aranka's die", weights: [6, 1, 6, 1, 6, 1]),
        DieType(name: "Cautious cheater's die", weights: [5, 3, 2, 3, 5, 3]),
        DieType(name: "Ci die", weights: [3, 3, 3, 3, 3, 6]),
        DieType(name: "Devil's head die", weights: [1, 1, 1, 1, 1, 1]),
        DieType(name: "Die of misfortune", weights: [1, 5, 5, 5, 5, 1]),
        DieType(name: "Even die", weights: [2, 8, 2, 8, 2, 8]),
        DieType(name: "Favourable die", weights: [6, 0, 1, 1, 6, 4]),
        DieType(name: "Fer die", weights: [3, 3, 3, 3, 3, 5]),
        DieType(name: "Greasy die", weights: [3, 2, 3, 2, 3, 4]),
        DieType(name: "Grimy die", weights: [1, 5, 1, 1, 7, 1]),
        DieType(name: "Grozav's lucky die", weights: [1, 10, 1, 1, 1, 1]),
        DieType(name: "Heavenly Kingdom die", weights: [7, 2, 2, 2, 2, 4]),
        DieType(name: "Holy Trinity die", weights: [4, 5, 7, 1, 1, 1]),
        DieType(name: "Hugo's Die", weights: [1, 1, 1, 1, 1, 1]),
        DieType(name: "King's die", weights: [4, 6, 7, 8, 4, 3]),
        DieType(name: "Lousy gambler's die", weights: [2, 3, 2, 3, 7, 3]),
        DieType(name: "Lu die", weights: [3, 3, 3, 3, 3, 6]),
        DieType(name: "Lucky Die", weights: [6, 1, 2, 3, 4, 6]),
        DieType(name: "Mathematician's Die", weights: [4, 5, 6, 7, 1, 1]),
        DieType(name: "Molar die", weights: [1, 1, 1, 1, 1, 1]),
        DieType(name: "Mother-of-pearl die", weights: [3, 1, 1, 1, 3, 3]),
        DieType(name: "Odd die", weights: [8, 2, 8, 2, 8, 2]),
        DieType.ordinary,
        DieType(name: "Painted die", weights: [3, 1, 1, 1, 6, 3]),
        DieType(name: "Painter's die B", weights: [1, 3, 2, 2, 2, 1]),
        DieType(name: "Painter's die G", weights: [1, 3, 2, 2, 2, 1]),
        DieType(name: "Painter's die R", weights: [1, 3, 2, 2, 2, 1]),
        DieType(name: "Pie die", weights: [6, 1, 3, 3, 0, 0]),
        DieType(name: "Premolar die", weights: [1, 1, 1, 1, 1, 1]),
        DieType(name: "Sad Greaser's Die", weights: [6, 6, 1, 1, 6, 3]),
        DieType(name: "Saint Antiochus' die", weights: [3, 1, 6, 1, 1, 3]),
        DieType(name: "Shrinking die", weights: [2, 1, 1, 1, 1, 3]),
        DieType(name: "St. Stephen's die", weights: [1, 1, 1, 1, 1, 1]),
        DieType(name: "Strip die", weights: [4, 2, 2, 2, 3, 3]),
        DieType(name: "Three die", weights: [2, 1, 4, 1, 2, 1]),
        DieType(name: "Unbalanced Die", weights: [3, 4, 1, 1, 2, 1]),
        DieType(name: "Unlucky die", weights: [1, 3, 2, 2, 2, 1]),
        DieType(name: "Wagoner's Die", weights: [1, 5, 6, 2, 2, 2]),
        DieType(name: "Weighted die", weights: [10, 1, 1, 1, 1, 1]),
        DieType(name: "Wisdom tooth die", weights: [1, 1, 1, 1, 1, 1]),
    ]

    public static func named(_ name: String) -> DieType? {
        catalog.first { $0.name == name }
    }
}
