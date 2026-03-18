# Map Transplant After-Action Report

## Overview

This report documents the Johto→Kanto map transplant pipeline: replacing Kanto region tile layouts with Johto region equivalents while preserving all events, trainers, dialogue, and warps.

## Results Summary

| Metric | Value |
|--------|-------|
| Kanto maps in scope | 408 |
| Maps matched to Johto | 407 (99.8%) |
| Maps transplanted | 388 (score ≥ 50) |
| Events processed | 7,513 |
| Events kept in place | 2,541 (33.8%) |
| Events relocated via BFS | 4,972 (66.2%) |
| Events on non-walkable tiles | 45 (0.6%) |
| Validation pass rate | 1,931 / 1,941 (99.5%) |
| Dialogue injection compatibility | 100% (0 failures across 62 files) |

## Tools Built

| Tool | Lines | Purpose |
|------|-------|---------|
| `tools/map_classifier.rb` | 277 | Bulk map metadata extraction + type classification |
| `tools/match_maps.rb` | 380 | Kanto→Johto compatibility scoring + greedy assignment |
| `tools/transplant_events.rb` | 466 | Tile swap + BFS event relocation + warp retargeting |
| `tools/generate_transplant_spec.rb` | 140 | Generates transplant spec from match results |
| `tools/validate_transplant.rb` | 292 | Post-transplant validation (events, walkability, warps) |
| `build_transplanted.sh` | ~200 | Integration wrapper for transplant + build pipeline |

## Pipeline

```
1. Classify all 808 maps → map_classification.json
2. Match Kanto maps to Johto → map_matches.json
3. Generate transplant spec → transplant_full_spec.json
4. Run transplant → modifies game_data/Data/Map###.rxdata
5. Inject dialogue → works on transplanted maps (event IDs preserved)
6. Validate → validate_transplant.rb + existing validators
7. Launch game
```

## Classifier Improvements

The initial classifier matched only 206 of 408 maps. After improvements:

- **Added name-based interior detection**: Hotel, House, Cafe, Shop, etc.
- **Expanded tileset keywords**: Interior2, Sewers, boat, arena, etc.
- **Added dimension-based fallback**: small maps (≤30×30) without Route/City in name → interior
- **Cross-type matching**: interior↔special, cave↔dungeon

Result: 507 maps classified as interior (was 203), 407 of 408 matched (was 206).

## Known Issues

### 1. Non-walkable event placement (45 events, 3 maps)

**Maps affected**: 660, 556, 703

**Root cause**: These Kanto maps were matched to Johto maps with very low walkability:
- Map695 (Burned Tower_old): **0% walkable tiles**
- Map585 (Bell Tower 5F): 18.1% walkable
- Map289 (Pokémon Center): 28.7% walkable

When BFS can't find any walkable tile, events remain at their original position on an impassable tile.

**Impact**: Low — 45 of 7,513 events (0.6%). These events will likely be unreachable in-game but won't crash. The affected maps are Silph Co. 2F (660), Pokemon Tower F3 (556), and Cinnabar Lab (703).

**Fix options**:
1. Skip these 3 transplants (keep original Kanto tiles)
2. Use a "force-place" mode that ignores passability
3. Find better Johto matches for these maps

### 2. Pre-existing warp issues (5 maps)

Maps 212, 665, 044, 663, 236, 131 have warps pointing to maps outside the `Map001-Map808` range. These are **pre-existing** in the source Kanto maps — not caused by transplant.

### 3. Johto map reuse (201 maps share Johto targets)

Only 207 unique Johto maps were available, but 407 Kanto maps needed matches. This means 201 Kanto maps share the same Johto tile layout as another Kanto map. For interiors this is fine (most PokeMarts look alike), but for routes/cities it means some areas will look identical.

### 4. Event relocation distance

66.2% of events needed relocation. While BFS finds the nearest walkable tile, events may end up far from their intended position. This is cosmetically imperfect — trainers might stand in odd places relative to terrain features.

## What Went Well

1. **Injection compatibility**: The key architectural bet — that injection uses event IDs, not positions — proved correct. Zero injection failures post-transplant.
2. **Same-ID transplant strategy**: Writing output to the same map IDs as the source eliminated all warp retargeting complexity.
3. **Existing tooling**: The project's validate_composition.rb already had passability checking and BFS, making the transplant tool straightforward to build.
4. **Classifier iteration**: Going from 206 → 407 matches with heuristic improvements was fast and effective.

## What Could Be Better

1. **Walkability edge cases**: The BFS search should handle 0% walkable maps by either skipping the transplant or relaxing passability requirements.
2. **Visual review**: We generated before/after PNGs but didn't do systematic visual review of all 388 transplanted maps.
3. **1:many Johto reuse**: A smarter assignment algorithm could minimize visual repetition by distributing Johto maps more evenly.
4. **Event relocation quality**: Currently BFS finds the *nearest* walkable tile. A better approach would consider event purpose (trainers need line-of-sight, NPCs need accessible positions, warps need edge placement).

## Files Produced

| File | Description |
|------|-------------|
| `map_classification.json` | Metadata for all 808 maps |
| `map_matches.json` | Kanto→Johto pairings with scores |
| `transplant_full_spec.json` | 388 transplant entries |
| `transplant_full_report.json` | Detailed transplant results |
| `transplant_full_log.txt` | Transplant execution log |
| `docs/map_transplant_testing.md` | Testing strategy document |
| `docs/map_transplant_report.md` | This report |
| `before_*.png` / `after_*.png` | Visual comparison renders |
| `test_transplant_spec.json` | Small batch test spec |

## Reproduction

```bash
# Fresh build from scratch
git clone <this-repo> && cd pkmnSynthesis

# Option A: Use the wrapper script
./build_transplanted.sh

# Option B: Manual steps
git clone --depth 1 https://github.com/infinitefusion/infinitefusion-e18 game_data
ruby tools/transplant_events.rb game_data transplant_full_spec.json
./build_and_launch.sh --inject

# Validation
ruby tools/validate_transplant.rb game_data transplant_full_report.json
ruby tools/validate_switches.rb game_data
ruby tools/smoke_test.rb game_data
```
