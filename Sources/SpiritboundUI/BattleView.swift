import SwiftUI
import SpiritboundCore

private enum Palette {
    static let ink = Color(red: 0.045, green: 0.09, blue: 0.11)
    static let panel = Color(red: 0.085, green: 0.15, blue: 0.17)
    static let ember = Color(red: 1, green: 0.64, blue: 0.40)
    static let jade = Color(red: 0.58, green: 0.86, blue: 0.76)
}
private enum Pile: String, Identifiable { case draw, discard, exhaust; var id: String { rawValue } }

struct BattleView: View {
    @ObservedObject var model: BattleModel
    @AppStorage("spiritbound.language") private var language = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
    @State private var inspectedPile: Pile?
    @State private var showRestart = false
    private var copy: BattlePresentation { BattlePresentation(content: model.content, language: language) }
    private var active: Bool { model.combat.phase == .playerTurn }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                HStack {
                    Text(copy.text("battle.chapter")).font(.caption).tracking(2)
                    Spacer()
                    Text(copy.text("battle.turn", ["turn": String(model.combat.turn)]))
                        .font(.caption.monospacedDigit())
                }.foregroundStyle(Palette.jade)
                combatant(model.combat.enemy, name: "enemy.name", symbol: "mountain.2.fill", tint: Palette.jade)
                if active {
                    Label(copy.text("enemy.intent", ["damage": String(model.content.rules.enemyDamage)]), systemImage: "arrow.down.right")
                        .font(.callout.weight(.semibold)).foregroundStyle(Palette.ember)
                }
                combatant(model.combat.player, name: "spirit.fox", symbol: "flame.fill", tint: Palette.ember)
                if active { hand } else { outcome }
                HStack(spacing: 8) {
                    pileButton(.draw, count: model.combat.drawPile.count)
                    pileButton(.discard, count: model.combat.discardPile.count)
                    pileButton(.exhaust, count: model.combat.exhaustPile.count)
                }
                if active { Text(copy.text(model.messageKey)).font(.footnote).foregroundStyle(.secondary) }
                Text(copy.text("battle.rules", ["draw": String(model.content.rules.draw), "energy": String(model.content.rules.energy)]))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ink)
        .safeAreaInset(edge: .bottom) {
            if active {
                Button(action: model.endTurn) {
                    Text(copy.text("battle.endTurn")).font(.headline).frame(maxWidth: .infinity).padding(12)
                        .foregroundStyle(Palette.ink)
                        .background(Palette.ember, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.vertical, 10).background(Palette.ink)
            }
        }
        .sheet(item: $inspectedPile) { pile in pileSheet(pile) }
        .confirmationDialog(copy.text("restart.title"), isPresented: $showRestart, titleVisibility: .visible) {
            Button(copy.text("battle.restart"), role: .destructive, action: model.restart)
            Button(copy.text("action.cancel"), role: .cancel) {}
        } message: { Text(copy.text("restart.message")) }
        .alert(copy.text("error.title"), isPresented: Binding(get: { model.errorKey != nil }, set: { if !$0 { model.errorKey = nil } })) {
            Button(copy.text("action.ok")) { model.errorKey = nil }
        } message: { Text(copy.text(model.errorKey ?? "error.content")) }
    }
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack { title; Spacer(); controls }
            VStack(alignment: .leading, spacing: 12) { title; controls }
        }
    }
    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SPIRITBOUND").font(.headline).tracking(3)
            Text(copy.text("battle.subtitle")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var controls: some View {
        HStack {
            Menu {
                Button("English") { language = "en" }
                Button("简体中文") { language = "zh-Hans" }
            } label: {
                Image(systemName: "globe").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel(copy.text("action.language"))
            Button { if active { showRestart = true } else { model.restart() } } label: {
                Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel(copy.text("battle.restart"))
        }.foregroundStyle(Palette.jade)
    }
    private func combatant(_ fighter: Combatant, name: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(tint)
                    .frame(width: 52, height: 56).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.text(name)).font(.title3.bold())
                    Text(copy.text("battle.health", ["current": String(fighter.health), "max": String(fighter.maxHealth)]))
                        .font(.subheadline.monospacedDigit())
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: Double(fighter.health), total: Double(fighter.maxHealth))
                .tint(tint).accessibilityLabel(copy.text(name))
                .accessibilityValue(copy.text("battle.health", ["current": String(fighter.health), "max": String(fighter.maxHealth)]))
            Label(copy.text("battle.shield", ["amount": String(fighter.shield)]), systemImage: "shield.fill")
                .font(.subheadline).foregroundStyle(Palette.jade)
            ForEach(fighter.statuses.keys.sorted(), id: \.self) { id in
                if let stacks = fighter.statuses[id], stacks > 0 {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(copy.text("status.\(id)")) · \(stacks)").font(.subheadline.bold())
                        Text(copy.statusDescription(id, stacks: stacks)).font(.caption).foregroundStyle(.secondary)
                    }.accessibilityElement(children: .combine)
                }
            }
        }.padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }
    private var hand: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(copy.text("battle.hand")).font(.title3.bold())
                Spacer()
                Label(copy.text("battle.energy", ["amount": String(model.combat.energy)]), systemImage: "bolt.fill")
                    .font(.headline).foregroundStyle(Palette.ember)
            }
            Text(copy.text("battle.tap")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .top)], alignment: .leading, spacing: 12) {
                ForEach(model.combat.hand) { instance in
                    if let card = definition(instance) {
                        Button { model.play(instance) } label: { cardFace(card) }
                            .buttonStyle(.plain)
                            .disabled(card.cost > model.combat.energy)
                            .opacity(card.cost > model.combat.energy ? 0.6 : 1)
                            .accessibilityLabel("\(copy.text(card.nameKey)). \(copy.text("card.cost", ["amount": String(card.cost)])). \(copy.description(for: card))")
                            .accessibilityHint(copy.text(card.cost > model.combat.energy ? "error.energy" : "battle.tap"))
                    }
                }
            }
        }
    }
    private func cardFace(_ card: CardDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(copy.text("rarity.\(card.rarity)")).font(.caption2).foregroundStyle(Palette.jade)
                Spacer()
                Label(String(card.cost), systemImage: "bolt.fill").font(.caption.bold()).foregroundStyle(Palette.ember)
            }
            Text(copy.text(card.nameKey)).font(.headline).foregroundStyle(.white)
            Text(copy.description(for: card)).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.ember.opacity(0.45), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    private var outcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.text(model.combat.phase == .won ? "battle.won" : "battle.lost")).font(.largeTitle.bold())
            Text(copy.text("battle.outcomeDetail")).foregroundStyle(.secondary)
            Button(copy.text("battle.restart"), action: model.restart).buttonStyle(.borderedProminent).tint(Palette.ember)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }
    private func pileButton(_ pile: Pile, count: Int) -> some View {
        Button { inspectedPile = pile } label: {
            VStack(spacing: 5) {
                Text(String(count)).font(.headline.monospacedDigit())
                Text(copy.text("pile.\(pile.rawValue)")).font(.caption)
            }.frame(maxWidth: .infinity, minHeight: 52)
        }.buttonStyle(.bordered).tint(Palette.jade)
            .accessibilityLabel("\(copy.text("pile.\(pile.rawValue)")), \(count)")
    }
    private func definition(_ instance: CardInstance) -> CardDefinition? {
        model.content.cards.first { $0.id == instance.definitionID }
    }
    private func pileCards(_ pile: Pile) -> [CardInstance] {
        let cards: [CardInstance]
        switch pile {
        case .draw: cards = model.combat.drawPile
        case .discard: cards = model.combat.discardPile
        case .exhaust: cards = model.combat.exhaustPile
        }
        // Inspect contents without revealing the future draw order.
        return cards.sorted { ($0.definitionID, $0.id) < ($1.definitionID, $1.id) }
    }
    private func pileSheet(_ pile: Pile) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(copy.text("pile.orderNote")).font(.caption).foregroundStyle(.secondary)
                    if pileCards(pile).isEmpty { Text(copy.text("pile.empty")) }
                    ForEach(pileCards(pile)) { instance in
                        if let card = definition(instance) { cardFace(card) }
                    }
                }.padding(20)
            }
            .background(Palette.ink)
            .navigationTitle(copy.text("pile.\(pile.rawValue)"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(copy.text("action.done")) { inspectedPile = nil } } }
        }.preferredColorScheme(.dark)
    }
}
