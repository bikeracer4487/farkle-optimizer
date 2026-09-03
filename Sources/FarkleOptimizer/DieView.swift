import SwiftUI
import FarkleCore

/// A bone die with pips. `face == nil` draws a blank die.
struct DieView: View {
    var face: Int?
    var size: CGFloat = 64
    var special = false
    var highlighted = false
    var dimmed = false
    var placeholder = true

    private static let pips: [Int: [(CGFloat, CGFloat)]] = [
        1: [(0.5, 0.5)],
        2: [(0.25, 0.25), (0.75, 0.75)],
        3: [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
        4: [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)],
        5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
        6: [(0.25, 0.25), (0.75, 0.25), (0.25, 0.5), (0.75, 0.5), (0.25, 0.75), (0.75, 0.75)],
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(LinearGradient(colors: special ? [Theme.gold, Theme.bronze] : [Theme.ivory, Theme.ivoryShade],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.18)
                .strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1)
            if let face, let points = DieView.pips[face] {
                GeometryReader { geo in
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: size * 0.17, height: size * 0.17)
                            .position(x: geo.size.width * p.0, y: geo.size.height * p.1)
                    }
                }
            } else if placeholder {
                Text("?").font(Theme.display(size * 0.5)).foregroundStyle(Theme.ink.opacity(0.35))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: highlighted ? Theme.gold.opacity(0.9) : .black.opacity(0.5), radius: highlighted ? 10 : 4, y: highlighted ? 0 : 3)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.18)
                .strokeBorder(Theme.gold, lineWidth: highlighted ? 2.5 : 0)
        )
        .opacity(dimmed ? 0.45 : 1)
    }
}

/// Six little bars showing a die's face odds.
struct OddsStrip: View {
    let die: DieType
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...6, id: \.self) { f in
                let p = die.probability(ofFace: f)
                VStack(spacing: 1) {
                    Rectangle()
                        .fill(f == 1 || f == 5 ? Theme.moss : Theme.bronze)
                        .frame(width: 14, height: max(1, 22 * p / 0.7))
                    Text("\(f)").font(.system(size: 8, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .help((1...6).map { "\($0): \(percent(die.probability(ofFace: $0)))" }.joined(separator: "   "))
    }
}
