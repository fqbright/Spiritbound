import test from 'node:test';
import assert from 'node:assert/strict';
import { content } from '../src/combat';
import { betweenFightHeal, chapterRewardCardIds, encounters, healthForNextEncounter, makeEncounter } from '../src/run';

test('encounters increase total enemy health and add new formations', () => {
  assert.equal(encounters.length, 50);
  assert.deepEqual([...new Set(encounters.map(encounter => encounter.chapter))], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.equal(new Set(encounters.map(encounter => encounter.mechanicKey)).size, 10);
  assert.equal(chapterRewardCardIds.length, 10);
  assert.ok(chapterRewardCardIds.every(id => content.cards.some(card => card.id === id)));
  for (const chapter of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
    assert.deepEqual(encounters.filter(encounter => encounter.chapter === chapter).map(encounter => encounter.level), [1, 2, 3, 4, 5]);
  }
  for (let level = 1; level <= 5; level++) {
    const health = encounters.filter(encounter => encounter.level === level).map(encounter => encounter.health + encounter.adds.reduce((sum, enemy) => sum + enemy.health, 0));
    assert.ok(health.every((value, index) => index === 0 || value > health[index - 1]));
  }
  assert.ok(encounters.some(encounter => encounter.adds.length === 1));
  assert.ok(encounters.some(encounter => encounter.adds.length === 2));
});

test('the next encounter carries health forward with a capped recovery', () => {
  assert.equal(betweenFightHeal, 10);
  assert.equal(healthForNextEncounter(21), 21 + betweenFightHeal);
  assert.equal(healthForNextEncounter(58), content.rules.playerHealth);

  const battle = makeEncounter(29, 1234, 29);
  assert.equal(battle.player.health, 29);
  assert.equal(battle.enemies[0].health, encounters[29].health);
  assert.equal(battle.enemies[0].damage, encounters[29].damage);
  assert.equal(battle.enemies.length, 3);
});
