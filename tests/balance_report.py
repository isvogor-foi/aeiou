#!/usr/bin/env python3
"""Summarises tests/balance.gd output (JSON lines on stdin or files given as args)."""
import json, sys, statistics as st
from collections import Counter, defaultdict

games = []
for path in sys.argv[1:] or ["-"]:
    f = sys.stdin if path == "-" else open(path)
    for line in f:
        line = line.strip()
        if line.startswith("{"):
            games.append(json.loads(line))
if not games:
    sys.exit("no games")
n = len(games)
wins = Counter(g["winner"] or "none" for g in games)
reasons = Counter(g["reason"] for g in games)
decided = [g["minutes"] for g in games if g["winner"]]
print(f"{n} games: wins {dict(wins)}  reasons {dict(reasons)}")
if decided:
    print(f"decided games: median {st.median(decided):.1f} min, range {min(decided):.1f}-{max(decided):.1f}")
by_map = defaultdict(Counter)
for g in games:
    by_map[g["map"]][g["winner"] or "none"] += 1
print("by map:", {k: dict(v) for k, v in by_map.items()})
side = Counter((g["p0"], g["winner"] == g["p0"]) for g in games if g["winner"])
print("player-0 side wins:", {f"{k[0]} as p0 {'won' if k[1] else 'lost'}": v for k, v in side.items()})
for fac in ["monarchy", "covenant"]:
    for age in ["2", "3", "4", "5", "6"]:
        ts = [g["ages"].get(fac, {}).get(age) for g in games]
        ts = [t for t in ts if t is not None]
        if ts:
            print(f"  {fac:9s} age {age}: reached in {len(ts)}/{n}, median {st.median(ts):5.1f} min")
    armies = [g["final"][fac]["peak_army"] for g in games if fac in g["final"]]
    print(f"  {fac:9s} peak army median {st.median(armies)}")
print(f"real time per game: median {st.median(g['real_s'] for g in games):.0f}s")
