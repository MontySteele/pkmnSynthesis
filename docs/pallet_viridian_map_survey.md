# Pallet Town → Route 1 → Viridian City: Map Survey

> Comprehensive catalog of the opening game slice for the map rework project.
> Generated from game data analysis, March 2026.

---

## Overview

This slice covers the player's first steps: leaving Pallet Town, walking Route 1, and arriving in Viridian City. It includes all interiors, the Viridian Gym (endgame), and several variant maps used for different game phases.

**Key finding:** Viridian City has 3 outdoor variants (Map079, Map710, Map711) used at different story stages. Map097 is an unused Route 1 placeholder (empty tileset, 2 events). Map205, Map076 are interior sub-maps of Pallet houses.

---

## Map Inventory

### Pallet Town (6 active maps)

| Map ID | Name | Dimensions | Tileset | Events | Notes |
|--------|------|-----------|---------|--------|-------|
| 042 | Pallet Town | 75×28 | Outdoor | 39 | Main overworld; Oak's Lab, Player's House, docks |
| 043 | Player's House | 20×15 | Indoor | 12 | Bedroom, living room |
| 076 | Pallet Town (house) | 20×15 | Indoor | 10 | Blue's house interior |
| 077 | Oak's Lab | 20×30 | Indoor | 54 | Starter selection, Pokedex, rival fight |
| 205 | Pallet Town (house) | 20×15 | Indoor | 8 | NPC house |

*Also: 5 regional Oak's Lab variants (Maps 551, 552, 593, 659 for Johto/Hoenn/Sinnoh/Custom starters), dream sequence maps (719-724), and legacy backups (430, 740, 847) — not in scope for rework.*

### Route 1 (3 active maps)

| Map ID | Name | Dimensions | Tileset | Events | Notes |
|--------|------|-----------|---------|--------|-------|
| 078 | Route 1 | 44×50 | Outdoor2 | 14 | Main route; tall grass, ledges |
| 097 | Route 1 (unused) | 42×50 | (empty) | 2 | Placeholder — empty tileset, skip |
| 185 | Secret Garden | 35×20 | Outdoor2 | 7 | Hidden area accessible from Route 1 |

### Viridian City (11 active maps)

| Map ID | Name | Dimensions | Tileset | Events | Notes |
|--------|------|-----------|---------|--------|-------|
| 079 | Viridian City | 51×50 | Outdoor | 32 | Main overworld (early game) |
| 710 | Viridian City | 45×50 | Outdoor | 32 | Alternate overworld (mid game) |
| 711 | Viridian City | 51×50 | Outdoor | 40 | Alternate overworld (late game) |
| 081 | PokeMart | 20×15 | Indoor | 13 | Shop; Oak's Parcel quest |
| 083 | Viridian City (house) | 20×15 | Indoor | 12 | NPC house |
| 084 | Viridian City (house) | 20×15 | Indoor | 9 | NPC house |
| 085 | Viridian City Gym | 45×45 | Indoor | 44 | Giovanni + 8 gym trainers |
| 371 | Pokemon Center | 20×15 | Indoor | 12 | Healing, PC |
| 458 | Pokémon Academy | 20×15 | Indoor | 16 | Tutorial NPCs |
| 746 | Viridian City (house) | 20×15 | Indoor | 8 | NPC house |
| 038 | Trainer House | 20×16 | Interior | 12 | Battle facility; many held items |

**Total active maps: 20** (6 Pallet + 3 Route 1 + 11 Viridian)

---

## Map Connections (Navigation Graph)

### Overworld Connections (map-edge seams)
```
Route 21 (south) ←→ Pallet Town (042)
                          ↕
                     Route 1 (078) ←→ Viridian River (040, side path)
                          ↕               ↕ Secret Garden (185)
                   Viridian City (079/710/711)
                     ↕           ↕
                Route 22 (west)  Route 2 (north, → Viridian Forest → Pewter)
```

### Interior Warps (doors)

**Pallet Town (042) doors:**
| Target | Name | Type |
|--------|------|------|
| 043 | Player's House | Interior |
| 076 | Blue's House | Interior |
| 077 | Oak's Lab | Interior |
| 205 | NPC House | Interior |
| 551/552/593/659 | Regional Oak Labs | Special (postgame) |

