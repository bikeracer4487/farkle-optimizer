import SwiftUI
import FarkleCore

struct DiceBagView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = ""

    private var listedDice: [DieType] {
        DieType.catalog.filter { !$0.isOrdinary && (filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter)) }
    }

    var body: some View {
        @Bindable var model = model
        HStack(alignment: .top, spacing: 24) {
            inventory
                .frame(width: 460)
            results
        }
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            RuledHeading(text: "Your dice")
            Text("Mark how many of each special die Henry carries. Ordinary dice fill any empty places.")
                .font(Theme.serif(14)).foregroundStyle(Theme.inkSoft)
            TextField("Search dice…", text: $filter)
                .textFieldStyle(.plain)
                .font(Theme.serif(15))
                .foregroundStyle(Theme.ink)
                .padding(8)
                .background(Theme.ivory.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.bronze, lineWidth: 1))
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(listedDice) { die in
                        inventoryRow(die)
                        Divider().overlay(Theme.bronze.opacity(0.35))
                    }
                }
            }
            HStack {
                Text("\(model.ownedSpecialCount) special dice owned").font(Theme.serifItalic(13)).foregroundStyle(Theme.inkSoft)
                Spacer()
                Button("Clear") { model.inventory = [:] }.buttonStyle(MedievalButtonStyle())
            }
        }
        .parchmentPanel()
    }

    private func inventoryRow(_ die: DieType) -> some View {
        let count = model.count(of: die)
        return HStack(spacing: 12) {
            DieView(face: 1, size: 30, special: count > 0, dimmed: count == 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(die.name).font(Theme.serif(16)).foregroundStyle(Theme.ink)
                if die.isUniform {
                    Text("fair — rolls like an ordinary die").font(Theme.serifItalic(12)).foregroundStyle(Theme.inkSoft)
                } else {
                    Text("1: \(percent(die.probability(ofFace: 1)))   5: \(percent(die.probability(ofFace: 5)))")
                        .font(Theme.mono(11)).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            OddsStrip(die: die)
            HStack(spacing: 6) {
                Button { model.setCount(count - 1, for: die) } label: { Image(systemName: "minus") }
                    .buttonStyle(.plain).foregroundStyle(count > 0 ? Theme.ink : Theme.inkSoft).disabled(count == 0)
                Text("\(count)").font(Theme.mono(16)).foregroundStyle(count > 0 ? Theme.ink : Theme.inkSoft).frame(width: 20)
                Button { model.setCount(count + 1, for: die) } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).foregroundStyle(Theme.ink).disabled(count >= 6)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var results: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 14) {
            RuledHeading(text: "Choose your set", color: Theme.gold)
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAYING TO").font(Theme.display(12)).tracking(2).foregroundStyle(Theme.ivory.opacity(0.7))
                    HStack(spacing: 6) {
                        ForEach([1000, 1500, 2000, 3000, 4000], id: \.self) { g in
                            Button { model.goal = g } label: { Text(verbatim: "\(g)").fixedSize() }
                                .buttonStyle(MedievalButtonStyle(prominent: model.goal == g))
                        }
                        TextField("", value: $model.goal, format: .number)
                            .textFieldStyle(.plain).font(Theme.mono(15)).foregroundStyle(Theme.ivory)
                            .multilineTextAlignment(.center).frame(width: 70).padding(6)
                            .background(Theme.night.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.bronze, lineWidth: 1))
                    }
                }
                Spacer()
                Button { model.rankSets() } label: { Text("Find my best set").fixedSize() }
                    .buttonStyle(MedievalButtonStyle(prominent: true))
                    .disabled(model.rankingProgress != nil)
            }
            if let p = model.rankingProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: p).tint(Theme.gold)
                    Text("Weighing \(model.searchedSetCount) possible sets…").font(Theme.serifItalic(13)).foregroundStyle(Theme.ivory.opacity(0.7))
                }
            }
            Text("Sets are ranked by the chance of beating an opponent who plays six ordinary dice, from 0–0, rolling first. Points per turn assume the play that maximises expected score.")
                .font(Theme.serif(13)).foregroundStyle(Theme.ivory.opacity(0.65))
            activeSetCard
            if !model.candidates.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(model.candidates.enumerated()), id: \.element.id) { idx, c in
                            candidateRow(rank: idx + 1, c)
                        }
                    }
                }
            } else if model.rankingProgress == nil {
                Text("Mark your dice on the left, then press Find my best set.")
                    .font(Theme.serifItalic(15)).foregroundStyle(Theme.ivory.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 30)
            }
            Spacer(minLength: 0)
        }
        .leatherPanel()
    }

    private var activeSetCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AT THE TABLE NOW").font(Theme.display(12)).tracking(2).foregroundStyle(Theme.inkSoft).fixedSize()
                Text(model.activeSet.summary).font(Theme.serif(16)).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 20)
            HStack(spacing: 6) {
                ForEach(Array(model.activeSet.dice.enumerated()), id: \.offset) { _, d in
                    DieView(face: nil, size: 28, special: !d.isOrdinary, placeholder: false)
                }
            }
            Button { model.screen = .table } label: { Text("Go to the table").fixedSize() }.buttonStyle(MedievalButtonStyle())
        }
        .parchmentPanel()
    }

    private func candidateRow(rank: Int, _ c: SetCandidate) -> some View {
        let isActive = c.set == model.activeSet
        return HStack(spacing: 16) {
            Text("\(rank)").font(Theme.display(22)).foregroundStyle(Theme.gold).frame(width: 28)
            HStack(spacing: 5) {
                ForEach(Array(c.set.dice.enumerated()), id: \.offset) { _, d in
                    DieView(face: nil, size: 26, special: !d.isOrdinary, placeholder: false).help(d.name)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(c.set.summary).font(Theme.serif(15)).foregroundStyle(Theme.ivory)
                HStack(spacing: 14) {
                    stat("win", percent(c.winProbability ?? 0))
                    stat("points / turn", String(format: "%.0f", c.expectedTurnScore))
                    stat("opening bust", percent(c.openingBust))
                }
            }
            Spacer()
            Button { model.activate(c.set); model.screen = .table } label: { Text(isActive ? "Playing" : "Play this set").fixedSize() }
                .buttonStyle(MedievalButtonStyle(prominent: !isActive))
                .disabled(isActive)
        }
        .padding(10)
        .background(isActive ? Theme.bronze.opacity(0.18) : Theme.night.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(isActive ? Theme.gold : Theme.bronze.opacity(0.4), lineWidth: 1))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(Theme.mono(12)).foregroundStyle(Theme.gold)
            Text(label).font(Theme.serifItalic(12)).foregroundStyle(Theme.ivory.opacity(0.6))
        }
    }
}
