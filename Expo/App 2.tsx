import React, { useEffect, useRef, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { getLocales } from 'expo-localization';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Action, Card, Pile, Unit, act, content, createBattle, description, statusDescription, translator } from './src/combat';

const colors = { ink: '#0B171C', panel: '#172B31', ember: '#FFA366', jade: '#94DBC2', text: '#F1F4F3', muted: '#B6C4C7' };
const seed = () => Math.floor(Math.random() * 4294967296);
const piles: Pile[] = ['drawPile', 'discardPile', 'exhaustPile'];
const pileKey = (p: Pile) => `pile.${p.replace('Pile', '')}`;

export default function App() { return <SafeAreaProvider><Battle /></SafeAreaProvider>; }
function Battle() {
  const [state, setState] = useState(() => createBattle(seed()));
  const [language, setLanguage] = useState(getLocales()[0]?.languageCode === 'zh' ? 'zh-Hans' : 'en');
  const [pile, setPile] = useState<Pile | null>(null);
  const [confirmRestart, setConfirmRestart] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const languageTouched = useRef(false);
  const scroll = useRef<ScrollView>(null);
  const { width, fontScale } = useWindowDimensions();
  const t = translator(language);
  const active = state.phase === 'playerTurn';
  const twoColumns = width >= 360 && fontScale < 1.4;
  useEffect(() => {
    let mounted = true;
    AsyncStorage.getItem('spiritbound.language').then(value => {
      if (mounted && !languageTouched.current && (value === 'en' || value === 'zh-Hans')) setLanguage(value);
    }).catch(() => {});
    return () => { mounted = false; };
  }, []);
  function toggleLanguage() {
    languageTouched.current = true;
    const next = language === 'en' ? 'zh-Hans' : 'en';
    setLanguage(next);
    void AsyncStorage.setItem('spiritbound.language', next).catch(() => {});
  }
  function dispatch(action: Action) {
    // Event handlers execute serially; use the current snapshot for each action.
    try { setState(act(state, action)); } catch (e) { setError(e instanceof Error ? e.message : 'error.content'); }
  }
  function restart() {
    setState(createBattle(seed())); setConfirmRestart(false); setPile(null); setError(null);
    scroll.current?.scrollTo({ y: 0, animated: false });
  }
  function button(label: string, onPress: () => void, primary = false) {
    return <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.button, primary && styles.primary, pressed && styles.pressed]}><Text style={[styles.buttonText, primary && styles.primaryText]}>{label}</Text></Pressable>;
  }
  function unit(fighter: Unit, name: string, emblem: string, tint: string) {
    return <View style={styles.unit}>
      <View style={styles.row}>
        <View accessible={false} style={[styles.emblem, { borderColor: tint }]}><Text style={{ color: tint, fontSize: 27 }}>{emblem}</Text></View>
        <View style={{ flex: 1 }}><Text style={styles.unitName}>{t(name)}</Text><Text style={styles.body}>{t('battle.health', { current: fighter.health, max: fighter.maxHealth })}</Text></View>
      </View>
      <View accessible={false} style={styles.healthTrack}><View style={{ height: '100%', width: `${100 * fighter.health / fighter.maxHealth}%`, backgroundColor: tint, borderRadius: 5 }} /></View>
      <Text style={styles.jade}>{t('battle.shield', { amount: fighter.shield })}</Text>
      {Object.entries(fighter.statuses).filter(([, n]) => n > 0).map(([id, n]) => <View key={id}><Text style={styles.status}>{t(`status.${id}`)} · {n}</Text><Text style={styles.note}>{statusDescription(id, n, language)}</Text></View>)}
    </View>;
  }
  function face(card: Card) {
    return <><View style={styles.spread}><Text style={styles.rarity}>{t(`rarity.${card.rarity}`)}</Text><Text style={styles.cost}>ϟ {card.cost}</Text></View><Text style={styles.cardName}>{t(card.nameKey)}</Text><Text style={styles.cardDescription}>{description(card, language)}</Text></>;
  }
  const inspected = pile ? [...state[pile]].sort((a, b) => a.definitionID.localeCompare(b.definitionID) || a.id - b.id) : [];
  return <SafeAreaView style={styles.screen}>
    <StatusBar style="light" />
    <ScrollView ref={scroll} contentContainerStyle={styles.content}>
      <View style={styles.spread}><View style={{ flex: 1 }}><Text style={styles.brand}>SPIRITBOUND</Text><Text style={styles.note}>{t('battle.subtitle')}</Text></View>
        <Pressable accessibilityRole="button" accessibilityLabel={t('action.language')} onPress={toggleLanguage} style={styles.smallButton}><Text style={styles.jade}>{language === 'en' ? '中文' : 'EN'}</Text></Pressable>
        <Pressable accessibilityRole="button" accessibilityLabel={t('battle.restart')} onPress={() => active ? setConfirmRestart(true) : restart()} style={styles.smallButton}><Text style={styles.jade}>↻</Text></Pressable>
      </View>
      <View style={styles.spread}><Text style={[styles.eyebrow, { flex: 1 }]}>{t('battle.chapter')}</Text><Text style={styles.note}>{t('battle.turn', { turn: state.turn })}</Text></View>
      {unit(state.enemy, 'enemy.name', '◇', colors.jade)}
      {active && <Text style={styles.intent}>↘ {t('enemy.intent', { damage: content.rules.enemyDamage })}</Text>}
      {unit(state.player, 'spirit.fox', '火', colors.ember)}
      {active ? <>
        <View style={styles.spread}><Text style={styles.heading}>{t('battle.hand')}</Text><Text style={styles.cost}>{t('battle.energy', { amount: state.energy })}</Text></View>
        <Text style={styles.note}>{t('battle.tap')}</Text>
        <View style={styles.grid}>{state.hand.map(instance => {
          const card = content.cards.find(x => x.id === instance.definitionID)!;
          const disabled = card.cost > state.energy;
          return <Pressable key={instance.id} accessibilityRole="button" accessibilityState={{ disabled }} accessibilityLabel={`${t(card.nameKey)}. ${t('card.cost', { amount: card.cost })}. ${description(card, language)}`} disabled={disabled} onPress={() => dispatch({ type: 'play', id: instance.id })} style={({ pressed }) => [styles.card, { width: twoColumns ? '48%' : '100%' }, disabled && styles.disabled, pressed && styles.pressed]}>{face(card)}</Pressable>;
        })}</View>
      </> : <View style={styles.unit}><Text accessibilityLiveRegion="polite" style={styles.heading}>{t(state.phase === 'won' ? 'battle.won' : 'battle.lost')}</Text><Text style={styles.body}>{t('battle.outcomeDetail')}</Text>{button(t('battle.restart'), restart, true)}</View>}
      <View style={styles.row}>{piles.map(p => <Pressable key={p} accessibilityRole="button" accessibilityLabel={`${t(pileKey(p))}, ${state[p].length}`} onPress={() => setPile(p)} style={styles.pile}><Text style={styles.heading}>{state[p].length}</Text><Text style={styles.note}>{t(pileKey(p))}</Text></Pressable>)}</View>
      <Text style={styles.note}>{t('battle.rules', { draw: content.rules.draw, energy: content.rules.energy })}</Text>
    </ScrollView>
    {active && <View style={styles.footer}>{button(t('battle.endTurn'), () => dispatch({ type: 'endTurn' }), true)}</View>}
    <Modal visible={pile !== null} animationType="slide" onRequestClose={() => setPile(null)}>
      <SafeAreaView style={styles.screen}><View style={styles.modalHeader}><Text style={styles.heading}>{pile ? t(pileKey(pile)) : ''}</Text>{button(t('action.done'), () => setPile(null))}</View><ScrollView contentContainerStyle={styles.content}><Text style={styles.note}>{t('pile.orderNote')}</Text>{!inspected.length && <Text style={styles.body}>{t('pile.empty')}</Text>}{inspected.map(instance => <View key={instance.id} style={styles.card}>{face(content.cards.find(x => x.id === instance.definitionID)!)}</View>)}</ScrollView></SafeAreaView>
    </Modal>
    <Modal visible={confirmRestart || error !== null} transparent animationType="fade" onRequestClose={() => { setConfirmRestart(false); setError(null); }}>
      <View style={styles.scrim}><View accessibilityViewIsModal style={styles.dialog}><Text style={styles.heading}>{t(error ? 'error.title' : 'restart.title')}</Text><Text style={styles.body}>{t(error ?? 'restart.message')}</Text>{error ? button(t('action.ok'), () => setError(null), true) : <>{button(t('battle.restart'), restart, true)}{button(t('action.cancel'), () => setConfirmRestart(false))}</>}</View></View>
    </Modal>
  </SafeAreaView>;
}
const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.ink },
  content: { padding: 20, gap: 16, width: '100%', maxWidth: 620, alignSelf: 'center', paddingBottom: 28 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  spread: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  brand: { color: colors.text, fontSize: 17, fontWeight: '800', letterSpacing: 2 },
  note: { color: colors.muted, fontSize: 12, lineHeight: 18 },
  body: { color: colors.text, fontSize: 15, lineHeight: 22 },
  jade: { color: colors.jade, fontSize: 14 },
  eyebrow: { color: colors.jade, fontSize: 11, letterSpacing: 1.5 },
  heading: { color: colors.text, fontSize: 20, fontWeight: '700' },
  unit: { backgroundColor: colors.panel, borderRadius: 20, padding: 18, gap: 12 },
  unitName: { color: colors.text, fontSize: 18, fontWeight: '700', marginBottom: 5 },
  emblem: { width: 48, height: 52, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 16 },
  healthTrack: { height: 6, borderRadius: 5, backgroundColor: '#35474B', overflow: 'hidden' },
  status: { color: colors.ember, fontSize: 14, fontWeight: '700' },
  intent: { color: colors.ember, fontSize: 14, fontWeight: '600' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, justifyContent: 'space-between' },
  card: { backgroundColor: colors.panel, borderWidth: 1, borderColor: '#8C674C', borderRadius: 15, padding: 14, minHeight: 170, gap: 12 },
  rarity: { color: colors.jade, fontSize: 10 },
  cost: { color: colors.ember, fontWeight: '700', fontSize: 16 },
  cardName: { color: colors.text, fontSize: 16, fontWeight: '700' },
  cardDescription: { color: colors.text, fontSize: 13, lineHeight: 19 },
  disabled: { opacity: 0.45 }, pressed: { opacity: 0.7 },
  button: { backgroundColor: colors.panel, minHeight: 48, padding: 13, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  primary: { backgroundColor: colors.ember },
  buttonText: { color: colors.jade, fontSize: 16, fontWeight: '700' }, primaryText: { color: colors.ink },
  smallButton: { minWidth: 44, minHeight: 44, padding: 10, backgroundColor: colors.panel, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  pile: { flex: 1, minHeight: 65, backgroundColor: colors.panel, borderRadius: 12, padding: 12, alignItems: 'center', gap: 5 },
  footer: { paddingHorizontal: 20, paddingVertical: 10, maxWidth: 620, width: '100%', alignSelf: 'center' },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 20 },
  scrim: { flex: 1, backgroundColor: '#000000AA', justifyContent: 'center', padding: 24 },
  dialog: { backgroundColor: colors.panel, padding: 24, borderRadius: 20, gap: 18, maxWidth: 460, width: '100%', alignSelf: 'center' },
});
