import raw from '../../Sources/SpiritboundCore/Resources/core.json';
import type { EquipmentId, RuneId } from './loadout';

export type Event = 'turnStart' | 'turnEnd' | 'cardPlayed' | 'drawn' | 'damaged' | 'death';
export type Effect = { operation: 'damage' | 'shield' | 'draw' | 'energy' | 'status' | 'heal'; target: 'actor' | 'opponent'; amount: number; status?: string };
export type Element = 'fire' | 'spirit' | 'stone';
export type CardKind = 'Attack' | 'Skill' | 'Power' | 'Tactic';
export type Card = { id: string; nameKey: string; rarity: string; pool: string; kind?: CardKind; element?: Element; cost: number; exhaust: boolean; special?: 'recycleDiscard' | 'recoverExhaust' | 'pierce' | 'cleave' | 'critical' | 'stun'; effects: Effect[] };
export type Status = { id: string; trigger: Event; effect: Effect; scaleWithStacks: boolean; decay: number; nextAttackBonus?: number };
export type Content = { rules: { energy: number; draw: number; handLimit: number; playerHealth: number; enemyHealth: number; enemyDamage: number }; cards: Card[]; statuses: Status[]; startingDeck: string[]; translations: Record<string, Record<string, string>> };
export const content = raw as Content;

export type Unit = { health: number; maxHealth: number; shield: number; statuses: Record<string, number> };
export type EncounterMechanics = {
  enemyShieldPerTurn: number;
  thornsDamage: number;
  enragePerTurn: number;
  criticalEvery: number;
  criticalMultiplier: number;
  belowHalfBonus: number;
  regenerationPerTurn: number;
  dodgeEvery: number;
};
export type EnemySetup = { id?: string; nameKey?: string; artKey?: string; tint?: string; element?: Element; health: number; damage: number; mechanics?: Partial<EncounterMechanics> };
export type EnemyUnit = Unit & { id: string; nameKey: string; artKey: string; tint: string; element?: Element; damage: number; attacksMade: number; hitsTaken: number; revived: boolean; mechanics: EncounterMechanics };
export type Instance = { id: number; definitionID: string };
export type Pile = 'drawPile' | 'discardPile' | 'exhaustPile';
export type State = { player: Unit; enemies: EnemyUnit[]; drawPile: Instance[]; hand: Instance[]; discardPile: Instance[]; exhaustPile: Instance[]; upgrades: Record<string, number>; equipmentIds: EquipmentId[]; cardRunes: Partial<Record<string, RuneId>>; equipmentCounters: { mistHits: number; soulHeals: number; phoenixUsed: boolean }; swiftUsed: boolean; moonStaffUsed: boolean; firstAttackUsed: boolean; turnElements: Partial<Record<Element, number>>; reviveChance: number; revivesRemaining: number; energy: number; actionsPerTurn: number; actionsRemaining: number; turn: number; phase: 'playerTurn' | 'won' | 'lost'; rng: number };
export type BattleSetup = { enemyHealth?: number; enemyDamage?: number; playerHealth?: number; playerMaxHealth?: number; actionsPerTurn?: number; mechanics?: Partial<EncounterMechanics>; enemies?: EnemySetup[]; deck?: string[]; upgrades?: Record<string, number>; reviveChance?: number; equipmentIds?: EquipmentId[]; cardRunes?: Partial<Record<string, RuneId>> };
export type Action = { type: 'play'; id: number; targetId?: string } | { type: 'endTurn' };
export type CardTarget = 'player' | 'enemy' | 'either';
export const defaultActionsPerTurn = 2;

const mechanics = (input: Partial<EncounterMechanics> = {}): EncounterMechanics => ({
  enemyShieldPerTurn: input.enemyShieldPerTurn ?? 0,
  thornsDamage: input.thornsDamage ?? 0,
  enragePerTurn: input.enragePerTurn ?? 0,
  criticalEvery: input.criticalEvery ?? 0,
  criticalMultiplier: input.criticalMultiplier ?? 2,
  belowHalfBonus: input.belowHalfBonus ?? 0,
  regenerationPerTurn: input.regenerationPerTurn ?? 0,
  dodgeEvery: input.dodgeEvery ?? 0,
});

