# Map Transplant Testing Strategy

## 1. Overview

Map transplanting replaces the tilesets and tile data on Kanto-region maps with Johto-region equivalents, giving the game world a different visual identity while preserving all gameplay logic (events, warps, dialogue, trainers). The transplant operates on the same map IDs, so a transplanted Map042 is still Map042 — only the tiles and tileset reference change.

This document describes the full validation plan: automated checks, visual review, manual play-testing, and rollback procedures.

## 2. Pipeline Steps

Starting from a clean state, the full build-and-test sequence is:

```bash
# 1. Clone the original game data (skip if already present)
./build_and_launch.sh --build-only

# 2. Back up original maps for comparison
mkdir -p game_data/.pre_transplant
cp game_data/Data/Map*.rxdata game_data/.pre_transplant/

# 3. Render "before" PNGs for visual comparison
for f in game_data/Data/Map*.rxdata; do
  ruby tools/render_map.rb game_data "$f" \
    "game_data/.pre_transplant/$(basename "${f%.rxdata}").png"
done

# 4. Run the transplant
#    (replace with actual transplant command/script)
ruby tools/transplant_maps.rb game_data <transplant_args>

# 5. Inject dialogue on top of transplanted maps
./build_and_launch.sh --inject

# 6. Run all automated validators (see Section 3)

# 7. Render "after" PNGs for visual comparison (see Section 4)

# 8. Launch for manual play-testing
./build_and_launch.sh --launch
```

**Build order matters.** Transplant must happen BEFORE dialogue injection. The transplant changes tiles and event positions; injection changes dialogue text by event ID. These operations are independent because `inject_dialogue.rb` locates events by event ID (hash key), not by (x,y) position. The fuzzy search window of +/-20 command indices provides additional safety if command lists shift slightly.

## 3. Automated Validation

Run each of the following after transplant + injection. All validators must exit 0.

### 3.1 Structural Map Validation

```bash
# Validate every transplanted map
for f in game_data/Data/Map*.rxdata; do
  ruby tools/validate_map.rb game_data "$f"
done
```

**What it checks:**
- All events are within map bounds (critical — transplanted maps may have different dimensions)
- Event command structures are well-formed (balanced branches, choice blocks, terminators)
- Warp targets exist and land within the target map's bounds
- Return warps are present (warns on one-way warps)
- Switch/variable IDs do not collide with Synthesis reserved ranges (switches 1130-1175, variables 340-360)
- Trainer battles reference non-empty trainer names
- Tile data dimensions match the map's declared width/height

**Expected output:** `[OK] All checks passed.` for each map. Any `[ERROR]` lines are blockers.

### 3.2 Dialogue Injection Validation

```bash
ruby tools/validate_injection.rb game_data
```

Confirms that all dialogue changes from `dialogue_changes/*.json` were successfully applied to the map files. Since injection uses event IDs (not positions), same-ID transplants should not cause injection failures.

### 3.3 Dialogue Conflict Check

```bash
ruby tools/validate_conflicts.rb
```

Checks for cross-file conflicts where multiple dialogue JSON files target the same event/command index. Transplanting does not change dialogue files, but this catches any pre-existing issues.

### 3.4 Silph Co. Fork Logic

```bash
ruby tools/validate_fork.rb game_data
```

Validates the Silph Co. story branch logic. Run this even if Silph Co. maps were not transplanted, to confirm nothing was disturbed.

### 3.5 Switch/Variable Collisions

```bash
ruby tools/validate_switches.rb game_data
```

Verifies that no switch or variable IDs collide between the base game and Synthesis reserved ranges.

### 3.6 Pre-Commit Validation

```bash
ruby tools/pre_validate.rb
```

Comprehensive check that covers injection structure, conflict detection, and general consistency. Run this as the final automated gate.

### 3.7 Smoke Test

```bash
ruby tools/smoke_test.rb
```

Quick sanity check of core functionality.

### 3.8 Full Dry-Run Injection

```bash
./build_and_launch.sh --dry-run
```

Runs the entire injection pipeline without writing files. Confirms that injection would succeed on the transplanted maps.

### Automated Validation Summary

| Script | What It Catches | Blocking? |
|--------|----------------|-----------|
| `validate_map.rb` (per map) | Out-of-bounds events, broken warps, bad commands, tile mismatches | Yes |
| `validate_injection.rb` | Dialogue not applied, missing event targets | Yes |
| `validate_conflicts.rb` | Cross-file dialogue conflicts | Yes |
| `validate_fork.rb` | Silph Co. branch logic errors | Yes |
| `validate_switches.rb` | Switch/variable collisions | Yes |
| `pre_validate.rb` | Broad consistency checks | Yes |
| `smoke_test.rb` | Core functionality regression | Yes |
| `--dry-run` | Injection pipeline errors | Yes |

## 4. Visual Review Process

Automated validators catch structural problems but cannot detect visual issues like misaligned tiles, wrong tileset assignments, or aesthetic problems. Use `render_map.rb` for before/after comparison.

### 4.1 Render After-Transplant PNGs

```bash
mkdir -p game_data/.post_transplant

for f in game_data/Data/Map*.rxdata; do
  ruby tools/render_map.rb game_data "$f" \
    "game_data/.post_transplant/$(basename "${f%.rxdata}").png"
done
```

### 4.2 Side-by-Side Comparison

Compare the before and after images for each transplanted map:

```bash
# Quick visual diff using ImageMagick (if available)
for f in game_data/.pre_transplant/Map*.png; do
  base=$(basename "$f")
  post="game_data/.post_transplant/$base"
  if [ -f "$post" ]; then
    compare "$f" "$post" "game_data/.post_transplant/diff_${base}" || true
  fi
done
```

