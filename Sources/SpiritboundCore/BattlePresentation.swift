import Foundation

/// Pure presentation helpers shared by the UI and headless checks.
public struct BattlePresentation: Sendable {
    public let content: Content
    public let language: String
    public init(content: Content, language: String) {
        self.content = content
        self.language = language
    }
    public func text(_ key: String, _ values: [String: String] = [:]) -> String {
        values.reduce(content.text(key, language: language)) {
            $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value)
        }
    }
    public func description(for card: CardDefinition) -> String {
        card.effects.map { effect in
            let target = text(effect.target == .actor ? "target.self" : "target.enemy")
            let summary = text("effect.\(effect.operation.rawValue)", [
                "amount": String(effect.amount), "target": target,
                "status": text("status.\(effect.status ?? "")")
            ])
            if effect.operation == .status, let id = effect.status {
                return summary + "\n" + statusDescription(id, stacks: effect.amount)
            }
            return summary
        }.joined(separator: "\n")
    }
    public func statusDescription(_ id: String, stacks: Int) -> String {
        guard let definition = content.statuses.first(where: { $0.id == id }) else { return id }
        return text("status.\(id).detail", [
            "amount": String(definition.effect.amount * (definition.scaleWithStacks ? stacks : 1)),
            "decay": String(definition.decay),
            "bonus": String((definition.nextAttackBonus ?? 0) * stacks)
        ])
    }
}
