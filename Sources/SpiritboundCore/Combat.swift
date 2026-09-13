import Foundation

public struct Combatant: Equatable, Sendable {
    public internal(set) var health: Int
    public let maxHealth: Int
    public internal(set) var shield = 0
    public internal(set) var statuses: [String: Int] = [:]
}
public struct CardInstance: Equatable, Sendable, Identifiable {
    public let id: Int
    public let definitionID: String
}
public enum CombatPhase: Sendable { case playerTurn, won, lost }
public enum CombatError: Error { case combatFinished, cardNotInHand, insufficientEnergy }

/// Value-type rules engine. UI observes snapshots; all randomness is seedable.
public struct Combat: Sendable {
    public private(set) var player: Combatant
    public private(set) var enemy: Combatant
    public private(set) var drawPile: [CardInstance] = []
    public private(set) var hand: [CardInstance] = []
    public private(set) var discardPile: [CardInstance] = []
    public private(set) var exhaustPile: [CardInstance] = []
    public private(set) var energy = 0
    public private(set) var turn = 0
    public private(set) var phase: CombatPhase = .playerTurn
    private let content: Content
    private var rng: SeededGenerator
    private var triggerDepth = 0

    public init(content: Content, seed: UInt64) throws {
        try content.validate()
        self.content = content
        rng = SeededGenerator(state: seed)
        player = Combatant(health: content.rules.playerHealth, maxHealth: content.rules.playerHealth)
        enemy = Combatant(health: content.rules.enemyHealth, maxHealth: content.rules.enemyHealth)
        drawPile = content.startingDeck.enumerated().map { CardInstance(id: $0.offset, definitionID: $0.element) }
        drawPile.shuffle(using: &rng)
        beginTurn()
    }
    public mutating func play(cardID: Int) throws {
        guard phase == .playerTurn else { throw CombatError.combatFinished }
        guard let index = hand.firstIndex(where: { $0.id == cardID }),
              let card = content.cards.first(where: { $0.id == hand[index].definitionID }) else { throw CombatError.cardNotInHand }
        guard energy >= card.cost else { throw CombatError.insufficientEnergy }
        energy -= card.cost
        let instance = hand.remove(at: index)
        if card.exhaust { exhaustPile.append(instance) } else { discardPile.append(instance) }
        var bonus = 0
        if card.effects.contains(where: { $0.operation == .damage && $0.target == .opponent }) {
            for status in content.statuses {
                if let value = status.nextAttackBonus, let stacks = player.statuses[status.id], stacks > 0 {
                    bonus += value * stacks
                    player.statuses[status.id] = nil
                }
            }
        }
        for effect in card.effects where phase == .playerTurn {
            if effect.operation == .damage && effect.target == .opponent {
                damage(effect.amount + bonus, toPlayer: false)
                bonus = 0
            } else { apply(effect, actorIsPlayer: true) }
        }
        if phase == .playerTurn { trigger(.cardPlayed, actorIsPlayer: true) }
    }
    public mutating func endTurn() throws {
        guard phase == .playerTurn else { throw CombatError.combatFinished }
        discardPile.append(contentsOf: hand)
        hand.removeAll()
        trigger(.turnEnd, actorIsPlayer: true)
        guard phase == .playerTurn else { return }
        enemy.shield = 0
        trigger(.turnStart, actorIsPlayer: false)
        guard phase == .playerTurn else { return }
        damage(content.rules.enemyDamage, toPlayer: true)
        guard phase == .playerTurn else { return }
        trigger(.turnEnd, actorIsPlayer: false)
        if phase == .playerTurn { beginTurn() }
    }
    private mutating func beginTurn() {
        turn += 1
        energy = content.rules.energy
        player.shield = 0
        trigger(.turnStart, actorIsPlayer: true)
        if phase == .playerTurn { draw(content.rules.draw) }
    }
    private mutating func draw(_ count: Int) {
        for _ in 0..<count {
            guard phase == .playerTurn, hand.count < content.rules.handLimit else { return }
            if drawPile.isEmpty {
                drawPile = discardPile
                discardPile.removeAll()
                drawPile.shuffle(using: &rng)
            }
            guard let card = drawPile.popLast() else { return }
            hand.append(card)
            trigger(.drawn, actorIsPlayer: true)
        }
    }
    private mutating func trigger(_ event: Trigger, actorIsPlayer: Bool) {
        // Bounded recursion prevents data-authored trigger cycles from hanging the game.
        guard triggerDepth < 32 else { return }
        triggerDepth += 1
        defer { triggerDepth -= 1 }
        let snapshot = actorIsPlayer ? player.statuses : enemy.statuses
        for definition in content.statuses where definition.trigger == event {
            guard let stacks = snapshot[definition.id], stacks > 0 else { continue }
            apply(definition.effect, actorIsPlayer: actorIsPlayer, multiplier: definition.scaleWithStacks ? stacks : 1)
            if actorIsPlayer { player.statuses[definition.id] = max(0, (player.statuses[definition.id] ?? 0) - definition.decay) }
            else { enemy.statuses[definition.id] = max(0, (enemy.statuses[definition.id] ?? 0) - definition.decay) }
            if phase != .playerTurn { break }
        }
    }
    private mutating func apply(_ effect: Effect, actorIsPlayer: Bool, multiplier: Int = 1) {
        let toPlayer = effect.target == .actor ? actorIsPlayer : !actorIsPlayer
        let amount = effect.amount * multiplier
        switch effect.operation {
        case .damage: damage(amount, toPlayer: toPlayer)
        case .draw: if toPlayer { draw(amount) }
        case .energy: if toPlayer { energy += amount }
        case .shield:
            if toPlayer { player.shield += amount } else { enemy.shield += amount }
        case .heal:
            if toPlayer { player.health = min(player.maxHealth, player.health + amount) }
            else { enemy.health = min(enemy.maxHealth, enemy.health + amount) }
        case .status:
            guard let id = effect.status else { return }
            if toPlayer { player.statuses[id, default: 0] += amount }
            else { enemy.statuses[id, default: 0] += amount }
        }
    }
    private mutating func damage(_ amount: Int, toPlayer: Bool) {
        var target = toPlayer ? player : enemy
        let absorbed = min(target.shield, amount)
        target.shield -= absorbed
        let healthDamage = amount - absorbed
        target.health = max(0, target.health - healthDamage)
        if toPlayer { player = target } else { enemy = target }
        if target.health == 0 {
            phase = toPlayer ? .lost : .won
            trigger(.death, actorIsPlayer: toPlayer)
        } else if healthDamage > 0 { trigger(.damaged, actorIsPlayer: toPlayer) }
    }
}
private struct SeededGenerator: RandomNumberGenerator, Sendable {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
