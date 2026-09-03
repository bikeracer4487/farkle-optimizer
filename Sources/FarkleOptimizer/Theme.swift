import SwiftUI

/// Palette and type inspired by the Kingdom Come: Deliverance II dice table.
enum Theme {
    static let night = Color(red: 0.07, green: 0.055, blue: 0.04)
    static let leather = Color(red: 0.17, green: 0.12, blue: 0.08)
    static let leatherLight = Color(red: 0.25, green: 0.18, blue: 0.11)
    static let felt = Color(red: 0.16, green: 0.20, blue: 0.13)
    static let feltDark = Color(red: 0.09, green: 0.12, blue: 0.08)
    static let parchment = Color(red: 0.87, green: 0.79, blue: 0.63)
    static let parchmentDark = Color(red: 0.76, green: 0.66, blue: 0.48)
    static let ink = Color(red: 0.18, green: 0.13, blue: 0.08)
    static let inkSoft = Color(red: 0.18, green: 0.13, blue: 0.08).opacity(0.65)
    static let bronze = Color(red: 0.70, green: 0.52, blue: 0.25)
    static let gold = Color(red: 0.90, green: 0.75, blue: 0.42)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.83)
    static let ivoryShade = Color(red: 0.80, green: 0.74, blue: 0.62)
    static let crimson = Color(red: 0.58, green: 0.17, blue: 0.12)
    static let moss = Color(red: 0.36, green: 0.48, blue: 0.24)

    static func display(_ size: CGFloat) -> Font { .custom("Cochin-Bold", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Cochin", size: size) }
    static func serifItalic(_ size: CGFloat) -> Font { .custom("Cochin-Italic", size: size) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

struct ParchmentPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                ZStack {
                    LinearGradient(colors: [Theme.parchment, Theme.parchmentDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [.clear, Theme.ink.opacity(0.18)], center: .center, startRadius: 120, endRadius: 520)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.bronze, lineWidth: 1.5)
                    .padding(4)
            )
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
    }
}

struct LeatherPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                ZStack {
                    LinearGradient(colors: [Theme.leatherLight, Theme.leather], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 100, endRadius: 600)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.bronze.opacity(0.7), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
    }
}

extension View {
    func parchmentPanel() -> some View { modifier(ParchmentPanel()) }
    func leatherPanel() -> some View { modifier(LeatherPanel()) }
}

/// A heading with thin bronze rules on either side, as on the game's menus.
struct RuledHeading: View {
    let text: String
    var color: Color = Theme.ink
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(color.opacity(0.5)).frame(height: 1)
            Text(text.uppercased())
                .font(Theme.display(15))
                .tracking(3)
                .foregroundStyle(color)
                .fixedSize()
            Rectangle().fill(color.opacity(0.5)).frame(height: 1)
        }
    }
}

struct MedievalButtonStyle: ButtonStyle {
    var prominent = false
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = danger ? Theme.crimson : (prominent ? Theme.bronze : Theme.leatherLight)
        let text: Color = prominent && !danger ? Theme.night : Theme.ivory
        configuration.label
            .fixedSize()
            .font(Theme.display(14))
            .tracking(1.5)
            .foregroundStyle(text)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            .contentShape(Rectangle())
    }
}

/// Parchment-style numeric field.
struct ScoreField: View {
    let label: String
    @Binding var value: Int
    var step = 50

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased()).font(Theme.display(12)).tracking(2).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 4) {
                Button { value = max(0, value - step) } label: { Image(systemName: "minus") }
                    .buttonStyle(.plain).foregroundStyle(Theme.ink)
                TextField("", value: $value, format: .number)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(20))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 84)
                    .padding(.vertical, 4)
                    .background(Theme.ivory.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.bronze, lineWidth: 1))
                Button { value += step } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).foregroundStyle(Theme.ink)
            }
        }
    }
}

func percent(_ p: Double) -> String {
    String(format: "%.1f%%", p * 100)
}
