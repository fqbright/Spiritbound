# Art Brief — What's Already Painted vs What's Still Placeholder/Procedural

Compiled 2026-09-15 by scanning the actual asset folders and rendering code, not from
memory — every claim below is grounded in a specific file or function. Use this to brief
an art-generation agent without redoing work that's already done, or missing a gap that's
easy to overlook because the game *looks* finished in that spot (procedural vector shapes
read as "fine" at a glance, but aren't painted art).

**Overall style already established**: painted/digital-illustration fantasy, East-Asian
xianxia-adjacent theming (灵狐, 月纹法杖, 翠玉战甲, 荆棘荒野...), warm-to-moody palette
depending on biome. `icon.png` (the app icon — a nine-tailed fox spirit mid-cast, dark
forest + purple spirit-fire) is the clearest single reference for "this is the target
quality bar." Any new asset should match this painted style, not a flat/vector icon style.

---

## Already professionally painted — do NOT regenerate these

- **50 chapter map backgrounds** — `assets/chapters/chapter_0.png` … `chapter_49.png`,
  390×520 each, one unique painted scene per chapter matching that chapter's name/lore in
  `content.gd`.
- **Card illustrations** — every one of the ~40 cards in `core.json` has dedicated art
  (verified by an automated test: "every single card in core.json has dedicated non-null
  art"). Plus 4 rarity-specific frame textures (`card_frame_starter/common/uncommon/rare.png`).
- **Equipment icons** — all 12 pieces (`assets/icons/equip_emberBlade.png`, etc.), one
  painted icon per item.
- **Rune icons** — all 10 runes (`assets/icons/rune_swift.png`, etc.).
- **Character/monster atlas** — `assets/characters/character-atlas-v3.png`, a 3×3 grid
  covering 3 hero classes + the shared enemy pool.
- **App icon** — `icon.png`, already at a high finished bar.
- **Map pin overlay texture** — `assets/map_pin_rune.png` (a rune-ring overlay stamped on
  every stage pin badge).

## Gaps — procedural/placeholder standing in for real art

1. **11 Relic icons — currently a bare Unicode glyph, no painted art at all.**
   Equipment and Runes both got the "real icon" upgrade (`_equip_icon_badge` /
   `_rune_icon_badge` load `equip_*.png` / `rune_*.png`); Relics never did — they still
   render as a single Unicode character (⚔ ⬢ ◇ ☾ ✣ ≋ ➹ ≈ ◆ ϟ ♨ ◉) wherever they appear
   (reward toast, Camp's Relics tab). This is the single most visible "unfinished-looking"
   spot once you know to look for it. **Ask for**: 11 painted relic icons, same square
   format/style as the equip_*/rune_* set, one per relic in `content.gd`'s `RELICS` array:
   `foxCharm`, `starShard`, `ancientSeed`, `windChime`, `bloodJade`, `thunderSeal`,
   `mirrorScale`, `emberCore`, plus the 3 boss-exclusive relics `cursedTome`, `titanBell`,
   `chaosPrism` — 11 total). Each already has a `color` hex and an `icon_mark` motif name
   (flame/sparkle/leaf/wave/drop/bolt/rings/cross_blade/eye/crescent/spiral/shield_mark) to
   use as the visual theme.

2. **4th hero portrait missing — "Miasma Witch" (D3, 灵界拓展手记 item).**
   Fully implemented mechanically (deck, relic, mastery perks) but has no unique art — the
   game shows a dimmed/desaturated borrowed portrait and an "Art Coming Soon" label
   (`art_pending: true` in `content.gd`, `ui.hero_art_pending`). The 3×3 character atlas is
   completely full (3 heroes + enemy pool use all 9 cells), so this needs a **standalone
   portrait file**, not another atlas cell — matches the painted style of the other 3 hero
   portraits in the atlas (fox/stone/shadow themed; this one should read as a poison/miasma
   witch). Same aspect ratio as one atlas cell.

3. **5 battle backgrounds are stock-feeling JPGs, not the game's painted style.**
   `assets/backgrounds/battlefield-v1.jpg`, `lantern-marsh-v1.jpg`, `rune-ravine-v1.jpg`,
   `ember-cliff-v1.jpg`, `mountain-forge-v1.jpg` — JPG format (vs. the painted PNGs
   everywhere else), generic names, and noticeably more "stock photo / generic digital art"
   than the bespoke chapter backgrounds. These are what's actually behind the player during
   every single battle, so the quality gap is highly visible. There are 5 sub-stage battle
   music tracks with clear identities (Trailhead → Crossing → Shrine → Stronghold →
   Crown/Boss); repainting these 5 to match those identities *and* the map's painted style
   would tie combat visually to the map for the first time. `spirit-world-map-v1.jpg` (used
   behind the account-setup/title screen) has the same stock-photo issue.

4. **Map pins are colored badges + a generic rune overlay, not illustrated pins.**
   `_add_stage_pin()` draws a flat colored rounded-rect badge (color varies by node kind:
   normal/elite/boss/greatboss/event/merchant/rest) with a procedurally-drawn `GameIcon`
   shape on top and the one shared `map_pin_rune.png` overlay. This works but reads as UI,
   not as part of the painted world. **Optional upgrade**: 7 illustrated pin/waypost
   designs (one per node kind) in the map's painted style.

5. **All navigation/UI icons are code-drawn vector shapes, not painted icons.**
   `GameIcon` (`scripts/game_icon.gd`) procedurally draws every nav-bar icon (quest scroll,
   profile crest, deck/shop/equip/next-stage icons), map terrain decoration (pine/boulder/
   hill), and non-equipment/rune/relic badges (sword/shield/pendant/staff/spear/bow generic
   shapes) using raw polygon math — no bitmap art. Likewise `IntentIcon`
   (`scripts/game_intent_icon.gd`) draws enemy intent glyphs (attack/defend/empower/curse/
   critical) the same way. These look clean/legible today; painting real icon art for them
   is a "make it feel premium" upgrade, not a functional gap — lowest priority of this list
   unless the goal is a full icon-set overhaul.

6. **Achievements have no icon at all — text only.**
   The 22-achievement list in `content.gd` has no icon field and nothing in `game.gd`
   renders one; the Achievements tab is name + description + progress bar, nothing visual.
   Would need a small badge/medal icon set (could be as few as 3-4 tiers of a generic badge
   shape recolored, rather than 22 bespoke icons, if scope is a concern).

7. **Four chapter map backgrounds have a road that's ambiguous or low-contrast — candidates for a repaint/touch-up, not a full redo.**
   Found this session while pixel-tracing the actual road in every chapter's art to fix pin
   placement (see `Docs/GROWTH_ROADMAP.md`'s "Map path/pins aligned..." entry): chapters 7
   and 18 are abstract flowing-dune compositions with no single distinguishable path (any
   waypoint choice is arbitrary), and chapters 8 and 26 paint the road as the *darkest*
   feature against bright glowing lava, which is hard to read as "the path" at a glance.
   Not urgent, but if these ever get a revision pass, ask for a clearly higher-contrast,
   single continuous trail like the other 46 chapters already have.

---

## Suggested priority if the art agent's time is limited

1. Relic icons (11) — cheap, high visibility, closes an obvious inconsistency with
   equipment/runes that already got this treatment.
2. Battle backgrounds (5-6) — highest visibility (seen in every fight), currently the
   biggest stylistic mismatch with the rest of the game.
3. Miasma Witch portrait (1) — closes a very visible "Art Coming Soon" label a player will
   actually see if they pick that hero.
4. Everything else (map pins, nav icons, intent icons, achievement badges, the 4
   low-contrast chapter roads) is polish, roughly in that order.
