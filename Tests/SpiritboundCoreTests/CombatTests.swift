import XCTest
@testable import SpiritboundCore

final class CombatTests: XCTestCase {
    func testContentAndLocalization() throws {
        let content = try Content.bundled()
        XCTAssertEqual(content.startingDeck.count, 10)
        XCTAssertEqual(content.text("card.foxfire", language: "zh-Hans"), "狐火")
        XCTAssertEqual(content.text("card.foxfire", language: "fr"), "Foxfire")
    }
    func testSeedAndInitialState() throws {
        let content = try Content.bundled()
        let a = try Combat(content: content, seed: 42)
        let b = try Combat(content: content, seed: 42)
        XCTAssertEqual(a.hand, b.hand)
        XCTAssertEqual(a.hand.count, 5)
        XCTAssertEqual(a.drawPile.count, 5)
        XCTAssertEqual(a.energy, 3)
    }
    func testInvalidPlayIsAtomic() throws {
        var combat = try Combat(content: .bundled(), seed: 42)
        let hand = combat.hand
        XCTAssertThrowsError(try combat.play(cardID: -1))
        XCTAssertEqual(combat.hand, hand)
        XCTAssertEqual(combat.energy, 3)
        for card in Array(combat.hand.prefix(3)) { try combat.play(cardID: card.id) }
        let before = combat.hand
        XCTAssertThrowsError(try combat.play(cardID: before[0].id))
        XCTAssertEqual(combat.hand, before)
        XCTAssertEqual(combat.energy, 0)
    }
    func testReshuffleConservesInstances() throws {
        var combat = try Combat(content: .bundled(), seed: 4)
        for _ in 0..<4 {
            try combat.endTurn()
            let all = combat.hand + combat.drawPile + combat.discardPile + combat.exhaustPile
            XCTAssertEqual(Set(all.map(\.id)).count, 10)
            XCTAssertEqual(all.count, 10)
            XCTAssertEqual(combat.hand.count, 5)
        }
    }
    func testBurnTicksAtEnemyEndAndDecays() throws {
        let content = try Content.bundled()
        for seed in UInt64(0)..<100 {
            var combat = try Combat(content: content, seed: seed)
            if let foxfire = combat.hand.first(where: { $0.definitionID == "foxfire" }) {
                try combat.play(cardID: foxfire.id)
                XCTAssertEqual(combat.enemy.health, 36)
                XCTAssertEqual(combat.enemy.statuses["burn"], 3)
                try combat.endTurn()
                XCTAssertEqual(combat.enemy.health, 33)
                XCTAssertEqual(combat.enemy.statuses["burn"], 2)
                return
            }
        }
        XCTFail("No Foxfire found")
    }
    func testFocusConsumedByNextAttack() throws {
        for seed in UInt64(0)..<100 {
            var combat = try Combat(content: .bundled(), seed: seed)
            if let focus = combat.hand.first(where: { $0.definitionID == "focus" }),
               let strike = combat.hand.first(where: { $0.definitionID == "strike" }) {
                try combat.play(cardID: focus.id)
                try combat.play(cardID: strike.id)
                XCTAssertEqual(combat.enemy.health, 31)
                XCTAssertNil(combat.player.statuses["focus"])
                return
            }
        }
        XCTFail("No test hand found")
    }
    func testDefeatStopsActions() throws {
        var combat = try Combat(content: .bundled(), seed: 0)
        for _ in 0..<9 { try combat.endTurn() }
        XCTAssertEqual(combat.phase, .lost)
        XCTAssertEqual(combat.player.health, 0)
        XCTAssertThrowsError(try combat.endTurn())
        XCTAssertThrowsError(try combat.play(cardID: 0))
    }
    func testLocalizedDescriptionsUseContentValues() throws {
        let content = try Content.bundled()
        for language in ["en", "zh-Hans"] {
            let presentation = BattlePresentation(content: content, language: language)
            for card in content.cards {
                let description = presentation.description(for: card)
                XCTAssertEqual(description.contains("{"), false)
                XCTAssertEqual(description.contains("effect."), false)
                for effect in card.effects {
                    XCTAssertEqual(description.contains(String(effect.amount)), true)
                }
            }
            let focus = content.cards.first { $0.id == "focus" }!
            XCTAssertEqual(presentation.description(for: focus).contains("3"), true)
        }
        XCTAssertEqual(Set(content.translations["en"]!.keys), Set(content.translations["zh-Hans"]!.keys))
    }
    func testShieldProtectsBeforeExpiring() throws {
        for seed in UInt64(0)..<100 {
            var combat = try Combat(content: .bundled(), seed: seed)
            if let ward = combat.hand.first(where: { $0.definitionID == "ward" }) {
                try combat.play(cardID: ward.id)
                XCTAssertEqual(combat.player.shield, 5)
                try combat.endTurn()
                XCTAssertEqual(combat.player.health, 58)
                XCTAssertEqual(combat.player.shield, 0)
                return
            }
        }
        XCTFail("No Ward found")
    }
    func testPlayableBattleCanReachVictory() throws {
        var combat = try Combat(content: .bundled(), seed: 42)
        for _ in 0..<20 {
            if combat.phase != .playerTurn { break }
            let prioritized = combat.hand.sorted {
                func rank(_ card: CardInstance) -> Int {
                    ["foxfire": 0, "strike": 1, "focus": 2, "ward": 3][card.definitionID] ?? 4
                }
                return rank($0) < rank($1)
            }
            for card in prioritized where combat.energy > 0 && combat.phase == .playerTurn {
                try combat.play(cardID: card.id)
            }
            if combat.phase == .playerTurn { try combat.endTurn() }
        }
        XCTAssertEqual(combat.phase, .won)
        XCTAssertEqual(combat.enemy.health, 0)
        XCTAssertThrowsError(try combat.endTurn())
    }
}