function elementalMultiplier(card?: Element, enemy?: Element) {
  if (!card || !enemy || card === enemy) return 1;
  return (card === 'fire' && enemy === 'spirit') || (card === 'spirit' && enemy === 'stone') || (card === 'stone' && enemy === 'fire') ? 1.5 : 0.75;
}

export function cardTarget(card: Card): CardTarget {
  const harmful = card.effects.some(effect => effect.target === 'opponent' && (effect.operation === 'damage' || effect.operation === 'status'));
  const helpful = card.effects.some(effect => effect.target === 'actor' && effect.operation !== 'damage');
  if (harmful && !helpful) return 'enemy';
  if (helpful && !harmful) return 'player';
  return 'either';
}

export function resolvePlayTarget(s: State, card: Card, requested?: string): string {
  const mode = cardTarget(card);
  if (requested === 'player') {
    if (mode === 'enemy') throw Error('error.targetSelf');
    return requested;
  }
  if (requested) {
    const enemy = s.enemies.find(unit => unit.id === requested && unit.health > 0);
    if (!enemy) throw Error('error.targetMissing');
    if (mode === 'player') throw Error('error.targetEnemy');
    return enemy.id;
  }
  if (mode === 'player') return 'player';
  const enemy = [...s.enemies].filter(unit => unit.health > 0).sort((a, b) => a.health - b.health || a.id.localeCompare(b.id))[0];
  if (!enemy) throw Error('error.targetMissing');
  return enemy.id;
}

export function enemyAttackPreview(s: State, enemyId?: string) {
  const enemy = enemyId ? s.enemies.find(unit => unit.id === enemyId) : s.enemies.find(unit => unit.health > 0);
  if (!enemy) return { damage: 0, critical: false, empowered: false };
  const empowered = enemy.mechanics.belowHalfBonus > 0 && enemy.health <= enemy.maxHealth / 2;
  const baseDamage = enemy.damage + (empowered ? enemy.mechanics.belowHalfBonus : 0);
  const attackNumber = enemy.attacksMade + 1;
  const critical = enemy.mechanics.criticalEvery > 0 && attackNumber % enemy.mechanics.criticalEvery === 0;
  return { damage: critical ? baseDamage * enemy.mechanics.criticalMultiplier : baseDamage, critical, empowered };
}

export function validate(c: Content) {
  const ids = new Set(c.cards.map(x => x.id));
  const statuses = new Set(c.statuses.map(x => x.id));
  const positive = [c.rules.energy, c.rules.draw, c.rules.handLimit, c.rules.playerHealth, c.rules.enemyHealth];
  if (positive.some(x => !Number.isSafeInteger(x) || x <= 0) || !Number.isSafeInteger(c.rules.enemyDamage) || c.rules.enemyDamage < 0 || c.rules.handLimit < c.rules.draw || ids.size !== c.cards.length || statuses.size !== c.statuses.length || !c.startingDeck.length || c.startingDeck.some(x => !ids.has(x))) throw Error('Invalid content');
  for (const card of c.cards) if (!Number.isSafeInteger(card.cost) || card.cost < 0 || !c.translations.en[card.nameKey] || !c.translations['zh-Hans'][card.nameKey]) throw Error('Invalid card');
  for (const effect of [...c.cards.flatMap(x => x.effects), ...c.statuses.map(x => x.effect)]) {
    if (!Number.isSafeInteger(effect.amount) || effect.amount < 0 || (effect.operation === 'status' && !statuses.has(effect.status!))) throw Error('Invalid effect');
  }
}

/** Pure reducer: failed commands leave the previous snapshot untouched. */
export function act(previous: State, action: Action, c = content): State {
  if (previous.phase !== 'playerTurn') throw Error('error.finished');
  let targetId: string | undefined;
  if (action.type === 'play') {
    const instance = previous.hand.find(x => x.id === action.id);
    if (!instance) throw Error('error.card');
    const card = c.cards.find(x => x.id === instance.definitionID)!;
    if (card.cost > previous.energy) throw Error('error.energy');
    if (previous.actionsRemaining <= 0) throw Error('error.actions');
    targetId = resolvePlayTarget(previous, card, action.targetId);
  }
  const s: State = JSON.parse(JSON.stringify(previous));
  const engine = new Engine(s, c);
  if (action.type === 'play') engine.play(action.id, targetId!); else engine.endTurn();
  return s;
}

