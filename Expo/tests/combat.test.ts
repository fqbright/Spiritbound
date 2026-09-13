import { test } from 'node:test';
import assert from 'node:assert/strict';
import { act, content, createBattle, description, enemyAttackPreview, State } from '../src/combat';
function withCards(...ids: string[]) {
  for (let seed = 0; seed < 1000; seed++) {
    const s = createBattle(seed);
    if (ids.every(id => s.hand.some(c => c.definitionID === id))) return s;
  }
  throw Error('No matching hand');
}
function play(s: State, id: string) { return act(s, { type: 'play', id: s.hand.find(c => c.definitionID === id)!.id }); }
test('seeded starting deck and resources', () => {
  assert.deepEqual(createBattle(42), createBattle(42));
  const s = createBattle(42);
  assert.equal(s.hand.length, 5); assert.equal(s.drawPile.length, 20); assert.equal(s.energy, 3); assert.equal(s.actionsRemaining, 2);
});
test('rejected actions do not mutate state', () => {
  let s = createBattle(42); const before = JSON.stringify(s);
  assert.throws(() => act(s, { type: 'play', id: -1 }), /error.card/);
  assert.equal(JSON.stringify(s), before);
  for (let i = 0; i < 2; i++) s = act(s, { type: 'play', id: s.hand[0].id });
  const spent = JSON.stringify(s);
  assert.equal(s.actionsRemaining, 0);
  assert.throws(() => act(s, { type: 'play', id: s.hand[0].id }), /error.actions/);
  assert.equal(JSON.stringify(s), spent);
  s = act(s, { type: 'endTurn' });
  assert.equal(s.actionsRemaining, 2);
});
test('all living enemies attack after the second card resolves', () => {
  let s = createBattle(31, content, { enemies: [{ id: 'a', health: 80, damage: 3 }, { id: 'b', health: 80, damage: 4 }] });
  s = act(s, { type: 'play', id: s.hand[0].id });
  s = act(s, { type: 'play', id: s.hand[0].id });
  assert.equal(s.actionsRemaining, 0);
  const before = s.player.health;
  s = act(s, { type: 'endTurn' });
  assert.ok(s.player.health <= before);
  assert.equal(s.enemies[0].attacksMade, 1);
  assert.equal(s.enemies[1].attacksMade, 1);
});
test('fixed 25-card battle deck conserves cards across all piles', () => {
  let s = createBattle(2);
  for (let i = 0; i < 4; i++) {
    s = act(s, { type: 'endTurn' });
    const all = [...s.hand, ...s.drawPile, ...s.discardPile, ...s.exhaustPile];
    assert.equal(all.length, 25); assert.equal(new Set(all.map(c => c.id)).size, 25);
  }
});
test('played cards do not automatically return from discard this battle', () => {
  let s = createBattle(22, content, { enemyHealth: 1000, enemyDamage: 0 });
  for (let turn = 0; turn < 20 && s.phase === 'playerTurn'; turn++) {
    while (s.actionsRemaining && s.hand.length) s = act(s, { type: 'play', id: s.hand[0].id });
    if (s.phase === 'playerTurn') s = act(s, { type: 'endTurn' });
  }
  assert.equal(s.drawPile.length, 0);
  assert.ok(s.discardPile.length > 0);
  const discarded = new Set(s.discardPile.map(card => card.id));
  assert.ok(s.hand.every(card => !discarded.has(card.id)));
});
test('an enemy can revive once, then disappears permanently on its next defeat', () => {
  let battle = createBattle(3, content, { enemyHealth: 6, enemyDamage: 0, deck: Array(25).fill('strike'), reviveChance: 1 });
  battle = act(battle, { type: 'play', id: battle.hand[0].id });
  assert.equal(battle.enemies[0].health, 3); assert.equal(battle.enemies[0].revived, true); assert.equal(battle.revivesRemaining, 0); assert.equal(battle.phase, 'playerTurn');
  battle = act(battle, { type: 'play', id: battle.hand[0].id });
  assert.equal(battle.enemies[0].health, 0); assert.equal(battle.phase, 'won');
});
test('runes alter action economy, card piles, and multi-enemy damage', () => {
  let swift = createBattle(40, content, { deck: Array(25).fill('strike'), cardRunes: { strike: 'swift' } });
  swift = act(swift, { type: 'play', id: swift.hand[0].id });
  assert.equal(swift.actionsRemaining, 2);
  swift = act(swift, { type: 'play', id: swift.hand[0].id });
  assert.equal(swift.actionsRemaining, 1);

  let cycle = createBattle(41, content, { deck: Array(25).fill('ward'), cardRunes: { ward: 'cycle' } });
  const cycledId = cycle.hand[0].id; cycle = act(cycle, { type: 'play', id: cycledId });
  assert.equal(cycle.drawPile[0].id, cycledId); assert.ok(!cycle.discardPile.some(card => card.id === cycledId));

  let chain = createBattle(42, content, { deck: Array(25).fill('strike'), cardRunes: { strike: 'chain' }, enemies: [{ id: 'a', health: 20, damage: 0 }, { id: 'b', health: 20, damage: 0 }] });
  chain = act(chain, { type: 'play', id: chain.hand[0].id, targetId: 'a' });
  assert.deepEqual(chain.enemies.map(enemy => enemy.health), [14, 18]);
});

