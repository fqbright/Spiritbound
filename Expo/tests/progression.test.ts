import test from 'node:test';
import assert from 'node:assert/strict';
import { act, content, createBattle } from '../src/combat';
import { dailyStage, encounterModifiers, nodeKindFor, rollEncounterModifier } from '../src/progression';
import { encounters, makeEncounter } from '../src/run';

test('the route contains meaningful node types and deterministic daily stages', () => {
  assert.deepEqual([0, 1, 2, 3, 4].map(nodeKindFor), ['battle', 'event', 'elite', 'rest', 'boss']);
  assert.deepEqual([5, 6, 7, 8, 9].map(nodeKindFor), ['battle', 'merchant', 'elite', 'rest', 'boss']);
  assert.equal(dailyStage(new Date('2026-09-12T03:00:00Z')), dailyStage(new Date('2026-09-12T23:59:00Z')));
});

test('campaign pressure starts on stage two and ascension scales both health and damage', () => {
  assert.equal(encounters[0].damage, 4);
  assert.ok(encounters[1].damage >= 7);
  assert.ok(encounters[18].damage >= 11);
  const normal = makeEncounter(8, 77, 60);
  const ascended = makeEncounter(8, 77, 60, content.startingDeck, 3);
  assert.ok(ascended.enemies[0].health > normal.enemies[0].health);
  assert.equal(ascended.enemies[0].damage, normal.enemies[0].damage + 6);
});

test('leaders, relics, and card upgrades have battle effects', () => {
  const warden = makeEncounter(0, 4, 60, content.startingDeck, 0, ['jadeBell'], 'warden');
  assert.equal(warden.player.shield, 17);
  const oracle = makeEncounter(0, 4, 60, content.startingDeck, 0, ['stormFeather'], 'oracle');
  assert.equal(oracle.hand.length, 7);

  const battle = createBattle(5, content, { enemyHealth: 30, enemyDamage: 0, deck: Array(15).fill('strike'), upgrades: { strike: 1 } });
  const played = act(battle, { type: 'play', id: battle.hand[0].id, targetId: battle.enemies[0].id });
  assert.equal(played.enemies[0].health, 23);

  const linked = makeEncounter(0, 5, 60, content.startingDeck, 0, ['emberCore']);
  assert.equal(linked.upgrades.foxfire, 1);

  const equipped = makeEncounter(0, 6, 60, content.startingDeck, 0, [], 'fox', {}, undefined, ['jadePlate', 'tideCharm', 'focusCharm']);
  assert.equal(equipped.player.shield, 8); assert.equal(equipped.hand.length, 6); assert.equal(equipped.player.statuses.focus, 2);
});

test('encounter modifiers are deterministic and exchange extra danger for rewards', () => {
  assert.deepEqual(rollEncounterModifier(9182, 12), rollEncounterModifier(9182, 12));
  assert.ok(encounterModifiers.every(modifier => modifier.rewardScale > 1));
  const swarm = encounterModifiers.find(modifier => modifier.id === 'swarm')!;
  const normal = makeEncounter(0, 99, 60); const crowded = makeEncounter(0, 99, 60, content.startingDeck, 0, [], 'fox', {}, swarm);
  assert.equal(crowded.enemies.length, normal.enemies.length + 1);
  assert.ok(crowded.enemies[0].health > normal.enemies[0].health);
});

test('a finite deck ends in defeat when every card has been spent', () => {
  let battle = createBattle(9, content, { enemyHealth: 999, enemyDamage: 0, deck: ['ward'] });
  battle = act(battle, { type: 'play', id: battle.hand[0].id, targetId: 'player' });
  battle = act(battle, { type: 'endTurn' });
  assert.equal(battle.phase, 'lost');
});
