import SwiftUI
import FarkleCore

struct TableView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 20) {
                scoreboard
                diceTable
                turnControls
            }
            AdvicePanel()
                .frame(width: 400)
        }
    }

    // MARK: Scores

    private var scoreboard: some View {
        @Bindable var model = model
        return HStack(spacing: 30) {
            ScoreField(label: "Henry", value: $model.myScore)
            Spacer()
            VStack(spacing: 4) {
                Text("PLAYING TO").font(Theme.display(12)).tracking(2).foregroundStyle(Theme.inkSoft)
                TextField("", value: $model.goal, format: .number)
                    .textFieldStyle(.plain).font(Theme.mono(20)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).frame(width: 84).padding(.vertical, 4)
                    .background(Theme.ivory.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.bronze, lineWidth: 1))
                if let w = model.winChanceNow {
                    Text("win chance at turn start \(percent(w))").font(Theme.serifItalic(12)).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            ScoreField(label: "Opponent", value: $model.oppScore)
        }
        .parchmentPanel()
    }

    // MARK: Dice

    private var diceTable: some View {
        VStack(spacing: 12) {
            HStack {
                RuledHeading(text: "Held", color: Theme.gold).frame(width: 200)
                Spacer()
                Text(model.activeSet.summary).font(Theme.serifItalic(12)).foregroundStyle(Theme.ivory.opacity(0.55))
            }
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { p in
                    if model.slots[p].held { dieSlot(p) }
                }
                if model.slots.allSatisfy({ !$0.held }) {
                    Text("No dice set aside yet").font(Theme.serifItalic(14)).foregroundStyle(Theme.ivory.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 130)
            RuledHeading(text: "On the table", color: Theme.gold).frame(width: 200).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { p in
                    if !model.slots[p].held { dieSlot(p) }
                }
                if model.allHeld {
                    Text("Hot dice! All six are held — roll them all again or bank.").font(Theme.serifItalic(14)).foregroundStyle(Theme.gold)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 130)
            Text("Click a die or a number to set the face it shows. Click HOLD to set a die aside by hand.")
                .font(Theme.serifItalic(12)).foregroundStyle(Theme.ivory.opacity(0.45))
        }
        .padding(18)
        .background(
            ZStack {
                LinearGradient(colors: [Theme.felt, Theme.feltDark], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 80, endRadius: 500)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.bronze.opacity(0.8), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
    }

    private func dieSlot(_ p: Int) -> some View {
        let slot = model.slots[p]
        let die = model.activeSet.dice[p]
        let recommended = model.advice?.best?.positions.contains(p) ?? false
        return VStack(spacing: 6) {
            Button { model.cycleFace(at: p) } label: {
                DieView(face: slot.face, size: 62, special: !die.isOrdinary, highlighted: recommended && !slot.held)
            }
            .buttonStyle(.plain)
            Text(die.isOrdinary ? "Ordinary" : die.name.replacingOccurrences(of: " die", with: "").replacingOccurrences(of: " Die", with: ""))
                .font(Theme.serif(11)).foregroundStyle(Theme.ivory.opacity(0.75)).lineLimit(1).frame(width: 96)
            HStack(spacing: 2) {
                ForEach(1...6, id: \.self) { f in
                    Button { model.slots[p].face = f } label: {
                        Text("\(f)").font(Theme.mono(10))
                            .frame(width: 14, height: 16)
                            .background(slot.face == f ? Theme.gold : Theme.night.opacity(0.5))
                            .foregroundStyle(slot.face == f ? Theme.night : Theme.ivory.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(slot.held ? "RELEASE" : "HOLD") { model.toggleHeld(at: p) }
                .buttonStyle(.plain)
                .font(Theme.display(10)).tracking(1.5)
                .foregroundStyle(slot.held ? Theme.gold : Theme.ivory.opacity(0.6))
        }
    }

    // MARK: Controls

    private var turnControls: some View {
        @Bindable var model = model
        return HStack(spacing: 14) {
            ScoreField(label: "Turn points", value: $model.turnPoints)
            Spacer()
            Button("New turn") { model.newTurn() }.buttonStyle(MedievalButtonStyle())
            Button("Farkle") { model.bust() }.buttonStyle(MedievalButtonStyle(danger: true))
            if model.allHeld {
                Button("Roll all six") { model.rollAllSix() }.buttonStyle(MedievalButtonStyle())
            }
            Button("Bank \(model.turnPoints)") { model.bank() }
                .buttonStyle(MedievalButtonStyle(prominent: true))
                .disabled(model.turnPoints == 0)
        }
        .parchmentPanel()
    }
}

// MARK: - Advice

struct AdvicePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RuledHeading(text: "Counsel")
            content
            Spacer(minLength: 0)
            Text("The opponent is assumed to play six ordinary dice. Odds are the chance of winning the match, not the points of one throw.")
                .font(Theme.serifItalic(11)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxHeight: .infinity)
        .parchmentPanel()
    }

    @ViewBuilder
    private var content: some View {
        if model.winTable == nil {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Reckoning the odds for this set…").font(Theme.serifItalic(15)).foregroundStyle(Theme.inkSoft)
            }
        } else if model.myScore >= model.goal {
            verdict("Henry has won", color: Theme.moss)
        } else if !model.rollIsComplete {
            Text("Set the face of every die on the table and I shall advise you.")
                .font(Theme.serif(15)).foregroundStyle(Theme.inkSoft)
        } else if let advice = model.advice {
            if advice.bustedRoll {
                verdict("Farkle!", color: Theme.crimson)
                Text("Nothing on the table scores. The turn's points are lost.").font(Theme.serif(15)).foregroundStyle(Theme.ink)
                Button("Next turn") { model.bust() }.buttonStyle(MedievalButtonStyle(danger: true))
            } else if let best = advice.best {
                bestCard(best)
                if advice.evaluations.count > 1 {
                    Text("OTHER CHOICES").font(Theme.display(12)).tracking(2).foregroundStyle(Theme.inkSoft).padding(.top, 6)
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(advice.evaluations.dropFirst().prefix(10)) { e in alternativeRow(e) }
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Thinking…").font(Theme.serifItalic(15)).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func verdict(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(Theme.display(26)).tracking(2)
            .foregroundStyle(Theme.ivory)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.gold, lineWidth: 1))
    }

    private func bestCard(_ best: HoldEvaluation) -> some View {
        let action = best.bestAction
        return VStack(alignment: .leading, spacing: 10) {
            verdict(action.rawValue, color: action == .scoreAndContinue ? Theme.moss : Theme.bronze)
            if best.hotDice && best.positions.isEmpty {
                Text(action == .scoreAndContinue ? "Roll all six dice again." : "Bank the \(model.turnPoints) points.")
                    .font(Theme.serif(17)).foregroundStyle(Theme.ink)
            } else {
                Text("Hold \(best.description)").font(Theme.serif(17)).foregroundStyle(Theme.ink)
                Text("+\(best.points) points" + (best.hotDice ? " — hot dice, all six roll again" : ""))
                    .font(Theme.serifItalic(14)).foregroundStyle(Theme.inkSoft)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    Text("Continue").font(Theme.serif(14)).foregroundStyle(Theme.ink)
                    Text(best.continueWin.map(percent) ?? "—").font(Theme.mono(14)).foregroundStyle(action == .scoreAndContinue ? Theme.moss : Theme.ink)
                    Text("to win").font(Theme.serifItalic(12)).foregroundStyle(Theme.inkSoft)
                }
                GridRow {
                    Text("Pass").font(Theme.serif(14)).foregroundStyle(Theme.ink)
                    Text(percent(best.passWin)).font(Theme.mono(14)).foregroundStyle(action == .scoreAndPass ? Theme.moss : Theme.ink)
                    Text("to win").font(Theme.serifItalic(12)).foregroundStyle(Theme.inkSoft)
                }
                GridRow {
                    Text("Next throw").font(Theme.serif(14)).foregroundStyle(Theme.ink)
                    Text(percent(best.bustIfContinue)).font(Theme.mono(14)).foregroundStyle(Theme.crimson)
                    Text("bust with \(best.diceLeftIfContinue) dice").font(Theme.serifItalic(12)).foregroundStyle(Theme.inkSoft)
                }
            }
            let hot = best.hotDice && best.positions.isEmpty
            VStack(alignment: .leading, spacing: 8) {
                Button(action == .scoreAndContinue ? (hot ? "Roll all six" : "Hold these & roll again")
                                                   : (hot ? "Bank \(model.turnPoints)" : "Hold these & bank")) {
                    model.applyBest()
                    if action == .scoreAndPass { model.bank() }
                }
                .buttonStyle(MedievalButtonStyle(prominent: true))
                if action == .scoreAndContinue {
                    Button(hot ? "Bank instead" : "Hold these & bank instead") { model.applyBest(); model.bank() }
                        .buttonStyle(MedievalButtonStyle())
                }
            }
        }
    }

    private func alternativeRow(_ e: HoldEvaluation) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.description).font(Theme.serif(14)).foregroundStyle(Theme.ink)
                Text("+\(e.points) · then \(e.bestAction == .scoreAndContinue ? "continue" : "pass")").font(Theme.serifItalic(11)).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(percent(e.bestWin)).font(Theme.mono(13)).foregroundStyle(Theme.ink)
                Text("go \(e.continueWin.map(percent) ?? "—") · pass \(percent(e.passWin))").font(Theme.mono(9)).foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(6)
        .background(Theme.ivory.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.bronze.opacity(0.4), lineWidth: 1))
    }
}