test('equipment provides opening bonuses and defensive combat effects', () => {
  let thorn = createBattle(43, content, { enemyHealth: 20, enemyDamage: 5, equipmentIds: ['thornArmor'] });
  thorn = act(thorn, { type: 'endTurn' }); assert.equal(thorn.enemies[0].health, 18);

  let mist = createBattle(44, content, { enemyHealth: 100, enemyDamage: 5, equipmentIds: ['mistCloak'] });
  mist = act(mist, { type: 'endTurn' }); mist = act(mist, { type: 'endTurn' }); mist = act(mist, { type: 'endTurn' });
  assert.equal(mist.player.health, 50);

  let phoenix = createBattle(45, content, { enemyHealth: 100, enemyDamage: 100, equipmentIds: ['phoenixMail'] });
  phoenix = act(phoenix, { type: 'endTurn' }); assert.equal(phoenix.player.health, 15); assert.equal(phoenix.phase, 'playerTurn');
});
test('custom decks and pile interaction cards change draw, discard, and exhaust piles', () => {
  const deck = ['foxfire', 'ashRecall', 'spiritCurrent', 'strike', 'strike', 'ward', 'ward', 'focus'];
  let s = createBattle(7, content, { deck });
  assert.equal([...s.hand, ...s.drawPile].length, deck.length);
  s.hand = [
    { id: 100, definitionID: 'ashRecall' },
    { id: 101, definitionID: 'spiritCurrent' },
  ];
  s.drawPile = [{ id: 102, definitionID: 'strike' }, { id: 103, definitionID: 'ward' }];
  s.discardPile = [{ id: 104, definitionID: 'focus' }, { id: 105, definitionID: 'strike' }];
  s.exhaustPile = [{ id: 106, definitionID: 'foxfire' }];
  s = act(s, { type: 'play', id: 100 });
  assert.ok(s.hand.some(card => card.definitionID === 'foxfire'));
  assert.equal(s.exhaustPile.length, 0);
  s = act(s, { type: 'play', id: 101 });
  assert.ok(s.hand.length >= 2);
  assert.ok(s.discardPile.length < 3);
});
test('Burn ticks after enemy attack and decays', () => {
  let s = play(withCards('foxfire'), 'foxfire');
  assert.equal(s.enemies[0].health, 36); assert.equal(s.enemies[0].statuses.burn, 3);
  assert.equal(s.exhaustPile.some(card => card.definitionID === 'foxfire'), true);
  s = act(s, { type: 'endTurn' });
  assert.equal(s.enemies[0].health, 33); assert.equal(s.enemies[0].statuses.burn, 2); assert.equal(s.player.health, 53);
});
test('Focus buffs the next attack once', () => {
  let s = play(withCards('focus', 'strike'), 'focus');
  s = play(s, 'strike'); assert.equal(s.enemies[0].health, 31); assert.equal(s.player.statuses.focus, undefined);
});
test('shield absorbs attack then expires', () => {
  const s = act(play(withCards('ward'), 'ward'), { type: 'endTurn' });
  assert.equal(s.player.health, 58); assert.equal(s.player.shield, 0);
});
test('encounter setup scales enemy attack and preserves run health', () => {
  let s = createBattle(8, content, { enemyHealth: 72, enemyDamage: 11, playerHealth: 41, playerMaxHealth: 60 });
  assert.equal(s.enemies[0].health, 72); assert.equal(s.enemies[0].damage, 11); assert.equal(s.player.health, 41);
  s = act(s, { type: 'endTurn' });
  assert.equal(s.player.health, 30);
});
test('encounter mechanics apply shield, thorns, and enrage', () => {
  let armored = createBattle(11, content, { mechanics: { enemyShieldPerTurn: 3 } });
  assert.equal(armored.enemies[0].shield, 3);
  armored = act(armored, { type: 'endTurn' });
  assert.equal(armored.enemies[0].shield, 3);

  let thorny = createBattle(12, content, { mechanics: { thornsDamage: 2 } });
  const attack = thorny.hand.find(card => card.definitionID === 'strike' || card.definitionID === 'foxfire')!;
  thorny = act(thorny, { type: 'play', id: attack.id });
  assert.equal(thorny.player.health, 58);

  let enraged = createBattle(13, content, { enemyDamage: 5, mechanics: { enragePerTurn: 1 } });
  enraged = act(enraged, { type: 'endTurn' });
  assert.equal(enraged.enemies[0].damage, 6);
  enraged = act(enraged, { type: 'endTurn' });
  assert.equal(enraged.enemies[0].damage, 7);
});
test('boss intent previews critical hits and half-health overload', () => {
  let critical = createBattle(14, content, { enemyDamage: 6, mechanics: { criticalEvery: 3, criticalMultiplier: 2 } });
  assert.deepEqual(enemyAttackPreview(critical), { damage: 6, critical: false, empowered: false });
  critical = act(critical, { type: 'endTurn' });
  critical = act(critical, { type: 'endTurn' });
  assert.deepEqual(enemyAttackPreview(critical), { damage: 12, critical: true, empowered: false });
  const healthBeforeCritical = critical.player.health;
  critical = act(critical, { type: 'endTurn' });
  assert.equal(critical.player.health, healthBeforeCritical - 12);

  const overloaded = createBattle(15, content, { enemyHealth: 20, enemyDamage: 5, mechanics: { belowHalfBonus: 3 } });
  overloaded.enemies[0].health = 10;
  assert.deepEqual(enemyAttackPreview(overloaded), { damage: 8, critical: false, empowered: true });
});
test('element, pierce, cleave, dodge, stun, and regeneration mechanics resolve', () => {
  let elemental = createBattle(51, content, { deck: Array(15).fill('stoneBreaker'), enemies: [{ id: 'fire', element: 'fire', health: 40, damage: 0 }] });
  elemental = act(elemental, { type: 'play', id: elemental.hand[0].id, targetId: 'fire' });
  assert.equal(elemental.enemies[0].health, 28);

  let pierce = createBattle(52, content, { deck: Array(15).fill('spiritLance'), enemies: [{ id: 'stone', element: 'stone', health: 40, damage: 0, mechanics: { enemyShieldPerTurn: 10 } }] });
  pierce = act(pierce, { type: 'play', id: pierce.hand[0].id, targetId: 'stone' });
  assert.equal(pierce.enemies[0].health, 28); assert.equal(pierce.enemies[0].shield, 10);

  let cleave = createBattle(53, content, { deck: Array(15).fill('stormArc'), enemies: [{ id: 'a', health: 20, damage: 0 }, { id: 'b', health: 20, damage: 0 }] });
  cleave = act(cleave, { type: 'play', id: cleave.hand[0].id, targetId: 'a' });
  assert.deepEqual(cleave.enemies.map(enemy => enemy.health), [15, 15]);

  let dodge = createBattle(54, content, { deck: Array(15).fill('twinMoon'), enemies: [{ id: 'mist', health: 20, damage: 0, mechanics: { dodgeEvery: 2 } }] });
  dodge = act(dodge, { type: 'play', id: dodge.hand[0].id, targetId: 'mist' });
  assert.equal(dodge.enemies[0].health, 16);

  let control = createBattle(55, content, { deck: Array(15).fill('mountainSeal'), enemies: [{ id: 'renewing', health: 20, damage: 9, mechanics: { regenerationPerTurn: 3 } }] });
  control = act(control, { type: 'play', id: control.hand[0].id, targetId: 'renewing' });
  const playerHealth = control.player.health; control = act(control, { type: 'endTurn' });
  assert.equal(control.player.health, playerHealth); assert.equal(control.enemies[0].health, 20);
});
test('defeat prevents further actions', () => {
  let s = createBattle(0); for (let i = 0; i < 9; i++) s = act(s, { type: 'endTurn' });
  assert.equal(s.phase, 'lost'); assert.equal(s.player.health, 0);
  assert.throws(() => act(s, { type: 'endTurn' }), /error.finished/);
});
test('training battle is winnable', () => {
  let s = createBattle(42);
  const rank: Record<string, number> = { foxfire: 0, strike: 1, focus: 2, ward: 3 };
  for (let turn = 0; turn < 20 && s.phase === 'playerTurn'; turn++) {
    for (const card of [...s.hand].sort((a, b) => rank[a.definitionID] - rank[b.definitionID])) {
      if (s.energy && s.actionsRemaining && s.phase === 'playerTurn') s = act(s, { type: 'play', id: card.id });
    }
    if (s.phase === 'playerTurn') s = act(s, { type: 'endTurn' });
  }
  assert.equal(s.phase, 'won'); assert.equal(s.enemies[0].health, 0);
});
test('unplayed cards remain and the next turn refills the hand to five', () => {
  let s = createBattle(42);
  const kept = s.hand.slice(2).map(card => card.id);
  s = act(s, { type: 'play', id: s.hand[0].id });
  s = act(s, { type: 'play', id: s.hand[0].id });
  s = act(s, { type: 'endTurn' });
  assert.equal(s.hand.length, 5);
  assert.ok(kept.every(id => s.hand.some(card => card.id === id)));
});
test('cards can target one enemy while harmful and beneficial mis-targets are rejected', () => {
  let s: State | undefined;
  for (let seed = 0; seed < 100 && !s; seed++) {
    const candidate = createBattle(seed, content, { enemies: [
      { id: 'left', health: 20, damage: 2 },
      { id: 'right', health: 20, damage: 2 },
    ] });
    if (candidate.hand.some(card => card.definitionID === 'strike') && candidate.hand.some(card => card.definitionID === 'ward')) s = candidate;
  }
  assert.ok(s);
  const strike = s!.hand.find(card => card.definitionID === 'strike')!;
  const ward = s!.hand.find(card => card.definitionID === 'ward')!;
  const targeted = act(s!, { type: 'play', id: strike.id, targetId: 'right' });
  assert.equal(targeted.enemies[0].health, 20);
  assert.equal(targeted.enemies[1].health, 14);
  assert.throws(() => act(s!, { type: 'play', id: strike.id, targetId: 'player' }), /error.targetSelf/);
  assert.throws(() => act(s!, { type: 'play', id: ward.id, targetId: 'right' }), /error.targetEnemy/);
  s!.enemies[1].health = 8;
  const smartAttack = act(s!, { type: 'play', id: strike.id });
  assert.equal(smartAttack.enemies[0].health, 20);
  assert.equal(smartAttack.enemies[1].health, 2);
  const smartBuff = act(s!, { type: 'play', id: ward.id });
  assert.equal(smartBuff.player.shield, 5);
});
test('bilingual descriptions resolve all tokens', () => {
  assert.deepEqual(Object.keys(content.translations.en).sort(), Object.keys(content.translations['zh-Hans']).sort());
  for (const language of ['en', 'zh-Hans']) for (const card of content.cards) {
    const text = description(card, language);
    assert.ok(!text.includes('{')); assert.ok(!text.includes('effect.'));
    for (const effect of card.effects) assert.ok(text.includes(String(effect.amount)));
  }
});
