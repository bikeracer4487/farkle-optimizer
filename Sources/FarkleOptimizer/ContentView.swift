import SwiftUI
import FarkleCore

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            LinearGradient(colors: [Theme.leather, Theme.night], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.leatherLight.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 700)
            VStack(spacing: 0) {
                header
                Divider().overlay(Theme.bronze.opacity(0.6))
                Group {
                    switch model.screen {
                    case .bag: DiceBagView()
                    case .table: TableView()
                    }
                }
                .padding(24)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)

    }

    private var header: some View {
        @Bindable var model = model
        return HStack(spacing: 24) {
            HStack(spacing: 10) {
                DieView(face: 1, size: 26, special: true)
                Text("Dice of Bohemia").font(Theme.display(24)).tracking(2).foregroundStyle(Theme.gold)
                Text("a Farkle counsellor for Kingdom Come: Deliverance II")
                    .font(Theme.serifItalic(13)).foregroundStyle(Theme.ivory.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(Screen.allCases) { s in
                    Button { model.screen = s } label: {
                        Text(s.rawValue.uppercased())
                            .font(Theme.display(13)).tracking(2)
                            .foregroundStyle(model.screen == s ? Theme.night : Theme.gold)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(model.screen == s ? Theme.gold : .clear)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.gold, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }
}
