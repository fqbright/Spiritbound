# UI audit — what the screens actually measure

`Godot/tools/ui_audit.gd` renders the same nine screens the visual snapshotter does, then measures
them instead of eyeballing them: hit-target sizes, text cut off by its own container, and text
contrast against the pixels really behind it. It asserts nothing. It prints numbers so the numbers
can be argued with.

```bash
godot --path Godot/ --script res://tools/ui_audit.gd     # needs a real renderer (contrast reads pixels)
```

Full per-screen detail lands in `Godot/tests/snapshots/ui_audit.json`.

**Why this exists alongside `ui_smoke.gd`.** Every trap in AGENTS.md is a bug that produced a wrong
screen with no error in the log, and `ui_smoke.gd` was written to catch those specific shapes. This
catches a different class: screens that render *exactly as coded* and are still wrong for a human
holding a phone. Nothing here would have failed a headless test — a 26-pixel-tall button and a
44-pixel-tall button are equally "present".

Thresholds are borrowed, not invented: 44x44 pt is Apple's HIG minimum for a hit target; 4.5:1 and
3.0:1 are WCAG 2.1 AA for normal and large text.

## Measured state (2026-09-20, before and after this session's fixes)

| Screen | hit targets <44pt | text cut off | low contrast |
| --- | ---: | ---: | ---: |
| 01 map | 6 | 0 | 5 → **5** |
| 02 battle | 4 | **1 → 0** | 6 → **4** |
| 03 rewards | 6 | 0 | 1 |
| 04 shop | 18 | 0 | 0 → **1** |
| 05 deck | 28 | 0 | 6 → **1** |
| 06 camp | 11 | 0 | 1 → **0** |
| 07 treasury | 12 | 0 | 0 |
| 08 codex | 7 | 0 | 0 |
| 09 challenges | 24 | 0 | 0 |
| **total** | **116 (107 enabled)** | **1 → 0** | **19 → 10** |

## Fixed, with the number that justified each

1. **`_button` hardcoded near-white text on every fill.** Invisible-on-light the moment a caller
   passes a light accent, which several already did. The *active* filter chips on the deck screen
   (ember fill) measured **1.90:1**, the active element chip (jade) **1.62:1**, and the
   confirm-deck button ("确认牌组 25/25") **1.76:1** — all live, tappable controls with unreadable
   labels. Now `_ink_for(fill)` picks dark-or-light per fill, and `ui_smoke.gd` asserts it clears
   4.5:1 across every palette colour a button actually uses (worst case now 4.74:1).
   The dark candidate is *near-black*, not a mid-dark slate: on the epic-purple `#a663bc`
   (luminance 0.20) both `#16232a` and white fall short, at 3.9:1 and 3.8:1.
2. **The player's HP readout measured 2.19:1.** `_stat_bar` draws white text across the *whole*
   bar, so it has to stay readable against the light fill on the left and the dark track on the
   right simultaneously. A single ink chosen by luminance cannot do that — that is why this one
   needs an outline rather than the contrast-aware ink above. Now **4.11:1 avg** (and it dropped
   out of the worst ten entirely).
3. **Map pin captions sat on terrain, not on a panel.** "未解锁" measured **2.07–2.98:1** against
   the ground behind it. The existing 1px drop shadow only darkens below the glyph; switched to an
   outline, which darkens all of it.
4. **The leftmost card's cost badge was half clipped.** A five-card fan spans the full 366px hand
   area edge to edge, so the leftmost tile got `x = -10` and the clip rounded the badge's left half
   away. The tile is now clamped to keep the badge on screen; for four or fewer cards the fan is
   narrower and nothing changes. Asserted in `ui_smoke.gd`.
5. **The camp account hint was the least readable text on its own screen** (`#5e7278` at 8pt,
   measured 2.04:1) *and* spilled 9px below its panel. Raised to `MUTED` at 9pt.

## Two metric bugs I hit doing this, both worth knowing

Both produced confident wrong readings, which is the failure mode that matters here.

**Averaging the whole label rect into one "background" hides the fix.** The first version scored a
label against the mean of every non-glyph pixel in its rect. But for a small label the rect is
mostly its own fill, so the standard fix for text on a variable background — an outline — barely
moved the number: growing the HP readout's outline from 2px to 10px shifted that average only
**2.18 → 2.73**. An eye compares a glyph against what is *immediately* around it. Now each glyph
pixel is compared against the mean of nearby non-glyph pixels, and both the average local ratio and
the worst single glyph pixel are reported — the latter is what catches "readable except where it
crosses the one bright rock".

**Emoji are not text.** 4 of the 13 remaining "violations" were colour-emoji glyphs (🧪 🔒 ✥), which
are drawn by the system emoji font in their own colours — so matching them against `font_color`
keys on a colour that was never used and scores the result as if it were text. They are now
excluded. **A gate that cries wolf is a gate that gets switched off.** (Watch the range ordering:
CJK is *also* above `0x2E80`, so the emoji ranges must be tested first — getting that backwards is
how "🔒" got reported at 2.35:1.)

## What is still wrong, ranked

**Hit targets are the biggest remaining gap and were deliberately not changed this pass.** 107
enabled targets under 44pt, concentrated in two places: the deck screen's search/filter chip rows
(24 of them: the kind chips are 70x28, the element chips 50x26) and the challenges screen (22).
These are *not* all defects — a row of five mutually-exclusive filter chips physically cannot be
44pt tall each and still fit a 390pt-wide portrait screen with the search field above it. The
honest fixes are structural, not per-button: give the chip rows a taller container, or move
filtering behind a single "筛选" sheet that opens a full-height panel. That is a design decision
about how much of the screen filtering deserves, so it is left to a human rather than guessed at.

**10 contrast findings remain**, all small (worst `avg` 3.18:1, worst single pixel 1.79:1): the map
captions that already got an outline, and the small quantity numerals on accent discs ("1" on a
cost badge, 4.15–4.35:1 avg). Neither is invisible; both are below AA and would improve with less
transparent badge fills.

**Font sizes.** 168 of 781 visible text nodes are under 11pt (5 at 7pt, 32 at 8pt, 69 at 9pt, 62 at
10pt). The 7pt ones are the kind/element line on small hand cards — the card is only 116pt wide and
that line shares it with the cost badge. This is the same structural problem as the hit targets and
deserves the same kind of answer (fewer, larger labels), not a blanket font bump that would break
the layouts that were tuned around the current sizes.

## Why this is not a CI gate

`ui_audit.gd` found these problems, which is what it is for — but it should not gate them. It needs
a real renderer; its contrast numbers move with the GPU driver; and a threshold on average local
contrast would go red on a font-weight change nobody can see. So the *decisions* are gated instead,
in `ui_smoke.gd`'s `== ui readability ==` section, which asserts the five things above in headless
form — including that no currency amount is drawn with a substitute glyph instead of its designed
icon. Re-run `ui_audit.gd` by hand when you want the current numbers.