Alternatively, open both directories in an image viewer and flip between them.

### 4.3 What to Look For

- **Event markers are in walkable areas.** Events rendered as colored dots (red=trainer, blue=NPC, green=warp, yellow=item, purple=sign) should be on accessible tiles, not inside walls or water.
- **Warp markers (green dots) are at map edges or doorways.** If a warp dot appears in the middle of open terrain, the transplanted tileset may have changed what was a door/stairway.
- **Tileset coverage.** No large areas of black (tile ID 0) or garbage tiles, which would indicate a tileset mismatch.
- **Map dimensions.** If the transplanted map is larger or smaller than the original, check that events near the edges are still in bounds (the automated validator catches this, but visual confirmation helps).

## 5. Manual Play-Testing Checklist

After all automated checks pass and visual review looks acceptable, play through the following in-game. Focus on transplanted maps.

### 5.1 Warp Connectivity

- [ ] Walk between all connected outdoor maps (route transitions work, player lands in correct spot)
- [ ] Enter and exit every building on transplanted maps (interior warps function correctly)
- [ ] Check cave entrances and exits
- [ ] Test any multi-floor buildings (elevator/stairway warps)
- [ ] Verify warp landing positions are on walkable tiles (not stuck in walls)

### 5.2 NPC Dialogue

- [ ] Talk to every NPC on transplanted maps (dialogue injection preserved)
- [ ] Confirm dialogue text matches what is defined in `dialogue_changes/*.json`
- [ ] Check that multi-page events (NPCs with different dialogue based on switches) still cycle correctly
- [ ] Test choice prompts and verify all branches respond correctly

### 5.3 Trainer Battles

- [ ] Battle every trainer on transplanted maps
- [ ] Confirm trainers are reachable (not blocked by impassable terrain)
- [ ] Verify trainer line-of-sight is not blocked by new tile passability
- [ ] Check that post-battle dialogue displays correctly

### 5.4 Item Pickups and Signs

- [ ] Collect all item balls on transplanted maps
- [ ] Read all signs (confirm text is correct)

### 5.5 Movement and Collision

- [ ] Walk the full perimeter of each transplanted map (no invisible walls or gaps)
- [ ] Check that water tiles are surfable where expected
- [ ] Verify ledges and jump tiles function correctly
- [ ] Confirm no areas are softlock-prone (player can always leave)

### 5.6 Story Progression

- [ ] Play through any story sequences that span transplanted maps
- [ ] Verify cutscenes trigger and complete normally
- [ ] Check that switch-gated progression (e.g., gym badges opening routes) still works

## 6. Rollback Plan

If transplant introduces blocking issues, restore the original maps:

### 6.1 From Pre-Transplant Backup

```bash
# Restore all original maps from the backup taken in Step 2
cp game_data/.pre_transplant/Map*.rxdata game_data/Data/

# Re-inject dialogue on the restored originals
./build_and_launch.sh --inject

# Verify restoration
ruby tools/validate_injection.rb game_data
```

### 6.2 From Git (Original Game Clone)

If no local backup exists, re-clone the original game data:

```bash
# Remove the modified game data
rm -rf game_data

# Re-clone and re-inject
./build_and_launch.sh --build-only
./build_and_launch.sh --inject
```

### 6.3 Partial Rollback

To restore only specific maps while keeping others transplanted:

```bash
# Restore a single map
cp game_data/.pre_transplant/Map042.rxdata game_data/Data/Map042.rxdata

# Re-inject dialogue for that map
./build_and_launch.sh --inject
```

## 7. Known Limitations

### 7.1 BFS-Relocated Events May Look Odd

When the transplant uses BFS to find the nearest walkable tile for a displaced event, the event's facing direction is preserved from the original map. A trainer who was facing a wall may now face open terrain, or vice versa. This is cosmetic but can affect trainer line-of-sight behavior.

**Mitigation:** Visual review with `render_map.rb` event markers. Flag any trainers that appear to face into walls or away from their intended patrol area.

### 7.2 Map Dimension Differences

If a Johto source map has different dimensions than the Kanto target, the transplanted map may have extra empty space or may be smaller than expected. Events near the original edges could end up out of bounds on a smaller map.

**Mitigation:** `validate_map.rb` checks event bounds against map dimensions and will flag any out-of-bounds events as errors.

### 7.3 Visual Style Shifts

Johto tilesets have a different art style than Kanto. The transition between transplanted and non-transplanted maps will be visually abrupt. This is expected and by design — the transplant is intended to give a distinct regional feel.

### 7.4 Tileset Passability Differences

Johto tilesets may define different passability for visually similar tiles. A tile that was walkable in the Kanto tileset might be impassable in the Johto tileset (or vice versa). This can create invisible walls or allow walking through apparently solid objects.

**Mitigation:** Manual play-testing (Section 5.5) is the primary way to catch these issues. Walk the full extent of each transplanted map.

### 7.5 Autotile Behavior

Autotiles (water, grass borders, cliffs) from a different tileset may not connect seamlessly with adjacent non-transplanted maps. Border tiles at map edges may display incorrectly.

**Mitigation:** Visual review of map-edge areas in the rendered PNGs. In-game, check transitions between transplanted and non-transplanted areas.

### 7.6 Same-ID Transplant Warp Safety

Because transplant preserves map IDs (Map042 stays Map042), all existing warps pointing to transplanted maps remain valid without retargeting. This is a significant simplification but means the transplant cannot rearrange map IDs.
