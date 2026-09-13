export type RelicId = 'emberCore' | 'jadeBell' | 'moonLens' | 'stormFeather' | 'pilgrimCoin';
export type LeaderId = 'fox' | 'warden' | 'oracle';
export type NodeKind = 'battle' | 'event' | 'elite' | 'rest' | 'merchant' | 'boss';
export type ModifierId = 'reinforced' | 'frenzy' | 'swarm' | 'rebirth' | 'eclipse';
export type EncounterModifier = { id: ModifierId; icon: string; healthScale: number; damageBonus: number; rewardScale: number; extraEnemy?: boolean; reviveChance?: number; en: string; zh: string; detailEn: string; detailZh: string };

export const relics: Array<{ id: RelicId; icon: string; en: string; zh: string; detailEn: string; detailZh: string }> = [
  { id: 'emberCore', icon: '♨', en: 'Ember Core', zh: '烬火核心', detailEn: 'Begin with 1 Focus; Fire cards count as upgraded.', detailZh: '战斗开始获得 1 层凝神；火属性牌视为已强化。' },
  { id: 'jadeBell', icon: '◆', en: 'Jade Bell', zh: '翠玉灵铃', detailEn: 'Begin with 7 Shield; Shield cards count as upgraded.', detailZh: '战斗开始获得 7 点护盾；护盾牌视为已强化。' },
  { id: 'moonLens', icon: '◉', en: 'Moon Lens', zh: '望月灵镜', detailEn: 'Reveal full enemy intent order.', detailZh: '显示完整敌方行动顺序。' },
  { id: 'stormFeather', icon: 'ϟ', en: 'Storm Feather', zh: '风暴翎羽', detailEn: 'Draw one additional opening card.', detailZh: '起手额外抽一张牌。' },
  { id: 'pilgrimCoin', icon: '✦', en: 'Pilgrim Coin', zh: '旅者古币', detailEn: 'Victory grants 20% more gold.', detailZh: '胜利金币增加 20%。' },
];

export const leaders: Array<{ id: LeaderId; icon: string; en: string; zh: string; detailEn: string; detailZh: string }> = [
  { id: 'fox', icon: '♨', en: 'Crimson Fox', zh: '绯狐', detailEn: 'First attack starts empowered by Focus.', detailZh: '首张攻击受凝神强化。' },
  { id: 'warden', icon: '◆', en: 'Jade Warden', zh: '翠玉守卫', detailEn: 'Begin every combat with 10 Shield.', detailZh: '每场战斗开始时获得 10 点护盾。' },
  { id: 'oracle', icon: '☾', en: 'Moon Oracle', zh: '月相先知', detailEn: 'Draw one additional opening card.', detailZh: '每场战斗起手额外抽一张牌。' },
];

export const encounterModifiers: EncounterModifier[] = [
  { id: 'reinforced', icon: '⬢', healthScale: 1.3, damageBonus: 0, rewardScale: 1.35, en: 'Reinforced Host', zh: '重甲军势', detailEn: 'Enemies have 30% more Health. Reward +35%.', detailZh: '敌人生命提高 30%，奖励提高 35%。' },
  { id: 'frenzy', icon: '♨', healthScale: 1, damageBonus: 3, rewardScale: 1.3, en: 'Blood Moon', zh: '血月狂怒', detailEn: 'Enemy attacks gain 3 damage. Reward +30%.', detailZh: '敌方攻击提高 3 点，奖励提高 30%。' },
  { id: 'swarm', icon: '♟', healthScale: 1.08, damageBonus: 0, rewardScale: 1.4, extraEnemy: true, en: 'Hunting Pack', zh: '狩猎群落', detailEn: 'An additional enemy joins. Reward +40%.', detailZh: '额外出现一名敌人，奖励提高 40%。' },
  { id: 'rebirth', icon: '✥', healthScale: 1.1, damageBonus: 1, rewardScale: 1.5, reviveChance: .45, en: 'Undying Ember', zh: '不灭余烬', detailEn: 'One enemy may revive at 35% Health. Reward +50%.', detailZh: '一名敌人可能以 35% 生命复活，奖励提高 50%。' },
  { id: 'eclipse', icon: '◐', healthScale: 1.18, damageBonus: 2, rewardScale: 1.45, en: 'Spirit Eclipse', zh: '灵蚀天象', detailEn: 'Enemies gain Health and damage. Reward +45%.', detailZh: '敌人同时强化生命与伤害，奖励提高 45%。' },
];

export function rollEncounterModifier(seed: number, stageIndex: number): EncounterModifier | undefined {
  let value = (seed ^ Math.imul(stageIndex + 1, 0x9e3779b1)) >>> 0;
  value ^= value >>> 16; value = Math.imul(value, 0x7feb352d) >>> 0; value ^= value >>> 15;
  if (value % 100 < 48) return undefined;
  return encounterModifiers[Math.floor(value / 100) % encounterModifiers.length];
}

export function nodeKindFor(index: number): NodeKind {
  const level = index % 5 + 1; const chapter = Math.floor(index / 5) + 1;
  if (level === 5) return 'boss';
  if (level === 3) return 'elite';
  if (level === 2) return chapter % 2 ? 'event' : 'merchant';
  if (level === 4) return 'rest';
  return 'battle';
}

export function nodeIcon(kind: NodeKind) {
  return ({ battle: '✦', event: '?', elite: '♜', rest: '♨', merchant: '◆', boss: '♛' } as const)[kind];
}

export function dailyStage(date = new Date()) {
  const day = Math.floor(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) / 86400000);
  return (day * 17 + 11) % 50;
}
