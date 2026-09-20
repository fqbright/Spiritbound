# Asset compression: the measured case, and the decision it leaves open

Status: **research only — no `.import` sidecar has been changed, so the shipped game is byte-for-byte
unaffected.** This records what the change would cost and save, so the decision can be made (and
re-made later) from numbers rather than impressions.

Re-measure at any time with:

```bash
godot --headless --path Godot/ -s tools/tex_probe.gd
```

## Current state

Every one of the **638 texture sources is imported Lossless** (`compress/mode=0`). Read straight
from the `.import` sidecars:

| import mode | files | source bytes |
|---|---|---|
| `compress/mode=0` (Lossless) — textures | 638 | 182.0 MiB |
| `compress/mode=2` — the `.wav` audio (QOA; the audio importer's `mode=2` is unrelated to the texture importer's) | 30 | 27.6 MiB |
| none — the two `.ttf` fonts | 2 | 13.2 MiB |

**These are source-directory figures, not pack figures.** They are not interchangeable with what
ends up in the `.pck`, which stores Godot's own imported containers: a Lossless texture becomes an
uncompressed `.ctex` holding raw pixels, which the packer then compresses itself. The pack-level
delta therefore has to be measured by an actual export; do not quote the percentages below as a
`.pck` reduction.

The largest single items are the **eight 1376x768 banners (~1.9 MiB each)** — one of them is the
background of every card on the trial-challenges screen — and a set of **720x1280 backgrounds
(~1.7-1.8 MiB each)**.

`textures/vram_compression/import_etc2_astc=true` in `project.godot`, so ETC2/ASTC (VRAM
Compressed) is available; the mobile renderer is `gl_compatibility`.

## Measured: what Lossy (compress/mode=1) actually costs

Godot's own WebP encoder, via `Image.save_webp_to_buffer()` — the same encoder the Lossy import
path uses, so this is not a third-party proxy. PSNR is measured by decoding the result back and
comparing sample pixels against the original.

| sample | source | q=0.90 | PSNR | q=0.95 | PSNR |
|---|---|---|---|---|---|
| `banners/banner_boss_rush.png` 1376x768 | 1.89 MiB | 0.29 MiB (-84.6%) | 37.5 dB | 0.39 MiB (-79.4%) | 39.1 dB |
| `backgrounds/battle_stage_4.png` 720x1280 | 1.84 MiB | 0.33 MiB (-81.8%) | 38.4 dB | 0.44 MiB (-76.2%) | 40.9 dB |
| `cards/card_back_default.png` 848x1264 | 1.91 MiB | 0.28 MiB (-85.5%) | 38.5 dB | 0.39 MiB (-79.8%) | 40.6 dB |

Roughly **-80% of source bytes**. For context on the quality column: >40 dB is conventionally
indistinguishable, 35-40 dB is normally invisible on a phone at arm's length, and below ~32 dB is
where soft gradients start to band. These banners *are* soft gradients, so they are the
worst-case content for this, and q=0.95 still lands at the indistinguishable end.

## Why Lossy rather than VRAM Compressed (ETC2/ASTC)

ETC2/ASTC goes further on size and additionally cuts GPU memory (Lossy is decoded to full RGBA in
VRAM, so it saves pack size but not VRAM). But it is a *block* codec: on the smooth colour ramps in
these banners and backgrounds it produces exactly the blocky banding that q=0.95 avoids. The art
here is illustration and gradient, not photographic texture, which is the content block codecs are
best at and gradients are what they are worst at.

So the two options trade differently, and it is not simply "ETC2 is stronger":

- **Lossy q=0.95** — ~-80% source bytes, PSNR ~40 dB, no visible change expected. No VRAM win.
- **VRAM/ETC2** — larger size win plus a real VRAM win (relevant to the 170 MB→136 MB pack that
  was previously within 85% of Apple's 200 MB cellular limit), at the cost of banding on the art
  most likely to show it.

If VRAM is the actual goal — and on a 60fps mobile target held by a large number of full-screen
gradient textures, it plausibly is — measure that separately rather than inferring it from size.

## Recommended shape of the change

1. Apply Lossy **only to large illustrated art** (banners, backgrounds, character/card art). Leave
   **UI icons, sprites and frames Lossless**: they are small, and their high-contrast edges are
   precisely where a block codec shows ringing first. This keeps the quality argument simple — no
   decision has to be made about whether a given icon survived.
2. Run `godot --headless --path Godot/ --import`, then **measure the real `.pck` delta** before and
   after (`Godot/tools/pck_audit.py`), and record both numbers. Do not extrapolate from the table
   above.
3. Expect the nine pixel-diff baselines to shift: the thresholds are tight (0.8%-2.5%), so any
   lossy pass moves pixels well past them. Refresh through
   `.github/workflows/refresh-baselines.yml`, which re-captures under the CI renderer, re-checks the
   result against a second capture, and reports the verdict in its commit body. Do **not** recapture
   locally — a local Metal capture disagrees with the committed baselines on all 7 of the original
   screens.
4. Re-run `./run_tests.sh` and confirm the pack still boots (`Godot/tools/pck_audit.py` exists for
   the pack side).

## Not done, and why

Nothing in this document has been applied. Compression quality is a visual judgement about the
game's art, it changes every committed baseline, and the evidence above makes the choice
low-risk but still a choice — so the numbers are recorded here rather than a setting being
flipped unilaterally.