**Route 1 (078) doors:**
| Target | Name | Type |
|--------|------|------|
| 185 | Secret Garden | Hidden area |

**Viridian City (079/710/711) doors:**
| Target | Name | Type |
|--------|------|------|
| 081 | PokeMart | Shop |
| 083 | NPC House 1 | Interior |
| 084 | NPC House 2 | Interior |
| 085 | Viridian Gym | Gym |
| 371 | Pokemon Center | Healing |
| 458 | Pokémon Academy | Tutorial |
| 038 | Trainer House | Battle facility (Map710/711 only) |
| 746 | NPC House 3 | Interior (Map711 only) |

### External Exits (connections outside this slice)
| From | To | Direction |
|------|----|----|
| Pallet Town (042) | Route 21 / Cerulean | South |
| Pallet Town (042) | S.S. Anne (027) | Dock |
| Viridian City | Route 22 (171) | West |
| Viridian City | Route 2 (086) | North |
| Viridian City (710/711) | Pinkan Island (051) | Special |

---

## Trainer Battles

### Viridian Gym (Map085) — 9 trainers

| Event | Trainer Class | Name | Notes |
|-------|--------------|------|-------|
| 38 | BLACKBELT | Atsushi | |
| 33 | COOLTRAINER_M | Samuel | |
| 34 | ENGINEER | Cole | |
| 35 | BLACKBELT | Kiyo | |
| 31 | BLACKBELT | Takashi | "Karate King" |
| 37 | ENGINEER | Jason | |
| 32 | COOLTRAINER_M | Yuji | |
| 15 | COOLTRAINER_F | Justine | |
| 92 | LEADER_Giovanni | Giovanni | Gym Leader; Earth Badge + TM26 |

### Other Trainers

