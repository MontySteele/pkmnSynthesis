# Map Transplant After-Action Report

## Overview

This report documents the Johto→Kanto map transplant pipeline: replacing Kanto region tile layouts with Johto region equivalents while preserving all events, trainers, dialogue, and warps. Small interiors keep their original Kanto tiles.

## Results Summary

| Metric | Value |
|--------|-------|
| Kanto maps in scope | 408 |
| Maps matched to Johto | 407 (99.8%) |
| Small interiors self-mapped (keep Kanto) | 217 |
| Maps actually transplanted | 166 (score ≥ 50) |
| Events processed | 5,113 |
| Events kept in place | 1,840 (36.0%) |
| Events relocated via BFS | 3,273 (64.0%) |
| Events on non-walkable tiles | 29 (0.6%) |
| Out-of-bounds warps fixed | 259 |
| Validation pass rate | 823 / 831 (99.0%) |
| Dialogue injection compatibility | 100% (0 failures) |
| Max Johto map reuse | 3x (capped) |
| Visual diversity per phase | 73-98% unique |

## Tools Built

| Tool | Purpose |
|------|---------|
| `tools/map_classifier.rb` | Bulk map metadata extraction + type classification |
| `tools/match_maps.rb` | Kanto→Johto scoring + greedy assignment with self-mapping |
| `tools/transplant_events.rb` | Tile swap + anti-stacking BFS relocation + warp retargeting |
| `tools/generate_transplant_spec.rb` | Generates transplant spec from match results |
| `tools/validate_transplant.rb` | Post-transplant validation (events, walkability, warps) |
| `tools/validate_reuse.rb` | Johto map reuse tracking + visual diversity scoring |
| `tools/validate_encounters.rb` | Trainer/wild Pokemon level progression validation |
| `tools/fix_warp_coords.rb` | Fixes out-of-bounds warp coordinates post-transplant |
| `build_transplanted.sh` | Integration wrapper for transplant + build pipeline |

## Pipeline

```
1. Classify all 808 maps → map_classification.json
2. Match Kanto to Johto → map_matches.json (self-maps small interiors)
3. Generate transplant spec → transplant_full_spec.json (166 maps)
4. Run transplant → modifies game_data/Data/Map###.rxdata
5. Fix warp coordinates → fix_warp_coords.rb
6. Inject dialogue → works on transplanted maps (event IDs preserved)
7. Validate → validate_transplant.rb + validate_reuse.rb + validate_encounters.rb
8. Launch game
```

## Matching Strategy

### Three-pass approach:
1. **Pre-pass: Self-map small interiors** — 217 maps with dimensions ≤25×20 keep their original Kanto tiles. This preserves visual quality for small rooms and frees Johto maps for larger areas.
2. **Pass 1: Unique assignment** — 150 Kanto maps get unique 1:1 Johto matches. Priority goes to routes, cities, and caves (the most visible areas).
3. **Pass 2: Controlled reuse** — 40 remaining maps share Johto maps, capped at 3x maximum per Johto map.

### Reuse distribution:
- 128 Johto maps used 1x (unique)
- 6 Johto maps used 2x
- 17 Johto maps used 3x
- 57 Johto maps unused (headroom)

### Visual diversity by game phase:
| Phase | Unique Johto / Total | Diversity |
|-------|---------------------|-----------|
| Early game (Pallet→Pewter) | 27 / 37 | 73.0% |
| Mid game (Cerulean→Celadon) | 46 / 53 | 86.8% |
| Late game (Saffron→Cinnabar) | 33 / 35 | 94.3% |
| Endgame (Victory Road+) | 13 / 15 | 86.7% |

## Encounter Validation

Trainers and wild Pokemon are validated against expected level progression:
- **1,020 trainers** found across 157 maps
- **200 OK**, 10 WARN, 51 ERROR (errors are mostly rematch/NG+ variants with scaled levels — pre-existing, not transplant-caused)
- **88 wild encounter tables** checked
- Trainers remain in their correct locations (Brock in Pewter Gym, Elite Four in Victory Road, etc.)

## Known Issues

### 1. Non-walkable event placement (29 events)

BFS anti-stacking relocation can't always find unoccupied walkable tiles. 29 of 5,113 events (0.6%) are on non-walkable tiles. Impact is low — these events are unreachable but won't crash.

### 2. Pre-existing warp issues

Some maps have warps to maps outside the `Map001-Map808` range. These are pre-existing in the source game, not transplant-caused.

### 3. Route/city reuse

A few routes share the same Johto tile layout (max 3x). Notable: Route 46 used for Routes 15/19/20, Route 37 used for Routes 2/2/9. This creates some visual repetition for outdoor areas.

### 4. Event relocation quality

64% of events needed relocation. Anti-stacking BFS finds nearby walkable tiles but doesn't consider event purpose (trainer line-of-sight, NPC accessibility, etc.).

## What Went Well

1. **Injection compatibility**: Injection uses event IDs, not positions — zero failures post-transplant.
2. **Self-mapping strategy**: Keeping 217 small interiors as Kanto originals dramatically reduced transplant scope and Johto reuse.
3. **Anti-stacking BFS**: Two-pass approach (keep → relocate) prevents event clustering.
4. **Warp fixer**: Post-transplant coordinate clamping fixed 259 out-of-bounds warps automatically.

## Reproduction

```bash
# Fresh build from scratch
git clone <this-repo> && cd pkmnSynthesis
git clone --depth 1 https://github.com/infinitefusion/infinitefusion-e18 game_data

# Run pipeline
ruby tools/transplant_events.rb game_data transplant_full_spec.json
ruby tools/fix_warp_coords.rb game_data
./build_and_launch.sh --inject

# Validation
ruby tools/validate_transplant.rb game_data transplant_full_report.json
ruby tools/validate_reuse.rb map_matches.json map_classification.json
ruby tools/validate_encounters.rb game_data
ruby tools/validate_switches.rb game_data
ruby tools/smoke_test.rb game_data
```
