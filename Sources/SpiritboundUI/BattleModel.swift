import SwiftUI
import SpiritboundCore

@MainActor
final class BattleModel: ObservableObject {
    let content: Content
    @Published private(set) var combat: Combat
    @Published var errorKey: String?
    @Published var messageKey = "battle.welcome"

    init(content: Content, seed: UInt64) throws {
        self.content = content
        combat = try Combat(content: content, seed: seed)
    }
    func play(_ card: CardInstance) {
        do {
            try combat.play(cardID: card.id)
            messageKey = "battle.played"
        } catch { report(error) }
    }
    func endTurn() {
        do {
            try combat.endTurn()
            messageKey = "battle.nextTurn"
        } catch { report(error) }
    }
    func restart() {
        do {
            combat = try Combat(content: content, seed: UInt64.random(in: .min ... .max))
            messageKey = "battle.welcome"
        } catch { report(error) }
    }
    private func report(_ error: Error) {
        switch error {
        case CombatError.insufficientEnergy: errorKey = "error.energy"
        case CombatError.cardNotInHand: errorKey = "error.card"
        case CombatError.combatFinished: errorKey = "error.finished"
        default: errorKey = "error.content"
        }
    }
}