export function createBattle(seed: number, c = content, setup: BattleSetup = {}): State {
  validate(c);
  const unit = (health: number): Unit => ({ health, maxHealth: health, shield: 0, statuses: {} });
  const playerMaxHealth = setup.playerMaxHealth ?? c.rules.playerHealth;
  const player = unit(playerMaxHealth);
  player.health = Math.max(1, Math.min(playerMaxHealth, setup.playerHealth ?? playerMaxHealth));
  const enemySetups = setup.enemies?.length ? setup.enemies : [{ health: setup.enemyHealth ?? c.rules.enemyHealth, damage: setup.enemyDamage ?? c.rules.enemyDamage, mechanics: setup.mechanics }];
  const enemies: EnemyUnit[] = enemySetups.map((entry, index) => ({
    ...unit(entry.health),
    id: entry.id ?? `enemy-${index + 1}`,
    nameKey: entry.nameKey ?? 'enemy.name',
    artKey: entry.artKey ?? 'sentinel',
    tint: entry.tint ?? '#83E4C1',
    element: entry.element,
    damage: entry.damage,
    attacksMade: 0,
    hitsTaken: 0,
    revived: false,
    mechanics: mechanics(entry.mechanics),
  }));
  if (new Set(enemies.map(enemy => enemy.id)).size !== enemies.length) throw Error('Invalid enemies');
  const actionsPerTurn = setup.actionsPerTurn ?? defaultActionsPerTurn;
  const deck = setup.deck?.length ? setup.deck : c.startingDeck;
  if (deck.some(id => !c.cards.some(card => card.id === id))) throw Error('Invalid deck');
  const s: State = { player, enemies, drawPile: deck.map((definitionID, id) => ({ id, definitionID })), hand: [], discardPile: [], exhaustPile: [], upgrades: { ...(setup.upgrades ?? {}) }, equipmentIds: [...(setup.equipmentIds ?? [])], cardRunes: { ...(setup.cardRunes ?? {}) }, equipmentCounters: { mistHits: 0, soulHeals: 0, phoenixUsed: false }, swiftUsed: false, moonStaffUsed: false, firstAttackUsed: false, turnElements: {}, reviveChance: Math.max(0, Math.min(1, setup.reviveChance ?? 0)), revivesRemaining: setup.reviveChance ? 1 : 0, energy: 0, actionsPerTurn, actionsRemaining: 0, turn: 0, phase: 'playerTurn', rng: seed >>> 0 };
  const engine = new Engine(s, c);
  engine.shuffle(s.drawPile);
  engine.beginTurn();
  return s;
}