| Map | Trainer Class | Name | Notes |
|-----|--------------|------|-------|
| 077 (Oak's Lab) | RIVAL1 | Blue | 3 variants (one per starter choice) |
| 078 (Route 1) | LASS | Mimi | |
| 079/710/711 (Viridian) | WORKER | Dave | Same trainer on all 3 variants |

**Total unique trainer battles: 13** (9 gym + 3 rival variants + 1 route + 1 city)

### Trainer Pokemon

*Trainer pokemon data is stored in `trainers.dat` (GameData::Trainer format). The exact teams require loading the full Pokemon Essentials runtime to decode. For the rework, equivalent-difficulty teams should be designed based on:*
- Gym trainers: levels ~45-50 (endgame gym)
- Giovanni: level ~47-50 (gym leader)
- Blue (rival): level 5 (starter battle)
- Lass Mimi: level ~3-5 (early route)
- Worker Dave: level ~3-5 (early city)

---

## Items

### Key Items & Story Items

| Map | Item | Notes |
|-----|------|-------|
| 077 (Oak's Lab) | POKEBALL ×5 | From Oak after Pokedex |
| 081 (PokeMart) | OAKSPARCEL | Quest item |
| 081 (PokeMart) | DNASPLICERS | Fusion item |
| 042 (Pallet) | CAPTAINSKEY | S.S. Anne access |
| 076 (Pallet house) | TOWNMAP | Key item |
| 085 (Gym) | TM26 | From Giovanni |
| 079 (Viridian) | EARTHPLATE, BRIGHTPOWDER, WOODENPLANKS, ICEPICK, POWERPLANTKEY, GASMASK | Various quest/held items |
| 043 (Player's House) | SHINYCHARM | Special item |

### Consumable Items

| Map | Item |
|-----|------|
| 078 (Route 1) | ORANBERRY, POTION |
| 097 (Route 1 alt) | POTION |
| 085 (Gym) | REVIVE, FRESHWATER |
| 185 (Secret Garden) | MAXREVIVE |
| 458 (Academy) | ORANBERRY |

### Trainer House (Map038) — Battle Facility Items
38 items available including: berries (Leppa, Lum, Sitrus, Custap, Jaboca, Rowap), held items (Scope Lens, Wide Lens, Zoom Lens, Muscle Band, Focus Band, Choice Band/Specs/Scarf, Life Orb, Leftovers, Quick Claw, Black Sludge), vitamins (Protein, Iron, Carbos, Zinc, Calcium, HP Up, PP Up), and training items (Power Bracer/Belt/Lens/Anklet/Weight).

**Total unique items: ~55** (17 in main areas + 38 in Trainer House)

---

## NPCs & Signs

| Map | NPCs | Signs | Notes |
|-----|------|-------|-------|
| 042 (Pallet Town) | 12 | 6 | Includes Oak, Blue, trade NPC, quest NPCs |
| 043 (Player's House) | 2 | 8 | Mom, furniture descriptions |
| 076 (Pallet house) | 2 | 5 | |
| 077 (Oak's Lab) | 13 | 34 | Heavy scripting for starter sequence |
| 078 (Route 1) | 2 | 1 | Mart clerk tutorial, NPC |
| 079 (Viridian City) | 8 | 5 | |
| 081 (PokeMart) | 4 | 6 | Shopkeeper, Oak's aide |
| 083 (Viridian house) | 5 | 4 | |
| 084 (Viridian house) | 3 | 3 | |
| 085 (Viridian Gym) | 10 | 0 | Trainers + Gym Guide |
| 371 (Pokemon Center) | 4 | 0 | Nurse Joy, PC |
| 458 (Academy) | 7 | 5 | Tutorial NPCs |
| 710 (Viridian alt) | 9 | 5 | |
| 711 (Viridian alt) | 9 | 6 | |
| Other | 5 | 9 | Remaining interiors |

**Total: 95 NPCs, 97 signs** across all maps

---

## Wild Pokemon Encounters

### Pallet Town (Map042) — Water/Fishing only
| Type | Species | Level | Rate |
|------|---------|-------|------|
| Land | Bulbasaur | 5 | 20% |
| Land | Charmander | 5 | 20% |
| Land | Squirtle | 5 | 20% |
| Land | Ivysaur | 10 | 10% |
| Land | Charmeleon | 10 | 10% |
| Land | Wartortle | 10 | 10% |
| Land | Venusaur | 15 | 3% |
| Land | Charizard | 15 | 3% |
| Land | Blastoise | 15 | 3% |
| Land | Mew | 1 | 1% |
| Water | Magikarp | 2-5 | 65% |
| Water | Poliwag | 2-3 | 35% |
| Old Rod | Magikarp | 5 | 80% |
| Old Rod | Poliwag | 5 | 20% |
| Good Rod | Poliwag | 5-15 | 60% |
| Good Rod | Goldeen | 5-15 | 20% |
| Good Rod | Magikarp | 5-15 | 20% |
| Super Rod | Poliwhirl | 20-30 | 70% |
| Super Rod | Psyduck | 15-30 | 15% |

*Step chance: Land 21, Water 2*

### Route 1 (Map078) — Day/Night variants
| Type | Species | Level | Rate |
|------|---------|-------|------|
| Day | Pidgey | 2-5 | 50% |
| Day | Rattata | 2-5 | 45% |
| Day | Tangela | 2-3 | 5% |
| Night | Hoothoot | 2-5 | 50% |
| Night | Rattata | 2-5 | 45% |
| Night | Mime Jr. | 2-3 | 5% |

*Step chance: 21*

### Secret Garden (Map185)
| Type | Species | Level | Rate |
|------|---------|-------|------|
| Day | Tangela | 2-3 | 45% |
| Day | Pidgey | 2-3 | 40% |
| Day | Eevee | 2-5 | 10% |
| Day | Mime Jr. | 2-3 | 5% |
| Night | Mime Jr. | 2-3 | 45% |
| Night | Rattata | 2-3 | 35% |
| Night | Ditto | 2-5 | 15% |
| Night | Tangela | 2-3 | 5% |

*Viridian City (079/710/711) and Viridian Gym (085) have no wild encounters.*

**Total unique wild species: 15** (Pidgey, Rattata, Tangela, Hoothoot, Mime Jr., Eevee, Ditto, Bulbasaur, Charmander, Squirtle, Ivysaur, Charmeleon, Wartortle, Venusaur+Charizard+Blastoise, Mew, Magikarp, Poliwag, Goldeen, Poliwhirl, Psyduck)

---

## Summary Totals

| Metric | Count |
|--------|-------|
| Active maps | 20 |
| Outdoor maps (need tile rework) | 6 (042, 078, 079, 185, 710, 711) |
| Indoor maps (need tile rework) | 14 |
| Total map tiles | ~175,000 |
| Internal warps | 34 |
| External exits | 5 directions |
| Trainer battles | 13 unique |
| Items | ~55 unique |
| NPCs | 95 |
| Signs | 97 |
| Wild pokemon species | ~20 |
| Total events | 366 |

---

## Effort Estimate for Rework

### What needs 1:1 parity (automated test cases)

| Requirement | Current Count | Testable? |
|------------|--------------|-----------|
| Map connections (warps match) | 34 internal + 5 external | Yes — `validate_map.rb` |
| Trainer count & types | 13 battles | Yes — script extraction |
| Item count & types | ~55 items | Yes — script extraction |
| Wild pokemon species & rates | ~20 species | Yes — encounters.dat comparison |
| NPC count | 95 | Yes — event counting |
| Sign count | 97 | Yes — event counting |
| Event trigger types (action/touch/auto) | 366 events | Yes — event metadata |

### What needs human QA

| Aspect | Notes |
|--------|-------|
| Map aesthetics | Does the new layout look good? |
| Pathing feel | Is exploration fun? Pacing right? |
| Trainer placement | Are sight lines fair? |
| Difficulty curve | Are wild/trainer levels balanced? |
| Story flow | Does dialogue make sense in new layout? |

### Estimated work per map type

| Map Type | Tile Work | Event Work | Estimate |
|----------|----------|------------|----------|
| Large outdoor (042, 079, 710, 711) | Clone + modify layout | Re-place all events | ~2-3 hours each |
| Medium outdoor (078, 185) | Clone + modify | Re-place events | ~1-2 hours each |
| Small indoor (20×15) | Clone template | Minimal changes | ~15-30 min each |
| Gym (085, 45×45) | Design new puzzle layout | Re-place trainers | ~3-4 hours |
| Trainer House (038) | Minimal | Re-organize items | ~30 min |

### Total estimated effort

| Phase | Maps | Effort |
|-------|------|--------|
| Outdoor rework | 6 maps | ~12-16 hours |
| Indoor rework | 13 maps | ~5-8 hours |
| Gym rework | 1 map | ~3-4 hours |
| Trainer team design | 13 trainers | ~2-3 hours |
| Wild encounter balancing | 3 encounter tables | ~1 hour |
| Validation & testing | All | ~2-3 hours |
| Human QA & iteration | All | ~3-5 hours |
| **Total** | **20 maps** | **~28-40 hours** |

### Automation breakdown

| Task | Automated | Human | Notes |
|------|----------|-------|-------|
| Map creation from spec | 100% | — | `create_map.rb` |
| Event population | 100% | — | JSON spec → events |
| Map rendering | 100% | — | `render_map.rb` |
| Visual QA (layout check) | ~80% | ~20% | Subagent inspection + human polish |
| Structural validation | 100% | — | `validate_map.rb` |
| Warp integrity | 100% | — | Automated bidirectional checks |
| Parity testing | 100% | — | Compare counts: trainers, items, species |
| Aesthetic judgment | — | 100% | Human eye needed |
| Playtesting | ~20% | ~80% | Can verify warps work, but feel needs human |

**Bottom line: ~70% of the work is automatable.** The main human effort is designing the new layouts, tuning trainer teams, and playtesting the feel. Everything structural (connections, counts, validation) can be tested automatically.

---

## Recommended Approach

1. **Start with one outdoor map** (Route 1 is simplest — linear path, few events)
2. Write a JSON spec with new layout + same events
3. Run the full pipeline: create → render → visual QA → validate → compare counts
4. Iterate on the layout until the visual QA agent and validator both pass
5. Move to Pallet Town, then Viridian City
6. Do interiors last (they're quick — mostly just re-placing NPCs)
7. Final pass: wire up all cross-map warps, run full-slice validation
8. Human playtests the complete slice end-to-end
