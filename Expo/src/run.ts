import { content, createBattle, Element, EnemySetup, EncounterMechanics, State } from './combat';
import { EncounterModifier, LeaderId, RelicId } from './progression';
import { EquipmentId, RuneId } from './loadout';

export type Encounter = {
  chapter: number; level: number; backgroundIndex: number; nameKey: string;
  health: number; damage: number; reward: number; tint: string; artKey: string;
  element?: Element; mechanicKey: string; mechanics: Partial<EncounterMechanics>; adds: EnemySetup[];
};

const enemies = [
  { nameKey: 'enemy.name', tint: '#83E4C1', artKey: 'sentinel' },
  { nameKey: 'enemy.sentinel2', tint: '#75D7D2', artKey: 'lanternstone' },
  { nameKey: 'enemy.sentinel3', tint: '#A3C8FF', artKey: 'runebound' },
  { nameKey: 'enemy.sentinel4', tint: '#F0B16D', artKey: 'embercliff' },
  { nameKey: 'enemy.sentinel5', tint: '#E67C65', artKey: 'mountainHeart' },
] as const;

const chapterRules: Array<{ mechanicKey: string; element?: Element; mechanics: Partial<EncounterMechanics> }> = [
  { mechanicKey: 'mechanic.chapter1', mechanics: {} },
  { mechanicKey: 'mechanic.chapter2', element: 'fire', mechanics: {} },
  { mechanicKey: 'mechanic.chapter3', mechanics: { criticalEvery: 3, criticalMultiplier: 2 } },
  { mechanicKey: 'mechanic.chapter4', element: 'stone', mechanics: { enemyShieldPerTurn: 4 } },
  { mechanicKey: 'mechanic.chapter5', mechanics: { thornsDamage: 1 } },
  { mechanicKey: 'mechanic.chapter6', element: 'spirit', mechanics: {} },
  { mechanicKey: 'mechanic.chapter7', mechanics: { regenerationPerTurn: 3 } },
  { mechanicKey: 'mechanic.chapter8', mechanics: { dodgeEvery: 3 } },
  { mechanicKey: 'mechanic.chapter9', mechanics: { enragePerTurn: 1 } },
  { mechanicKey: 'mechanic.chapter10', element: 'fire', mechanics: { enemyShieldPerTurn: 3, criticalEvery: 3, criticalMultiplier: 2, belowHalfBonus: 3 } },
];

export const chapterRewardCardIds = ['stoneBreaker', 'calmWard', 'spiritLance', 'cinderHex', 'stormArc', 'soulBrand', 'twinMoon', 'finalFlare', 'mountainSeal', 'worldFlame'];

export const encounters: Encounter[] = Array.from({ length: 50 }, (_, index) => {
  const chapter = Math.floor(index / 5) + 1; const level = index % 5 + 1;
  const enemy = enemies[(chapter + level - 2) % enemies.length]; const rule = chapterRules[chapter - 1];
  const adds: EnemySetup[] = [];
  if ((chapter >= 3 && level === 3) || (chapter >= 6 && level >= 2)) adds.push({ id: `add-a-${index}`, nameKey: 'enemy.forgeSpark', artKey: 'forgeSpark', tint: '#FFB05C', element: rule.element, health: 5 + chapter, damage: 1 + Math.floor(chapter / 3) });
  if ((chapter >= 5 && level === 5) || (chapter === 10 && level >= 4)) adds.push({ id: `add-b-${index}`, nameKey: 'enemy.runeShard', artKey: 'runeShard', tint: '#9EA7FF', element: rule.element, health: 7 + chapter, damage: 2 + Math.floor(chapter / 4) });
  return {
    chapter, level, backgroundIndex: (chapter - 1) % 5, ...enemy, element: rule.element,
    health: 24 + level * 5 + (chapter - 1) * 7,
    damage: 3 + level + (level >= 2 ? 2 : 0) + Math.floor((chapter - 1) * 0.75),
    reward: 16 + chapter * 5 + level * 2,
    mechanicKey: rule.mechanicKey,
    mechanics: { ...rule.mechanics, ...(level === 5 && chapter > 2 ? { belowHalfBonus: (rule.mechanics.belowHalfBonus ?? 0) + 1 } : {}) },
    adds,
  };
});

export const betweenFightHeal = 10;
export function healthForNextEncounter(currentHealth: number) { return Math.min(content.rules.playerHealth, currentHealth + betweenFightHeal); }

export function makeEncounter(index: number, seed: number, playerHealth = content.rules.playerHealth, deck = content.startingDeck, difficulty = 0, relicIds: RelicId[] = [], leader: LeaderId = 'fox', upgrades: Record<string, number> = {}, modifier?: EncounterModifier, equipmentIds: EquipmentId[] = [], cardRunes: Partial<Record<string, RuneId>> = {}): State {
  const encounter = encounters[index]; if (!encounter) throw Error('Invalid encounter');
  const healthScale = (1 + Math.max(0, difficulty) * 0.15) * (modifier?.healthScale ?? 1); const damageBonus = Math.max(0, difficulty) * 2 + (modifier?.damageBonus ?? 0);
  const formations: EnemySetup[] = [{
    id: `boss-${index + 1}`, nameKey: encounter.nameKey, artKey: encounter.artKey, tint: encounter.tint,
    element: encounter.element, health: Math.round(encounter.health * healthScale), damage: encounter.damage + damageBonus, mechanics: encounter.mechanics,
  }, ...encounter.adds.map(enemy => ({ ...enemy, health: Math.round(enemy.health * healthScale), damage: enemy.damage + damageBonus }))];
  if (modifier?.extraEnemy) formations.push({ id: `modifier-add-${index}`, nameKey: 'enemy.ashRaven', artKey: 'ashRaven', tint: '#D77866', element: encounter.element, health: Math.round((8 + encounter.chapter) * healthScale), damage: 2 + Math.floor(encounter.chapter / 3) + damageBonus });
  const linkedUpgrades = { ...upgrades };
  for (const id of new Set(deck)) {
    const card = content.cards.find(item => item.id === id); if (!card) continue;
    const emberLink = relicIds.includes('emberCore') && card.element === 'fire';
    const jadeLink = relicIds.includes('jadeBell') && card.effects.some(effect => effect.operation === 'shield');
    if (emberLink || jadeLink) linkedUpgrades[id] = Math.max(1, linkedUpgrades[id] ?? 0);
  }
  const state = createBattle(seed, content, { playerHealth, playerMaxHealth: content.rules.playerHealth, deck, upgrades: linkedUpgrades, reviveChance: modifier?.reviveChance, equipmentIds, cardRunes, enemies: formations });
  const openingFocus = (leader === 'fox' ? 1 : 0) + (relicIds.includes('emberCore') ? 1 : 0);
  if (openingFocus) state.player.statuses.focus = (state.player.statuses.focus ?? 0) + openingFocus;
  if (leader === 'warden') state.player.shield += 10;
  if (relicIds.includes('jadeBell')) state.player.shield += 7;
  if (equipmentIds.includes('jadePlate')) state.player.shield += 8;
  if (equipmentIds.includes('focusCharm')) state.player.statuses.focus = (state.player.statuses.focus ?? 0) + 1;
  const extraDraw = (leader === 'oracle' ? 1 : 0) + (relicIds.includes('stormFeather') ? 1 : 0) + (equipmentIds.includes('tideCharm') ? 1 : 0);
  for (let draw = 0; draw < extraDraw && state.drawPile.length && state.hand.length < content.rules.handLimit; draw++) state.hand.push(state.drawPile.pop()!);
  return state;
}
