export type EquipmentSlot = 'weapon' | 'armor' | 'charm';
export type EquipmentId = 'emberBlade' | 'moonStaff' | 'stoneSpear' | 'stormBow' | 'jadePlate' | 'thornArmor' | 'mistCloak' | 'phoenixMail' | 'soulPendant' | 'tideCharm' | 'fortuneSeal' | 'focusCharm';
export type RuneId = 'swift' | 'chain' | 'echo' | 'siphon' | 'burning' | 'guardian' | 'cycle' | 'cleanse' | 'execute' | 'resonance';
export type EquipmentDefinition = { id: EquipmentId; slot: EquipmentSlot; rarity: 'Common' | 'Rare' | 'Epic'; icon: string; en: string; zh: string; detailEn: string; detailZh: string };
export type RuneDefinition = { id: RuneId; icon: string; color: string; en: string; zh: string; detailEn: string; detailZh: string };

export const equipment: EquipmentDefinition[] = [
  { id: 'emberBlade', slot: 'weapon', rarity: 'Common', icon: '⚔', en: 'Ember Blade', zh: '烬火长刀', detailEn: 'First Attack each turn deals +3 damage.', detailZh: '每回合第一张攻击牌伤害 +3。' },
  { id: 'moonStaff', slot: 'weapon', rarity: 'Rare', icon: '☾', en: 'Moon Staff', zh: '月纹法杖', detailEn: 'First Tactic each turn restores 1 Energy.', detailZh: '每回合第一张策略牌返还 1 点能量。' },
  { id: 'stoneSpear', slot: 'weapon', rarity: 'Rare', icon: '➹', en: 'Stonepiercer', zh: '破岩灵枪', detailEn: 'Attack cards ignore enemy Shield.', detailZh: '攻击牌无视敌方护盾。' },
  { id: 'stormBow', slot: 'weapon', rarity: 'Epic', icon: 'ϟ', en: 'Storm Bow', zh: '逐电长弓', detailEn: 'Draw 1 card whenever an enemy is defeated.', detailZh: '每击败一名敌人抽 1 张牌。' },
  { id: 'jadePlate', slot: 'armor', rarity: 'Common', icon: '⬢', en: 'Jade Plate', zh: '翠玉战甲', detailEn: 'Begin combat with 8 Shield.', detailZh: '战斗开始时获得 8 点护盾。' },
  { id: 'thornArmor', slot: 'armor', rarity: 'Rare', icon: '✣', en: 'Thorn Armor', zh: '荆棘铠甲', detailEn: 'After an enemy hurts you, deal 2 damage back.', detailZh: '敌人对你造成生命伤害后，反击 2 点伤害。' },
  { id: 'mistCloak', slot: 'armor', rarity: 'Rare', icon: '≈', en: 'Mist Cloak', zh: '流雾披风', detailEn: 'Negate every third enemy attack.', detailZh: '每第三次敌方攻击伤害归零。' },
  { id: 'phoenixMail', slot: 'armor', rarity: 'Epic', icon: '♨', en: 'Phoenix Mail', zh: '涅槃羽衣', detailEn: 'Once per battle, survive lethal damage at 15 Health.', detailZh: '每场战斗一次，受到致命伤害时以 15 点生命存活。' },
  { id: 'soulPendant', slot: 'charm', rarity: 'Common', icon: '◇', en: 'Soul Pendant', zh: '猎魂坠饰', detailEn: 'Defeating an enemy heals 2 Health, up to 3 times.', detailZh: '击败敌人回复 2 点生命，每场最多 3 次。' },
  { id: 'tideCharm', slot: 'charm', rarity: 'Rare', icon: '≋', en: 'Tide Charm', zh: '灵潮玉佩', detailEn: 'Draw 1 additional opening card.', detailZh: '起手额外抽 1 张牌。' },
  { id: 'fortuneSeal', slot: 'charm', rarity: 'Rare', icon: '◆', en: 'Fortune Seal', zh: '旅运金印', detailEn: 'Victory grants 15% more gold.', detailZh: '胜利金币增加 15%。' },
  { id: 'focusCharm', slot: 'charm', rarity: 'Epic', icon: '◉', en: 'Focus Lens', zh: '凝神灵镜', detailEn: 'Begin combat with 1 Focus.', detailZh: '战斗开始时获得 1 层凝神。' },
];

export const runes: RuneDefinition[] = [
  { id: 'swift', icon: '»', color: '#78E9FF', en: 'Swift', zh: '迅捷', detailEn: 'First use each turn does not spend an action.', detailZh: '每回合第一次使用时不消耗出牌次数。' },
  { id: 'chain', icon: '⌁', color: '#A2D9FF', en: 'Chain', zh: '连锁', detailEn: '40% of single-target damage strikes another enemy.', detailZh: '单体伤害的 40% 传递给另一名敌人。' },
  { id: 'echo', icon: '◎', color: '#D1A8FF', en: 'Echo', zh: '回响', detailEn: 'Repeat card effects at 50% strength.', detailZh: '以 50% 数值重复一次卡牌效果。' },
  { id: 'siphon', icon: '◒', color: '#80E4C0', en: 'Siphon', zh: '吸魂', detailEn: 'Gain Shield equal to 25% of damage dealt.', detailZh: '获得相当于伤害 25% 的护盾。' },
  { id: 'burning', icon: '♨', color: '#FF9868', en: 'Burning', zh: '灼烧', detailEn: 'Damaging cards apply 2 Burn.', detailZh: '伤害牌额外施加 2 层燃烧。' },
  { id: 'guardian', icon: '⬡', color: '#8FF5CF', en: 'Guardian', zh: '守御', detailEn: 'Playing this card grants 4 Shield.', detailZh: '使用该牌时额外获得 4 点护盾。' },
  { id: 'cycle', icon: '↻', color: '#FFD47C', en: 'Cycle', zh: '循环', detailEn: 'After use, place it at the bottom of the draw pile.', detailZh: '使用后放到抽牌堆底部。' },
  { id: 'cleanse', icon: '✦', color: '#F7F0BD', en: 'Cleanse', zh: '净化', detailEn: 'Playing this card removes Burn from the player.', detailZh: '使用该牌时移除玩家身上的燃烧。' },
  { id: 'execute', icon: '✕', color: '#FF7373', en: 'Execute', zh: '处决', detailEn: 'Deal 50% more damage to enemies below 25% Health.', detailZh: '对低于 25% 生命的敌人伤害提高 50%。' },
  { id: 'resonance', icon: '◈', color: '#B9A2FF', en: 'Resonance', zh: '共鸣', detailEn: 'Gain +1 value for each matching Element card played this turn.', detailZh: '本回合每使用过一张同属性牌，数值 +1。' },
];

export const equipmentById = (id?: string) => equipment.find(item => item.id === id);
export const runeById = (id?: string) => runes.find(item => item.id === id);
export const bossEquipmentOrder: EquipmentId[] = ['emberBlade', 'jadePlate', 'soulPendant', 'moonStaff', 'thornArmor', 'tideCharm', 'stoneSpear', 'mistCloak', 'fortuneSeal', 'stormBow', 'phoenixMail', 'focusCharm'];
export const defaultEquipment: Partial<Record<EquipmentSlot, EquipmentId>> = {};
