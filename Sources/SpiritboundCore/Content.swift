import Foundation

public enum Trigger: String, Codable, Sendable { case turnStart, turnEnd, cardPlayed, drawn, damaged, death }
public enum Operation: String, Codable, Sendable { case damage, shield, draw, energy, status, heal }
public enum Target: String, Codable, Sendable { case actor, opponent }
public struct Effect: Codable, Sendable {
    public let operation: Operation
    public let target: Target
    public let amount: Int
    public let status: String?
}
public struct CardDefinition: Codable, Sendable {
    public let id: String
    public let nameKey: String
    public let rarity: String
    public let pool: String
    public let cost: Int
    public let exhaust: Bool
    public let effects: [Effect]
}
public struct StatusDefinition: Codable, Sendable {
    public let id: String
    public let trigger: Trigger
    public let effect: Effect
    public let scaleWithStacks: Bool
    public let decay: Int
    public let nextAttackBonus: Int?
}
public struct Rules: Codable, Sendable {
    public let energy: Int
    public let draw: Int
    public let handLimit: Int
    public let playerHealth: Int
    public let enemyHealth: Int
    public let enemyDamage: Int
}
public struct Content: Codable, Sendable {
    public let rules: Rules
    public let cards: [CardDefinition]
    public let statuses: [StatusDefinition]
    public let startingDeck: [String]
    public let translations: [String: [String: String]]
    public static func bundled() throws -> Content {
        guard let url = Bundle.module.url(forResource: "core", withExtension: "json") else { throw ContentError.missingResource }
        let content = try JSONDecoder().decode(Content.self, from: Data(contentsOf: url))
        try content.validate()
        return content
    }
    public func text(_ key: String, language: String) -> String {
        translations[language]?[key] ?? translations["en"]?[key] ?? key
    }
    public func validate() throws {
        guard Set(cards.map(\.id)).count == cards.count,
              Set(statuses.map(\.id)).count == statuses.count,
              !startingDeck.isEmpty,
              rules.energy > 0, rules.draw > 0, rules.handLimit >= rules.draw,
              rules.playerHealth > 0, rules.enemyHealth > 0, rules.enemyDamage >= 0 else { throw ContentError.invalidData }
        let cardIDs = Set(cards.map(\.id)), statusIDs = Set(statuses.map(\.id))
        guard startingDeck.allSatisfy(cardIDs.contains) else { throw ContentError.invalidData }
        for card in cards {
            guard card.cost >= 0, ["en", "zh-Hans"].allSatisfy({ translations[$0]?[card.nameKey] != nil }) else { throw ContentError.invalidData }
        }
        for effect in cards.flatMap(\.effects) + statuses.map(\.effect) {
            guard effect.amount >= 0 else { throw ContentError.invalidData }
            if effect.operation == .status {
                guard let id = effect.status, statusIDs.contains(id) else { throw ContentError.invalidData }
            }
        }
        guard statuses.allSatisfy({ $0.decay >= 0 }) else { throw ContentError.invalidData }
    }
}
public enum ContentError: Error { case missingResource, invalidData }