class Engine {
  private depth = 0;
  constructor(private s: State, private c: Content) {}
  private enemy(id: string) { return this.s.enemies.find(enemy => enemy.id === id)!; }
  private unit(id: string): Unit { return id === 'player' ? this.s.player : this.enemy(id); }
  private livingEnemy() { return [...this.s.enemies].filter(enemy => enemy.health > 0).sort((a, b) => a.health - b.health || a.id.localeCompare(b.id))[0]; }
  private random() { let t = this.s.rng = (this.s.rng + 0x6D2B79F5) >>> 0; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
  shuffle(cards: Instance[]) {
    for (let i = cards.length - 1; i > 0; i--) {
      let t = this.s.rng = (this.s.rng + 0x6D2B79F5) >>> 0;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      const j = Math.floor(((t ^ (t >>> 14)) >>> 0) / 4294967296 * (i + 1));
      [cards[i], cards[j]] = [cards[j], cards[i]];
    }
  }
  beginTurn() {
    this.s.turn++;
    this.s.energy = this.c.rules.energy;
    this.s.actionsRemaining = this.s.actionsPerTurn;
    this.s.swiftUsed = false; this.s.moonStaffUsed = false; this.s.firstAttackUsed = false; this.s.turnElements = {};
    this.s.player.shield = 0;
    for (const enemy of this.s.enemies) if (enemy.health > 0) enemy.shield = enemy.mechanics.enemyShieldPerTurn;
    this.trigger('turnStart', 'player');
    if (this.s.phase === 'playerTurn') this.draw(Math.max(0, this.c.rules.draw - this.s.hand.length));
    if (this.s.phase === 'playerTurn' && this.s.hand.length === 0 && this.s.drawPile.length === 0) this.s.phase = 'lost';
  }
  draw(count: number) {
    for (let i = 0; i < count; i++) {
      if (this.s.phase !== 'playerTurn' || this.s.hand.length >= this.c.rules.handLimit) return;
      const card = this.s.drawPile.pop();
      if (!card) return;
      this.s.hand.push(card);
      this.trigger('drawn', 'player');
    }
  }
  play(id: number, targetId: string) {
    const index = this.s.hand.findIndex(x => x.id === id);
    const instance = this.s.hand[index];
    const card = this.c.cards.find(x => x.id === instance.definitionID)!;
    const rune = this.s.cardRunes[card.id];
    this.s.energy -= card.cost;
    this.s.actionsRemaining--;
    if (rune === 'swift' && !this.s.swiftUsed) { this.s.actionsRemaining++; this.s.swiftUsed = true; }
    if (card.kind === 'Tactic' && this.s.equipmentIds.includes('moonStaff') && !this.s.moonStaffUsed) { this.s.energy++; this.s.moonStaffUsed = true; }
    this.s.hand.splice(index, 1);
    if (rune === 'cycle' && !card.exhaust) this.s.drawPile.unshift(instance); else this.s[card.exhaust ? 'exhaustPile' : 'discardPile'].push(instance);
    if (card.special === 'recycleDiscard') {
      const currentIndex = this.s.discardPile.findIndex(item => item.id === instance.id);
      const available = this.s.discardPile.filter((_, pileIndex) => pileIndex !== currentIndex).splice(-2);
      this.s.discardPile = this.s.discardPile.filter(item => !available.some(recycled => recycled.id === item.id));
      this.s.drawPile.unshift(...available);
      this.shuffle(this.s.drawPile);
    }
    if (card.special === 'recoverExhaust') {
      const recovered = this.s.exhaustPile.pop();
      if (recovered && recovered.id !== instance.id && this.s.hand.length < this.c.rules.handLimit) this.s.hand.push(recovered);
      else if (recovered) this.s.exhaustPile.push(recovered);
    }
    const attacksEnemy = targetId !== 'player' && card.effects.some(effect => effect.operation === 'damage' && effect.target === 'opponent');
    let bonus = 0;
    if (attacksEnemy) {
      for (const status of this.c.statuses) {
        if (status.nextAttackBonus && this.s.player.statuses[status.id]) {
          bonus += status.nextAttackBonus * this.s.player.statuses[status.id];
          delete this.s.player.statuses[status.id];
        }
      }
    }
    if (attacksEnemy && this.s.equipmentIds.includes('emberBlade') && !this.s.firstAttackUsed) bonus += 3;
    if (attacksEnemy) this.s.firstAttackUsed = true;
    const resonance = rune === 'resonance' && card.element ? (this.s.turnElements[card.element] ?? 0) : 0;
    const upgrade = Math.max(0, this.s.upgrades[card.id] ?? 0);
    let damageDealt = 0;
    for (const effect of card.effects) {
      if (this.s.phase !== 'playerTurn') break;
      if (effect.operation === 'damage' && effect.target === 'opponent') {
        const targets = card.special === 'cleave' ? this.s.enemies.filter(enemy => enemy.health > 0).map(enemy => enemy.id) : [targetId];
        for (const enemyId of targets) {
          const enemy = this.enemy(enemyId);
          const execute = rune === 'execute' && enemy.health <= enemy.maxHealth * .25 ? 1.5 : 1;
          const raw = (effect.amount + upgrade + bonus + resonance) * (card.special === 'critical' ? 2 : 1) * execute;
          const amount = Math.max(1, Math.round(raw * elementalMultiplier(card.element, enemy.element)));
          damageDealt += this.damage(amount, enemyId, card.special === 'pierce' || this.s.equipmentIds.includes('stoneSpear'));
          if (rune === 'chain' && targets.length === 1) {
            const other = this.s.enemies.find(unit => unit.health > 0 && unit.id !== enemyId);
            if (other) damageDealt += this.damage(Math.max(1, Math.round(amount * .4)), other.id);
          }
        }
        bonus = 0;
      } else this.apply({ ...effect, amount: effect.amount + (effect.operation === 'shield' || effect.operation === 'heal' || effect.operation === 'status' ? upgrade : 0) }, 'player', 1, targetId);
    }
    if (rune === 'echo' && this.s.phase === 'playerTurn') for (const effect of card.effects) {
      const echoed = { ...effect, amount: Math.max(1, Math.round((effect.amount + (effect.operation === 'shield' || effect.operation === 'heal' || effect.operation === 'status' ? upgrade : 0)) * .5)) };
      if (echoed.operation === 'damage' && echoed.target === 'opponent') damageDealt += this.damage(echoed.amount, targetId, card.special === 'pierce' || this.s.equipmentIds.includes('stoneSpear')); else this.apply(echoed, 'player', 1, targetId);
    }
    if (rune === 'siphon' && damageDealt > 0) this.s.player.shield += Math.max(1, Math.floor(damageDealt * .25));
    if (rune === 'burning' && attacksEnemy && this.enemy(targetId).health > 0) this.enemy(targetId).statuses.burn = (this.enemy(targetId).statuses.burn ?? 0) + 2;
    if (rune === 'guardian') this.s.player.shield += 4;
    if (rune === 'cleanse') delete this.s.player.statuses.burn;
    if (card.element) this.s.turnElements[card.element] = (this.s.turnElements[card.element] ?? 0) + 1;
    if (card.special === 'stun' && targetId !== 'player') this.enemy(targetId).statuses.stun = (this.enemy(targetId).statuses.stun ?? 0) + 1;
    if (this.s.phase === 'playerTurn' && attacksEnemy) {
      const thorns = this.enemy(targetId).mechanics.thornsDamage;
      if (thorns > 0) this.damage(thorns, 'player');
    }
    if (this.s.phase === 'playerTurn') this.trigger('cardPlayed', 'player');
  }
  endTurn() {
    this.trigger('turnEnd', 'player');
    if (this.s.phase !== 'playerTurn') return;
    for (const enemy of this.s.enemies) {
      if (enemy.health <= 0) continue;
      enemy.shield = 0;
      this.trigger('turnStart', enemy.id);
      enemy.health = Math.min(enemy.maxHealth, enemy.health + enemy.mechanics.regenerationPerTurn);
      if (enemy.health <= 0 || this.s.phase !== 'playerTurn') continue;
      if ((enemy.statuses.stun ?? 0) > 0) { enemy.statuses.stun--; this.trigger('turnEnd', enemy.id); continue; }
      this.s.equipmentCounters.mistHits++;
      const negated = this.s.equipmentIds.includes('mistCloak') && this.s.equipmentCounters.mistHits % 3 === 0;
      const taken = this.damage(negated ? 0 : enemyAttackPreview(this.s, enemy.id).damage, 'player');
      enemy.attacksMade++;
      if (taken > 0 && this.s.equipmentIds.includes('thornArmor')) this.damage(2, enemy.id);
      if (this.s.phase !== 'playerTurn') return;
      this.trigger('turnEnd', enemy.id);
      enemy.damage += enemy.mechanics.enragePerTurn;
      if (this.s.phase !== 'playerTurn') return;
    }
    if (this.s.phase === 'playerTurn') this.beginTurn();
  }
  trigger(event: Event, actorId: string) {
    if (this.depth >= 32) return;
    const unit = this.unit(actorId);
    if (unit.health <= 0 && event !== 'death') return;
    this.depth++;
    try {
      const snapshot = { ...unit.statuses };
      for (const status of this.c.statuses) {
        const stacks = snapshot[status.id] ?? 0;
        if (status.trigger !== event || stacks <= 0) continue;
        const opponentId = actorId === 'player' ? this.livingEnemy()?.id : 'player';
        this.apply(status.effect, actorId, status.scaleWithStacks ? stacks : 1, opponentId);
        unit.statuses[status.id] = Math.max(0, (unit.statuses[status.id] ?? 0) - status.decay);
        if (this.s.phase !== 'playerTurn') break;
      }
    } finally { this.depth--; }
  }
  apply(effect: Effect, actorId: string, multiplier = 1, opponentId?: string) {
    const targetId = effect.target === 'actor' ? actorId : opponentId;
    if (!targetId) return;
    const unit = this.unit(targetId);
    const amount = effect.amount * multiplier;
    switch (effect.operation) {
      case 'damage': this.damage(amount, targetId); break;
      case 'shield': unit.shield += amount; break;
      case 'heal': unit.health = Math.min(unit.maxHealth, unit.health + amount); break;
      case 'draw': if (targetId === 'player') this.draw(amount); break;
      case 'energy': if (targetId === 'player') this.s.energy += amount; break;
      case 'status': unit.statuses[effect.status!] = (unit.statuses[effect.status!] ?? 0) + amount; break;
    }
  }
  damage(amount: number, targetId: string, ignoreShield = false) {
    const unit = this.unit(targetId);
    if (unit.health <= 0) return 0;
    if (targetId !== 'player') {
      const enemy = this.enemy(targetId); enemy.hitsTaken++;
      if (enemy.mechanics.dodgeEvery > 0 && enemy.hitsTaken % enemy.mechanics.dodgeEvery === 0) return 0;
    }
    const absorbed = ignoreShield ? 0 : Math.min(unit.shield, amount);
    unit.shield -= absorbed;
    const dealt = Math.min(unit.health, Math.max(0, amount - absorbed));
    unit.health = Math.max(0, unit.health - dealt);
    if (unit.health === 0) {
      if (targetId !== 'player') {
        const enemy = this.enemy(targetId);
        if (!enemy.revived && this.s.revivesRemaining > 0 && this.random() < this.s.reviveChance) { enemy.health = Math.max(1, Math.ceil(enemy.maxHealth * .35)); enemy.shield = 0; enemy.revived = true; this.s.revivesRemaining--; return dealt; }
        if (this.s.equipmentIds.includes('soulPendant') && this.s.equipmentCounters.soulHeals < 3) { this.s.player.health = Math.min(this.s.player.maxHealth, this.s.player.health + 2); this.s.equipmentCounters.soulHeals++; }
        if (this.s.equipmentIds.includes('stormBow')) this.draw(1);
      } else if (this.s.equipmentIds.includes('phoenixMail') && !this.s.equipmentCounters.phoenixUsed) {
        unit.health = Math.min(unit.maxHealth, 15); this.s.equipmentCounters.phoenixUsed = true; return dealt;
      }
      if (targetId === 'player') this.s.phase = 'lost'; else if (this.s.enemies.every(enemy => enemy.health === 0)) this.s.phase = 'won';
      this.trigger('death', targetId);
    } else if (amount > absorbed) this.trigger('damaged', targetId);
    return dealt;
  }
}

export function translator(language: string) {
  return (key: string, values: Record<string, string | number> = {}) => {
    let value = content.translations[language]?.[key] ?? content.translations.en[key] ?? key;
    for (const [token, replacement] of Object.entries(values)) value = value.replaceAll(`{${token}}`, String(replacement));
    return value;
  };
}
export function statusDescription(id: string, stacks: number, language: string) {
  const status = content.statuses.find(x => x.id === id)!;
  return translator(language)(`status.${id}.detail`, { amount: status.effect.amount * (status.scaleWithStacks ? stacks : 1), decay: status.decay, bonus: (status.nextAttackBonus ?? 0) * stacks });
}
export function description(card: Card, language: string) {
  const t = translator(language);
  const effects = card.effects.map(effect => {
    const summary = t(`effect.${effect.operation}`, { amount: effect.amount, target: t(effect.target === 'actor' ? 'target.self' : 'target.enemy'), status: t(`status.${effect.status}`) });
    return summary + (effect.operation === 'status' ? '\n' + statusDescription(effect.status!, effect.amount, language) : '');
  });
  if (card.exhaust) effects.push(t('card.exhaust'));
  if (card.special) effects.push(t(`card.special.${card.special}`));
  return effects.join('\n');
}
