#!/usr/bin/env python3
"""Fetch public App Store metadata for the deckbuilder comparables in
Docs/COMPETITIVE_RESEARCH.md, straight from Apple's iTunes Search/Lookup API.

Why this exists: the numbers in that doc are only worth anything if the next
person can re-derive them. Run this and you get either the same table or a
diff, which is the only reliable way to tell "the market moved" from "someone
typed a number into a markdown file".

    python3 Godot/tools/store_research.py table          # the doc's table
    python3 Godot/tools/store_research.py regions        # per-storefront ratings
    python3 Godot/tools/store_research.py search "dawncaster"
    python3 Godot/tools/store_research.py lookup 1555459868

Apple exposes rating counts and listing metadata only. There is no public
endpoint for downloads, revenue, DAU or retention -- do not add a column that
implies otherwise.

Nothing is written to disk: results go to stdout only, so a run can't leave a
stale snapshot behind for someone to mistake for current data.
"""
from __future__ import annotations

import argparse
import datetime
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://itunes.apple.com"
# Apple's own listing data, and it is rate-limiting-friendly if you stay slow.
PAUSE = 0.3

# The comparables, by App Store id, so a rename can't silently change the
# subject of a comparison. Curated by hand on 2026-09-20.
COMPARABLES = {
    "Slay the Spire": 1491530147,
    "Dawncaster": 1555459868,
    "Night of the Full Moon": 1278845241,
    "Pirates Outlaws": 1442776789,
    "Monster Train": 1577392165,
    "MARVEL SNAP": 1592081003,
    "Hearthstone": 625257520,
    "Legends of Runeterra": 1480617557,
    "Loop Hero": 6464048549,
    "Card Guardians": 1566663161,
    "Ancient Gods": 6444331833,
    "Abalon": 1235934798,
    "Slice & Dice": 6449848963,
    "Buriedbornes2": 6456705641,
    "Wildfrost": 6462882621,
    "Meteorfall: Journey": 1269922212,
    "Meteorfall: Krumit's Tale": 1369611597,
    "Indies' Lies": 1573371456,
    "Dicey Dungeons": 1368013995,
    "Gordian Quest": 6736658756,
    "Vault of the Void": 6477535804,
}

# cn is listed separately on purpose: it is a different storefront with its own
# regulatory entry requirements, not just another locale.
STOREFRONTS = ["us", "tw", "hk", "sg", "my", "cn"]

CURATED_DATE = datetime.date(2026, 9, 20)


def _get(path: str, **params) -> dict:
    url = f"{API}{path}?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "spiritbound-research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def search(term: str, country: str = "us", limit: int = 6) -> list:
    body = _get("/search", term=term, entity="software", country=country, limit=limit)
    return body.get("results", [])


def lookup(app_id: int, country: str = "us") -> dict | None:
    body = _get("/lookup", id=app_id, country=country)
    return body["results"][0] if body["results"] else None


def _size_mb(row: dict) -> int | None:
    """fileSizeBytes comes back as a string from one endpoint and an int from
    the other; it is also simply absent on some listings."""
    try:
        n = int(row.get("fileSizeBytes") or 0)
    except (TypeError, ValueError):
        return None
    return n // 1048576 or None


def _age_years(row: dict) -> float:
    try:
        rel = datetime.date.fromisoformat(str(row.get("releaseDate"))[:10])
    except ValueError:
        return 0.0
    return max((CURATED_DATE - rel).days / 365.25, 0.05)


def cmd_table(args) -> int:
    print("| Title | Price | US ratings | Avg | Size | Last update | Age | Ratings/y |")
    print("| --- | --- | ---: | ---: | ---: | --- | ---: | ---: |")
    rows = []
    for name, app_id in COMPARABLES.items():
        row = lookup(app_id, "us")
        time.sleep(PAUSE)
        if not row:
            print(f"!! {name}: not returned by lookup", file=sys.stderr)
            continue
        n = row.get("userRatingCount") or 0
        avg = row.get("averageUserRating")
        age = _age_years(row)
        velocity = n / age
        rows.append(velocity)
        print("| {} | {} | {:,} | {} | {} MB | {} | {:.1f}y | {:,.0f} |".format(
            name, row.get("formattedPrice"), n,
            f"{avg:.2f}" if avg else "-", _size_mb(row) or "?",
            str(row.get("currentVersionReleaseDate"))[:10], age, velocity))
    if rows:
        rows.sort()
        n = len(rows)
        quartiles = [rows[int(q * (n - 1))] for q in (0.25, 0.5, 0.75)]
        print(f"\nratings/year quartiles (25/50/75): {[round(q) for q in quartiles]}")
    return 0


def cmd_regions(args) -> int:
    header = f"{'title':<26}" + "".join(f"{c:>10}" for c in STOREFRONTS)
    print(header)
    for name, app_id in COMPARABLES.items():
        cells = []
        for country in STOREFRONTS:
            row = None
            try:
                row = lookup(app_id, country)
            except Exception as exc:  # noqa: BLE001 - a missing storefront is data, not a crash
                print(f"!! {name}/{country}: {exc}", file=sys.stderr)
            cells.append(str(row.get("userRatingCount") or 0) if row else "absent")
            time.sleep(PAUSE)
        if all(c == "absent" for c in cells):
            continue  # skip rows that say nothing
        print(f"{name[:26]:<26}" + "".join(f"{c:>10}" for c in cells))
    return 0


def cmd_search(args) -> int:
    for row in search(args.term, args.country, args.limit):
        print("{:<44} id={:<12} {:<8} ratings={:<8} {:<5} {} MB".format(
            str(row.get("trackName"))[:44], row.get("trackId"),
            str(row.get("formattedPrice")), str(row.get("userRatingCount")),
            str(row.get("averageUserRating"))[:4], _size_mb(row) or "?"))
    return 0


def cmd_lookup(args) -> int:
    row = lookup(args.app_id, args.country)
    if not row:
        print("not found on that storefront", file=sys.stderr)
        return 1
    print(json.dumps(row, indent=1, ensure_ascii=False))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("table", help="the comparison table in Docs/COMPETITIVE_RESEARCH.md")
    p.set_defaults(func=cmd_table)

    p = sub.add_parser("regions", help="ratings per storefront, including cn")
    p.set_defaults(func=cmd_regions)

    p = sub.add_parser("search", help="free-text search, to find new comparables")
    p.add_argument("term")
    p.add_argument("--country", default="us")
    p.add_argument("--limit", type=int, default=6)
    p.set_defaults(func=cmd_search)

    p = sub.add_parser("lookup", help="dump one listing as JSON")
    p.add_argument("app_id", type=int)
    p.add_argument("--country", default="us")
    p.set_defaults(func=cmd_lookup)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
