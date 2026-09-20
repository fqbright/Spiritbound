# Asset compression: what was shipped, and what it cost

Status: **applied and shipped.** `Godot/tools/tex_policy.py` is the policy and the only thing that
edits the `.import` sidecars. The decision is reversible with one command (`--restore`).

Re-measure at any time:

```bash
python3 Godot/tools/tex_policy.py --pck Godot/build/ios/Spiritbound.pck   # plan + real pack bytes
python3 Godot/tools/tex_policy.py --restore && godot --headless --path Godot/ --import
python3 Godot/tools/tex_policy.py --samples Godot/tools/tex_probe_samples.txt --per-group 3
godot --headless --path Godot/ -s tools/tex_probe.gd                      # per-category PSNR
python3 Godot/tools/pck_audit.py Godot/build/ios/Spiritbound.pck          # where the pack bytes go
```

## The result

The pack was 99.3% imported texture and all 638 texture sources imported Lossless. Switching the
519 large-art sources to Lossy q=0.95 (`compress/mode=1`, Godot's own WebP encoder):

| | pack size |
|---|---|
| before | 136,094,432 bytes (129.8 MiB) |
| after | 63,887,520 bytes (60.9 MiB) |
| | **−72.2 MB, −53.1%** |

Both are real exports read with `pck_audit.py`, not extrapolations. The artifact boots from the pack
and reaches the game loop with zero errors.

## The number that should be quoted for quality

**On-screen, the whole lossless → q=0.95 switch moves at most 0.52% of the pixels on any of the nine
captured screens** (largest raw move: battle screen, 2247 px of ~329k), against existing per-screen
gates of 0.80–2.50%. That came out of the CI baseline refresh (`refresh-baselines.yml`), which
diffs a fresh capture against the baselines it is about to replace — i.e. the measurement is taken
on rendered frames, in the renderer CI uses, before the baselines are overwritten.

That is a considerably stronger statement than the PSNR table below, and it is measured rather than
inferred. Note the corollary: the old pre-compression baselines still pass against the new capture,
so CI would have gone green either way. The baselines were refreshed because a baseline should
describe the art that ships.

## Where the bytes went (before → after, by source directory)

| dir | before | after | policy |
|---|---|---|---|
| `assets/characters/monsters` | 34.1 MiB | 13.6 MiB | 375 lossy |
| `assets/chapters` | 23.9 MiB | 8.0 MiB | 50 lossy |
| `assets` (root frames/atlas) | 5.0 MiB | 5.0 MiB | 10 keep (lossless) |
| `assets/cards` | 16.6 MiB | 4.9 MiB | 48 lossy / 4 keep |
| `assets/characters` | 10.2 MiB | 3.3 MiB | 15 lossy |
| `assets/banners` | 9.4 MiB | 2.7 MiB | 8 lossy |
| `assets/backgrounds` | 7.5 MiB | 2.2 MiB | 17 lossy |
| `assets/icons` | 1.9 MiB | 1.9 MiB | 82 keep |
| `assets/ui` (title logo) | 1.2 MiB | 1.2 MiB | 1 keep |
| `assets/biomes` | 3.0 MiB | 1.0 MiB | 6 lossy |

## What is Lossy, what is not, and why

Lossy: banners, backgrounds, chapter art, biomes, card art, character portraits, monster sprites —
the large illustrated frames. Anything ≥384×384 px and ≥48 KiB, and not named below.

Lossless, deliberately: UI icons, badges, map pins, vfx sprites, the fox rig, card frames, the chest
atlas, map tiles, and the title logo. **8.6 MiB combined.** They are small, and their high-contrast
edges are precisely where a codec rings first, so compressing them buys a rounding error and risks
the most visible artifact class.

## Measured quality per category (PSNR, composited over mid-grey)

At q=0.95, min per group:

| group | min PSNR | worst file |
|---|---|---|
| backgrounds | 41.0 dB | `battle_stage_4.png` |
| banners | 39.2 dB | `banner_boss_rush.png` |
| biomes / chapters | 36.2 dB | `biome_1_autumn.png`, `chapter_5.png` |
| cards | 37.2 dB | `ironWill.png` |
| characters | 35.2 dB | `character-atlas-v3.png` |
| **monsters** | **34.5 dB** | `m_r4_25.png` |

>40 dB is conventionally indistinguishable, 35–40 dB normally invisible on a phone at arm's length,
>below ~32 dB is where soft gradients band.

**The monsters are the known worst case and the trade was made deliberately.** They are 512×512
sprites with anti-aliased rims and they were the single largest group in the pack (34.1 MiB), so
leaving them lossless would have kept roughly a third of the total saving on the table. If they
prove visible in play, one line in `tex_policy.py` holds them back (add
`assets/characters/monsters/` to `KEEP_LOSSLESS_DIRS`) — the policy is re-runnable, and `--restore`
undoes the lot.

## Two measurement traps this went through

Both produced confident wrong answers first, so they are recorded rather than quietly fixed.

**1. Source bytes are not pack bytes.** The first pass at this concluded "audio is the top target,
convert the `.wav` to OGG for ~28 MiB" by running `du` over `assets/`. That is the *source* tree;
the pack holds Godot's own imported containers, in which those `.wav` files had already been
compressed to QOA (`compress/mode=2`) and weighed 5.6 MiB. The recommendation was wrong by a factor
of five. Audio was never worth touching; texture was 90%+ of the problem.

**2. Straight (non-premultiplied) RGB over every pixel is the wrong quality metric for art with
alpha.** `tex_probe.gd` originally reported the monster sprites at ~17–23 dB — "severe artifacts" —
and reported *the same 17.5 dB at q=0.90, q=0.95 and q=0.98*. A number that does not move when the
quality setting moves is not measuring quality. On an anti-aliased rim the source RGB of a
near-transparent pixel is undefined, a codec is free to change it, and a straight comparison bills
that as error while the composited pixel is identical. Compositing both images over the same backdrop
— what a player sees — lifted those same sprites to 34.5 dB. The tool now reports the composited
figure (and alpha separately), and takes its file list from the policy so the two cannot drift.

## Why Lossy rather than VRAM Compressed (ETC2/ASTC)

`textures/vram_compression/import_etc2_astc=true` is set, so ETC2/ASTC is available. It goes further
on size and additionally cuts GPU memory (Lossy is decoded to full RGBA in VRAM, so it saves pack
bytes but not VRAM). But it is a *block* codec: on the smooth colour ramps in these banners and
backgrounds it produces exactly the banding that q=0.95 avoids. The art here is illustration and
gradient — the content block codecs are worst at.

If VRAM is the actual goal (on a 60 fps mobile target holding many full-screen gradients, it
plausibly is) that is a separate measurement, and it should be measured rather than inferred from
pack size. Nothing here claims a VRAM win.
