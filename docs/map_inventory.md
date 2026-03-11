# Map Inventory — Pokemon: Synthesis

> **Generated:** 2026-03-11
> **Source:** `ruby tools/smoke_test.rb game_data/Data` + cross-reference with `dialogue_changes/*.json` and `docs/city_plans/`

---

## Summary Statistics

| Metric | Count | Percentage |
|--------|-------|------------|
| Total map files | 809 | -- |
| Maps with dialogue | 752 | -- |
| Maps without dialogue | 57 | -- |
| **Kanto story maps (in scope)** | **~390** | -- |
| Maps DONE (injected) | 17 | 2.3% of dialogue maps |
| Maps READY (JSON written, not yet injected) | 25 | 3.3% |
| Maps IN_PROGRESS | 0 | 0% |
| Maps PLANNED (city plan exists, no JSON) | ~25 | ~3.3% |
| Maps NOT_STARTED | ~325 | ~43.2% |
| Maps SPECIAL_LOGIC | ~12 | ~1.6% |
| Non-Kanto / SKIP | ~300 | -- |
| Events with dialogue | 8,030 | -- |
| Events modified | 262 | 3.3% |
| Dialogue blocks total | 46,417 | -- |
| Dialogue blocks modified | 1,089 | 2.3% |

### dialogue_changes files (12):

| File | Maps Covered | Status |
|------|-------------|--------|
| `pallet_town.json` | 42, 43, 48, 77, 78 | Injected |
| `viridian_city.json` | 79, 80, 81, 83, 84, 491 | Injected |
| `pewter_city.json` | 91, 93 | Injected |
| `pewter_museum.json` | 96 | Ready |
| `pewter_routes.json` | 86, 92, 106 | Ready |
| `mt_moon.json` | 102, 105 | Ready |
| `cerulean_blue.json` | 1 | Injected |
| `cerulean_city.json` | 1, 4, 5, 7, 8, 9, 10, 11, 324, 387-389, 461-462 | Ready |
| `route22_blue.json` | 171 | Injected |
| `champion_blue.json` | 328 | Injected |
| `silph_co_blue.json` | 757 | Injected |
| `vermilion_city.json` | 16, 19, 24, 25, 26, 27 | Ready |

### City plan docs (9):

| Doc | Covers |
|-----|--------|
| `00_pallet_town.md` | Maps 42, 43, 48, 77, 78 |
| `01_viridian_city.md` | Maps 79, 80, 81, 83, 84, 491, 710, 711, 746, 40, 669 |
| `02_pewter_city.md` | Maps 91, 93, 96, 86, 92, 102, 105, 106, 380 |
| `03_cerulean_city.md` | Maps 1-11, plus interiors |
| `04_vermilion_city.md` | Maps 16, 19-37, Vermilion interiors |
| `07_saffron_city.md` | Maps 108, Silph Co floors, Saffron interiors |
| `08_fuchsia_city.md` | Maps 472, 481, 482, Safari Zone, Routes 12-18 |
| `09_cinnabar_island.md` | Maps 98, 125, 189, 190, 207, 219, Pokemon Mansion |
| `10_endgame.md` | Viridian return, Victory Road, Indigo Plateau |

---

## Status Key

| Status | Meaning |
|--------|---------|
| **DONE** | Has a validated `dialogue_changes` JSON that has been injected into map data |
| **READY** | Has a `dialogue_changes` JSON written and validated, awaiting injection |
| **IN_PROGRESS** | Has a `dialogue_changes` JSON but not yet injected or validated |
| **PLANNED** | Has a city plan doc but no JSON yet |
| **NOT_STARTED** | No plan or JSON exists |
| **SPECIAL_LOGIC** | Flagged in `special_logic_areas.md`; needs scripting beyond dialogue replacement |
| SKIP | Backup, duplicate, non-Kanto, debug, or zero-dialogue map |

---

## 1. Pallet Town (Phase 0: Opening)

*City plan: `00_pallet_town.md` -- Status: IMPLEMENTED*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 042 | Pallet Town | 27 | 173 | DONE |
| 043 | \PN's House | 10 | 184 | DONE |
| 048 | \PN's Room | 10 | 18 | DONE |
| 077 | Oak's Lab | 48 | 466 | DONE |
| 078 | Route 1 | 6 | 28 | DONE |
| 076 | Pallet Town (south) | 7 | 36 | NOT_STARTED |
| 097 | Route 1 (interior) | 2 | 10 | NOT_STARTED |
| 185 | Secret Garden | 5 | 9 | NOT_STARTED |
| 205 | Pallet Town (house) | 5 | 11 | NOT_STARTED |

---

## 2. Route 1

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 078 | Route 1 | 6 | 28 | DONE |
| 097 | Route 1 (gate/interior) | 2 | 10 | NOT_STARTED |
| 185 | Secret Garden | 5 | 9 | NOT_STARTED |

---

## 3. Viridian City + Viridian Forest (Phase 1: Innocence)

*City plan: `01_viridian_city.md`*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 079 | Viridian City | 23 | 76 | DONE |
| 080 | Pokemon Center | 12 | 193 | DONE |
| 081 | PokeMart | 10 | 32 | DONE |
| 083 | Viridian City (house) | 9 | 20 | DONE |
| 084 | Viridian City (house) | 6 | 18 | DONE |
| 491 | Viridian Forest | 54 | 243 | DONE |
| 085 | Viridian City Gym | 11 | 128 | PLANNED |
| 371 | Pokemon Center (alt) | 7 | 51 | PLANNED |
| 458 | Pokemon Academy | 12 | 88 | PLANNED |
| 710 | Viridian City (interior) | 22 | 86 | PLANNED |
| 711 | Viridian City (interior) | 23 | 88 | PLANNED |
| 746 | Viridian City (interior) | 5 | 10 | PLANNED |
| 038 | Trainer House | 4 | 429 | NOT_STARTED |
| 375 | Trainer House (interior) | 5 | 192 | NOT_STARTED |
| 040 | Viridian River | 8 | 103 | NOT_STARTED |
| 669 | Viridian River (interior) | 2 | 5 | NOT_STARTED |
| 655 | Hidden Forest | 8 | 8 | NOT_STARTED |

---

## 4. Route 2

*City plan: `01_viridian_city.md` (partial), `02_pewter_city.md` (partial)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 086 | Route 2 | 27 | 45 | READY |
| 088 | Gate (south) | 5 | 21 | NOT_STARTED |
| 089 | Gate (north) | 7 | 11 | NOT_STARTED |
| 090 | Route 2 (connector) | 3 | 4 | NOT_STARTED |
| 092 | Route 2 (north) | 5 | 92 | READY |
| 222 | Route 2 (interior) | 4 | 44 | NOT_STARTED |
| 511 | Gate (interior) | 1 | 14 | NOT_STARTED |
| 039 | Trainer House | 1 | 11 | NOT_STARTED |

---

## 5. Pewter City (Phase 1: Innocence)

*City plan: `02_pewter_city.md`*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 091 | Pewter City (interior) | 9 | 20 | DONE |
| 093 | Pewter City (interior) | 8 | 17 | DONE |
| 380 | Pewter City (overworld) | 37 | 211 | PLANNED |
| 386 | Pewter City Gym | 6 | 90 | PLANNED |
| 392 | Pokemon Center | 11 | 65 | PLANNED |
| 382 | PokeMart | 10 | 15 | PLANNED |
| 096 | Pewter City Museum (1F) | 21 | 105 | READY |
| 385 | Pewter City Museum (2F) | 17 | 39 | PLANNED |
| 381 | Pewter City Museum (basement) | 10 | 112 | PLANNED |
| 470 | Pewter City Museum (exhibit) | 6 | 11 | PLANNED |
| 459 | Pewter Hotel | 5 | 33 | PLANNED |
| 460 | Pewter Hotel (rooms) | 6 | 123 | PLANNED |

---

## 6. Route 3

*City plan: `02_pewter_city.md` (partial)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 490 | Route 3 | 29 | 319 | PLANNED |
| 379 | Pokemon Center | 9 | 88 | NOT_STARTED |

---

## 7. Mt. Moon

*City plan: `02_pewter_city.md` (partial) -- Flagged: `special_logic_areas.md` Tier 1 (Rocket encounter)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 102 | Mt. Moon (1F) | 29 | 142 | READY |
| 103 | Mt. Moon (B1F) | 3 | 3 | NOT_STARTED |
| 104 | Mt. Moon (connector) | 2 | 3 | NOT_STARTED |
| 105 | Mt. Moon (B2F) | 39 | 196 | READY |
| 116 | Mt. Moon (B3F) | 11 | 44 | NOT_STARTED |
| 117 | Mt. Moon (B4F) | 2 | 2 | NOT_STARTED |
| 494 | Mt. Moon Square | 7 | 23 | NOT_STARTED |
| 496 | Mt. Moon (connector) | 8 | 11 | NOT_STARTED |
| 515 | Mt. Moon Square (interior) | 6 | 15 | NOT_STARTED |
| 699 | Mt. Moon (deep) | 5 | 19 | NOT_STARTED |
| 827 | Mt. Moon Summit | 44 | 69 | NOT_STARTED |
| 828 | Mt. Moon Observatory | 10 | 48 | NOT_STARTED |
| 830 | Nightsky | 118 | 126 | NOT_STARTED |
| 831 | Nightsky (event) | 1 | 3 | NOT_STARTED |
| 767 | Mt. Moon (connector) | 4 | 4 | SKIP |
| 750 | Mt. Moon B2F.old | 32 | 130 | SKIP |
| 801 | Mt. Moon (old) | 0 | 0 | SKIP |
| 802 | Mt. Moon (old interior) | 3 | 8 | SKIP |

---

## 8. Route 4

*City plan: `02_pewter_city.md` (partial)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 106 | Route 4 | 9 | 41 | READY |
| 233 | Route 4 (interior) | 6 | 18 | NOT_STARTED |
| 291 | Route 4 (south) | 6 | 19 | NOT_STARTED |
| 236 | Route 4 (connector) | 0 | 0 | SKIP |

---

## 9. Cerulean City + Routes 24, 25 (Phase 1: Innocence, late)

*City plan: `03_cerulean_city.md`*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 001 | Cerulean City | 33 | 377 | READY |
| 002 | PokeMart | 11 | 39 | PLANNED |
| 003 | \PN's House (Cerulean) | 1 | 11 | PLANNED |
| 004 | Cerulean City Gym | 6 | 76 | READY |
| 005 | Cerulean City (Bike Shop interior) | 4 | 21 | READY |
| 006 | Team Rocket HQ | 16 | 269 | PLANNED |
| 007 | Bike Shop | 8 | 52 | READY |
| 008 | Route 24 (Nugget Bridge) | 19 | 256 | READY |
| 009 | Route 25 | 27 | 224 | READY |
| 010 | Cerulean Cape | 11 | 27 | READY |
| 011 | Bill's Lighthouse (exterior) | 9 | 64 | READY |
| 384 | Bill's Lighthouse (interior) | 18 | 110 | PLANNED |
| 387 | Cerulean City (house) | 5 | 61 | READY |
| 388 | Cerulean City (house) | 4 | 12 | READY |
| 389 | Cerulean City (house) | 4 | 27 | READY |
| 461 | Cerulean Hotel | 4 | 27 | READY |
| 462 | Cerulean Hotel (rooms) | 3 | 72 | READY |
| 383 | Gate | 1 | 2 | NOT_STARTED |
| 178 | Bill's Garden | 4 | 4 | NOT_STARTED |
| 390 | connection | 0 | 0 | SKIP |
| 739 | backup | 27 | 111 | SKIP |

---

## 10. Route 5 + Underground

*City plan: `04_vermilion_city.md` (partial)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 012 | Route 5 | 12 | 121 | PLANNED |
| 013 | Day Care Center | 3 | 129 | PLANNED |
| 214 | Day Care Center (interior) | 9 | 131 | NOT_STARTED |
| 014 | Underground | 5 | 5 | NOT_STARTED |
| 015 | Northern Gate | 6 | 80 | NOT_STARTED |
| 397 | Underground Gate | 2 | 5 | NOT_STARTED |

---

## 11. Vermilion City + Route 6 (Phase 2: Complication)

*City plan: `04_vermilion_city.md`*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 016 | Route 6 | 45 | 145 | READY |
| 018 | Southern Gate | 5 | 65 | NOT_STARTED |
| 019 | Vermilion City | 41 | 235 | READY |
| 020 | Pokemon Center | 9 | 109 | PLANNED |
| 021 | PokeMart | 24 | 52 | PLANNED |
| 022 | Vermilion City (house) | 4 | 21 | PLANNED |
| 023 | Vermilion City (house) | 7 | 28 | PLANNED |
| 024 | Vermilion City Gym | 22 | 230 | READY |
| 025 | Pokemon Fan Club | 11 | 96 | READY |
| 026 | Harbour | 6 | 28 | READY |
| 037 | Vermilion City (house) | 5 | 57 | PLANNED |
| 061 | Vermilion City Gym (rematch) | 22 | 260 | NOT_STARTED |
| 155 | Route 11 | 10 | 335 | NOT_STARTED |
| 161 | Lighthouse | 6 | 22 | NOT_STARTED |
| 226 | Vermilion City (docks) | 30 | 64 | PLANNED |
| 394 | Vermilion City (house) | 2 | 17 | PLANNED |
| 395 | Vermilion City (house) | 8 | 30 | PLANNED |
| 396 | Underground Gate | 2 | 3 | NOT_STARTED |
| 463 | Vermilion Hotel | 4 | 39 | PLANNED |
| 464 | Vermilion Hotel (rooms) | 6 | 188 | PLANNED |
| 546 | Fighting Arena | 37 | 561 | NOT_STARTED |
| 158 | Gate | 0 | 0 | SKIP |
| 231 | Underwater | 0 | 0 | SKIP |
| 733 | Vermilion City_backup | 35 | 126 | SKIP |
| 749 | Vermilion City_backup | 31 | 115 | SKIP |

---

## 12. SS Anne

*Flagged: `special_logic_areas.md` Tier 1 (simplified to dialogue-only)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 017 | S.S. Anne (main deck) | 15 | 288 | SPECIAL_LOGIC |
| 027 | S.S. Anne (entrance hall) | 11 | 91 | READY |
| 028 | S.S. Anne (cabins A) | 17 | 84 | SPECIAL_LOGIC |
| 029 | S.S. Anne (cabins B) | 17 | 174 | SPECIAL_LOGIC |
| 030 | S.S. Anne (upper deck) | 2 | 20 | SPECIAL_LOGIC |
| 031 | S.S. Anne (kitchen/crew) | 15 | 57 | SPECIAL_LOGIC |
| 034 | SS.Anne (lower deck) | 18 | 79 | SPECIAL_LOGIC |
| 035 | Captain's Room | 3 | 21 | SPECIAL_LOGIC |
| 036 | SS. Anne (cargo) | 6 | 41 | SPECIAL_LOGIC |
| 032 | S.S. Anne (connector) | 0 | 0 | SKIP |
| 201 | S.S. Anne (backup) | 1 | 1 | SKIP |

---

## 13. Route 9, 10, Rock Tunnel

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 351 | Route 9 (west) | 3 | 22 | NOT_STARTED |
| 495 | Route 9 (east, trainers) | 18 | 165 | NOT_STARTED |
| 154 | Route 10 | 22 | 104 | NOT_STARTED |
| 391 | Pokemon Center (Route 10) | 5 | 38 | NOT_STARTED |
| 349 | Rock Tunnel (1F) | 33 | 137 | NOT_STARTED |
| 350 | Rock Tunnel (B1F) | 33 | 167 | NOT_STARTED |
| 512 | Rock Tunnel (connector) | 2 | 2 | NOT_STARTED |
| 513 | Rock Tunnel (side area) | 4 | 8 | NOT_STARTED |
| 800 | Rock Tunnel (deep) | 1 | 1 | NOT_STARTED |
| 256 | Gate | 6 | 26 | NOT_STARTED |

---

## 14. Lavender Town + Pokemon Tower

*Flagged: `special_logic_areas.md` Tier 2 (Mr. Fuji choice, Project M journal)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 050 | Lavender Town | 23 | 91 | NOT_STARTED |
| 416 | Pokemon Center | 7 | 110 | NOT_STARTED |
| 422 | PokeMart | 8 | 17 | NOT_STARTED |
| 417 | Gate | 2 | 8 | NOT_STARTED |
| 418 | Pokemon House | 17 | 52 | NOT_STARTED |
| 419 | Lavender Town (house) | 4 | 23 | NOT_STARTED |
| 420 | Lavender Town (house) | 5 | 25 | NOT_STARTED |
| 421 | Nicknaming Club | 4 | 73 | NOT_STARTED |
| 109 | Hidden Tomb | 3 | 3 | NOT_STARTED |
| 400 | Pokemon Tower (entrance) | 9 | 28 | SPECIAL_LOGIC |
| 401 | Pokemon Tower F2 | 8 | 204 | SPECIAL_LOGIC |
| 402 | Pokemon Tower F3 | 7 | 25 | SPECIAL_LOGIC |
| 403 | Pokemon Tower F4 | 7 | 24 | SPECIAL_LOGIC |
| 467 | Pokemon Tower F5 | 12 | 53 | SPECIAL_LOGIC |
| 468 | Pokemon Tower F6 | 5 | 19 | SPECIAL_LOGIC |
| 469 | Pokemon Tower F7 (Mr. Fuji) | 10 | 104 | SPECIAL_LOGIC |
| 100 | Spooky chamber | 5 | 38 | NOT_STARTED |
| 142 | Pokemon Tower B1 | 3 | 4 | NOT_STARTED |
| 556 | Pokemon Tower F3 (alt) | 8 | 8 | SKIP |

---

## 15. Route 8 + Underground

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 409 | Route 8 | 21 | 362 | NOT_STARTED |
| 410 | Underground Gate (east) | 1 | 1 | NOT_STARTED |
| 411 | Underground | 9 | 64 | NOT_STARTED |
| 412 | Gate (East) | 0 | 0 | SKIP |

---

## 16. Celadon City + Routes 7, 16, 17, 18

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 095 | Celadon City (overworld) | 55 | 266 | NOT_STARTED |
| 408 | Pokemon Center | 9 | 80 | NOT_STARTED |
| 414 | Celadon City Gym | 9 | 104 | NOT_STARTED |
| 542 | Celadon City Gym (rematch) | 9 | 118 | NOT_STARTED |
| 405 | Game Corner | 39 | 91 | NOT_STARTED |
| 510 | Game Corner (basement) | 2 | 102 | NOT_STARTED |
| 406 | Celadon Cafe | 9 | 170 | NOT_STARTED |
| 768 | Celadon Cafe (alt entrance) | 2 | 56 | NOT_STARTED |
| 407 | Celadon Cafe Backstore | 10 | 325 | NOT_STARTED |
| 432 | Celadon Dpt. Store (1F) | 6 | 33 | NOT_STARTED |
| 433 | Celadon Dpt. Store (2F) | 7 | 12 | NOT_STARTED |
| 434 | Celadon Dpt. Store (3F) | 7 | 51 | NOT_STARTED |
| 435 | Celadon Dpt. Store (4F) | 9 | 19 | NOT_STARTED |
| 436 | Celadon Dpt. Store (5F) | 11 | 83 | NOT_STARTED |
| 514 | Celadon Dpt. Store (roof) | 1 | 2 | NOT_STARTED |
| 431 | Celadon Sewers (entrance) | 27 | 135 | NOT_STARTED |
| 446 | Celadon Sewers (main) | 24 | 96 | NOT_STARTED |
| 447 | Control Room | 3 | 23 | NOT_STARTED |
| 448 | Control Room (inner) | 1 | 8 | NOT_STARTED |
| 449 | Team Rocket Hideout (1F) | 17 | 100 | NOT_STARTED |
| 455 | Team Rocket Hideout (B1) | 9 | 39 | NOT_STARTED |
| 456 | Team Rocket Hideout (B2) | 10 | 42 | NOT_STARTED |
| 457 | Team Rocket Hideout (B3) | 8 | 72 | NOT_STARTED |
| 062 | Celadon City (house) | 3 | 7 | NOT_STARTED |
| 063 | Celadon City (house 2F) | 5 | 28 | NOT_STARTED |
| 064 | Celadon City (house 3F) | 4 | 11 | NOT_STARTED |
| 393 | Celadon City (house) | 3 | 19 | NOT_STARTED |
| 450 | Celadon City (house) | 4 | 12 | NOT_STARTED |
| 451 | Celadon City (house) | 2 | 8 | NOT_STARTED |
| 452 | Celadon City (house 2F) | 5 | 14 | NOT_STARTED |
| 453 | Celadon City (house) | 3 | 8 | NOT_STARTED |
| 454 | Celadon City (house 2F) | 10 | 30 | NOT_STARTED |
| 498 | Celadon City (house) | 5 | 53 | NOT_STARTED |
| 499 | Celadon City (house 2F) | 4 | 9 | NOT_STARTED |
| 500 | Celadon City (house) | 3 | 9 | NOT_STARTED |
| 501 | Celadon City (house 2F) | 4 | 49 | NOT_STARTED |
| 502 | Celadon City (house) | 3 | 10 | NOT_STARTED |
| 503 | Celadon City (house 2F) | 7 | 16 | NOT_STARTED |
| 504 | Celadon City (house 3F) | 4 | 13 | NOT_STARTED |
| 505 | Celadon Condominiums (1F) | 7 | 11 | NOT_STARTED |
| 506 | Celadon Condominiums (2F) | 8 | 83 | NOT_STARTED |
| 507 | Celadon Condominiums (3F) | 1 | 13 | NOT_STARTED |
| 509 | Celadon Condominiums (roof) | 2 | 65 | NOT_STARTED |
| 465 | Celadon Hotel | 3 | 24 | NOT_STARTED |
| 466 | Celadon Hotel (rooms) | 6 | 323 | NOT_STARTED |
| 771 | Celadon City (connector) | 2 | 8 | NOT_STARTED |
| 508 | Celadon Condominiums (4F) | 0 | 0 | SKIP |
| 072 | Celadon Sewers (connector) | 2 | 3 | NOT_STARTED |
| 372 | Celadon Sewers (old) | 1 | 1 | SKIP |

**Routes around Celadon:**

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 413 | Route 7 | 19 | 238 | NOT_STARTED |
| 425 | Underground Gate (Route 7) | 1 | 2 | NOT_STARTED |
| 415 | Western Gate | 3 | 55 | NOT_STARTED |
| 066 | Eastern Gate | 3 | 73 | NOT_STARTED |
| 438 | Route 16 | 8 | 38 | NOT_STARTED |
| 439 | House (Route 16) | 5 | 20 | NOT_STARTED |
| 474 | Gate (Route 16) | 1 | 2 | NOT_STARTED |
| 475 | Gate (Cycling Road) | 5 | 23 | NOT_STARTED |
| 146 | Route 17 (Cycling Road) | 28 | 201 | NOT_STARTED |
| 517 | Route 18 | 25 | 161 | NOT_STARTED |
| 518 | Gate (Route 18) | 1 | 2 | NOT_STARTED |
| 193 | Gate (Route 18 south) | 4 | 21 | NOT_STARTED |
| 204 | Farmhouse | 5 | 60 | NOT_STARTED |
| 516 | Route 16 (connector) | 0 | 0 | SKIP |

---

## 17. Saffron City + Silph Co. (Phase 3: Crisis)

*City plan: `07_saffron_city.md` -- Flagged: `special_logic_areas.md` Tier 3 (THE FORK)*

### Saffron City

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 108 | Saffron City (overworld) | 68 | 234 | PLANNED |
| 122 | Pokemon Center | 10 | 76 | PLANNED |
| 133 | Rocket Mart | 12 | 16 | PLANNED |
| 215 | PokeMart | 25 | 56 | PLANNED |
| 152 | Saffron City Gym | 7 | 96 | PLANNED |
| 191 | Fighting Dojo | 15 | 91 | PLANNED |
| 192 | Train Station | 9 | 35 | PLANNED |
| 179 | Police Station | 14 | 39 | PLANNED |
| 151 | Saffron Boutique | 7 | 103 | PLANNED |
| 110 | Saffron Hotel (lobby) | 6 | 30 | PLANNED |
| 111 | Saffron Hotel (rooms) | 13 | 114 | PLANNED |
| 701 | Saffron Hotel (floor 2) | 8 | 31 | PLANNED |
| 702 | Saffron Hotel (floor 3) | 3 | 5 | PLANNED |
| 112 | Saffron Bar (entrance) | 12 | 84 | PLANNED |
| 113 | Saffron Bar (VIP) | 14 | 47 | PLANNED |
| 114 | Saffron Nightclub | 27 | 188 | PLANNED |
| 115 | Saffron Bar (back room) | 15 | 76 | PLANNED |
| 195 | Saffron Bar (upstairs) | 10 | 32 | PLANNED |
| 825 | Saffron Bar (event) | 24 | 197 | PLANNED |
| 829 | Saffron Bar (event) | 35 | 349 | PLANNED |
| 120 | Saffron City (house) | 6 | 17 | PLANNED |
| 141 | Saffron City (house) | 5 | 28 | PLANNED |
| 153 | Saffron City (house) | 8 | 25 | PLANNED |
| 156 | Saffron City (house 2F) | 5 | 61 | PLANNED |
| 180 | Saffron City (house) | 3 | 122 | PLANNED |
| 182 | Saffron City (house) | 8 | 26 | PLANNED |
| 183 | Saffron City (house) | 7 | 11 | PLANNED |
| 184 | Saffron City (house 2F) | 7 | 23 | PLANNED |
| 194 | Saffron City (house) | 7 | 54 | PLANNED |
| 196 | Saffron City (house) | 5 | 54 | PLANNED |
| 199 | Saffron City (house) | 7 | 11 | PLANNED |
| 200 | Saffron City (house 2F) | 14 | 20 | PLANNED |
| 232 | Saffron City (house) | 6 | 16 | PLANNED |
| 772 | Saffron City (connector) | 2 | 8 | NOT_STARTED |
| 803 | Saffron City (house) | 2 | 50 | NOT_STARTED |

### Silph Co.

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 757 | 11F (President's Office) | 13 | 118 | DONE |
| 121 | Silph Co. (lobby) | 10 | 43 | SPECIAL_LOGIC |
| 212 | Silph Co. (connector) | 2 | 5 | SPECIAL_LOGIC |
| 660 | 2F | 13 | 63 | SPECIAL_LOGIC |
| 661 | 3F | 15 | 40 | SPECIAL_LOGIC |
| 662 | 4F | 20 | 58 | SPECIAL_LOGIC |
| 663 | 5F | 23 | 75 | SPECIAL_LOGIC |
| 758 | 6F | 29 | 114 | SPECIAL_LOGIC |
| 665 | 7F | 30 | 100 | SPECIAL_LOGIC |
| 666 | 8F | 24 | 79 | SPECIAL_LOGIC |
| 667 | 9F | 28 | 72 | SPECIAL_LOGIC |
| 668 | 10F | 22 | 34 | SPECIAL_LOGIC |
| 807 | 11F (alt/event) | 8 | 63 | SPECIAL_LOGIC |
| 658 | new (Silph 1F) | 0 | 0 | SKIP |
| 131 | 9F --old-- | 26 | 134 | SKIP |
| 305 | 11F.old | 27 | 140 | SKIP |

---

## 18. Fuchsia City + Safari Zone + Routes 12-15 (Phase 2/Post-Fork)

*City plan: `08_fuchsia_city.md` -- Flagged: `special_logic_areas.md` Tier 2 (Rival path-variant encounter)*

### Fuchsia City

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 472 | Fuchsia City (overworld) | 47 | 239 | PLANNED |
| 476 | Pokemon Center | 11 | 63 | PLANNED |
| 060 | PokeMart | 26 | 56 | PLANNED |
| 479 | Fuchsia City Gym | 8 | 161 | PLANNED |
| 473 | Safari Zone Gate | 9 | 54 | PLANNED |
| 804 | Safari Zone Gate (inner) | 3 | 19 | NOT_STARTED |
| 087 | Fuchsia City (house) | 6 | 15 | PLANNED |
| 481 | Fuchsia City (house) | 3 | 20 | PLANNED |
| 482 | Fuchsia City (house) | 5 | 42 | PLANNED |
| 477 | Fuchsia Hotel | 6 | 35 | PLANNED |
| 478 | Fuchsia Hotel (rooms) | 8 | 153 | PLANNED |
| 044 | Fuchsia City -old | 13 | 28 | SKIP |

### Safari Zone

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 445 | Area 1 | 36 | 40 | PLANNED |
| 074 | Area 1 (interior) | 4 | 8 | NOT_STARTED |
| 484 | Area 2 | 14 | 28 | PLANNED |
| 075 | Area 2 (interior) | 3 | 5 | NOT_STARTED |
| 485 | Area 3 | 39 | 53 | PLANNED |
| 082 | Area 3 (interior) | 6 | 26 | NOT_STARTED |
| 486 | Area 4 | 25 | 27 | PLANNED |
| 107 | Area 4 (interior) | 1 | 20 | NOT_STARTED |
| 487 | Area 5 | 14 | 64 | NOT_STARTED |
| 488 | Area 5 (interior) | 15 | 33 | NOT_STARTED |
| 717 | Area 5 (side) | 4 | 13 | NOT_STARTED |
| 443 | Safari Zone (hub) | 0 | 0 | SKIP |
| 493 | Area 1 _ old | 0 | 0 | SKIP |
| 715 | Area 5 (connector) | 0 | 0 | SKIP |
| 718 | Area 5 (connector) | 0 | 0 | SKIP |

### Routes 12-15

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 159 | Route 12 | 30 | 189 | PLANNED |
| 471 | Fishing Hut | 3 | 21 | PLANNED |
| 162 | Underwater (Route 12) | 13 | 26 | NOT_STARTED |
| 149 | Flooded Cave | 1 | 1 | SKIP |
| 437 | Route 13 | 46 | 350 | PLANNED |
| 220 | Underwater (Route 13) | 9 | 15 | NOT_STARTED |
| 440 | Route 14 | 15 | 123 | PLANNED |
| 444 | Route 15 | 21 | 152 | PLANNED |
| 712 | Creepy House | 24 | 25 | NOT_STARTED |
| 713 | Creepy House (2F) | 27 | 32 | NOT_STARTED |
| 714 | Creepy House (basement) | 38 | 51 | NOT_STARTED |
| 213 | Gate | 4 | 30 | NOT_STARTED |
| 441 | Gate | 0 | 0 | SKIP |
| 483 | Gate | 0 | 0 | SKIP |
| 809 | Creepy House_backup | 38 | 47 | SKIP |

---

## 19. Cinnabar Island + Pokemon Mansion (Phase 4: Reckoning)

*City plan: `09_cinnabar_island.md`*

### Cinnabar Island

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 098 | Cinnabar Island (overworld) | 27 | 129 | PLANNED |
| 130 | Pokemon Center | 10 | 70 | PLANNED |
| 188 | PokeMart | 24 | 54 | PLANNED |
| 221 | Cinnabar Island Gym | 23 | 333 | SPECIAL_LOGIC |
| 125 | Cinnabar Island (house) | 2 | 18 | PLANNED |
| 189 | Cinnabar Island (house) | 6 | 27 | PLANNED |
| 190 | Cinnabar Island (house) | 1 | 15 | PLANNED |
| 207 | Cinnabar Island (house) | 1 | 31 | PLANNED |
| 219 | Cinnabar Island (house) | 2 | 5 | PLANNED |
| 135 | Cinnabar Hotel | 5 | 31 | PLANNED |
| 136 | Cinnabar Hotel (rooms) | 4 | 109 | PLANNED |
| 206 | Cinnabar Lab (lobby) | 6 | 37 | PLANNED |
| 208 | Cinnabar Lab (research) | 5 | 197 | PLANNED |
| 209 | Cinnabar Lab (genetics) | 7 | 81 | PLANNED |
| 703 | Cinnabar Lab (restricted) | 10 | 162 | PLANNED |
| 721 | Cinnabar Lab (archive) | 5 | 110 | PLANNED |
| 616 | Cinnabar Island Harbor | 14 | 70 | NOT_STARTED |
| 761 | Cinnabar Island Harbor (dock) | 16 | 72 | NOT_STARTED |

### Pokemon Mansion

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 173 | Pokemon Mansion (1F) | 25 | 72 | PLANNED |
| 174 | Pokemon Mansion (2F) | 15 | 38 | PLANNED |
| 181 | Pokemon Mansion (3F) | 13 | 46 | PLANNED |
| 187 | Pokemon Mansion (basement) | 30 | 88 | PLANNED |

### Seafoam Islands

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 808 | Seafoam Islands B1 | 24 | 76 | NOT_STARTED |
| 054 | Seafoam Islands B3 | 3 | 10 | NOT_STARTED |
| 055 | Seafoam Islands B4 | 7 | 19 | NOT_STARTED |
| 052 | Seafoam Islands.old | 10 | 39 | SKIP |
| 053 | Seafoam Islands B2 | 3 | 3 | SKIP |
| 489 | Seafoam Islands.old (alt) | 13 | 79 | SKIP |

### Routes 19-21

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 057 | Route 19 | 9 | 93 | PLANNED |
| 058 | Route 20 | 12 | 100 | PLANNED |
| 059 | Route 21 | 11 | 77 | PLANNED |
| 056 | Surf Race | 5 | 67 | NOT_STARTED |
| 229 | Underwater (Route 21) | 4 | 9 | NOT_STARTED |
| 227 | Underwater (Route 19) | 4 | 4 | SKIP |
| 228 | Underwater (Route 20) | 4 | 4 | SKIP |
| 442 | Sunken Ship | 2 | 2 | SKIP |
| 480 | Underwater (deep) | 10 | 10 | SKIP |
| 492 | Gate (Route 19) | 0 | 0 | SKIP |

---

## 20. Viridian City (Return) + Route 22, 23 (Phase 4: Endgame)

*City plan: `10_endgame.md` -- Flagged: `special_logic_areas.md` Tier 2 (Giovanni path-variant)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 171 | Route 22 | 19 | 354 | DONE |
| 085 | Viridian City Gym | 11 | 128 | SPECIAL_LOGIC |
| 143 | Route 23 | 25 | 149 | PLANNED |
| 148 | Pokemon League Entrance | 4 | 37 | PLANNED |

*Note: Viridian City overworld maps (079, 083, 084, 710, 711, 746) are listed under section 3 above; they have return-visit content planned in `10_endgame.md`.*

---

## 21. Victory Road + Indigo Plateau (Phase 4: Endgame)

*City plan: `10_endgame.md` -- Flagged: `special_logic_areas.md` Tier 2 (Rival path-variant), Tier 3 (Champion = Rival)*

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 304 | Victory Road (1F) | 14 | 20 | PLANNED |
| 306 | Victory Road (2F) | 23 | 65 | PLANNED |
| 307 | Victory Road (3F) | 14 | 58 | PLANNED |
| 303 | Indigo Plateau | 5 | 5 | PLANNED |
| 314 | Pokemon League (lobby) | 11 | 134 | PLANNED |
| 315 | Elite 1 (Lorelei) | 3 | 85 | PLANNED |
| 316 | Elite 2 (Bruno) | 3 | 63 | PLANNED |
| 317 | Elite 3 (Agatha) | 4 | 88 | PLANNED |
| 318 | Elite 4 (Lance) | 3 | 103 | SPECIAL_LOGIC |
| 328 | Champion | 3 | 150 | DONE |
| 341 | Hall of Fame | 1 | 13 | PLANNED |
| 202 | backup | 15 | 136 | SKIP |

---

## 22. Postgame

*Flagged: `special_logic_areas.md` Tier 3 (Cerulean Cave endings)*

### Cerulean Cave

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 322 | Cerulean Cave (1F) | 11 | 11 | SPECIAL_LOGIC |
| 323 | Cerulean Cave (B1F) | 13 | 13 | SPECIAL_LOGIC |
| 324 | Cerulean Cave (B2F / Mewtwo) | 1 | 5 | READY |
| 544 | Cerulean Cave WTF | 1 | 4 | NOT_STARTED |

### Diglett's Cave

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 140 | Diglett's Cave (entrance) | 7 | 15 | NOT_STARTED |
| 398 | Diglett's Cave (middle) | 4 | 12 | NOT_STARTED |
| 399 | Diglett's Cave (exit) | 2 | 6 | NOT_STARTED |

### Power Plant

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 197 | Power Plant (exterior) | 10 | 17 | NOT_STARTED |
| 198 | Power Plant (interior) | 74 | 159 | NOT_STARTED |
| 144 | Power Plant (generator) | 10 | 16 | NOT_STARTED |
| 785 | Power Plant.old | 20 | 100 | SKIP |

### Dream Sequence

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 720 | \PN's Room? | 11 | 11 | NOT_STARTED |
| 722 | \PN's House? | 7 | 7 | NOT_STARTED |
| 723 | Pallet Town? | 12 | 28 | NOT_STARTED |
| 724 | Oak's Lab? | 23 | 87 | NOT_STARTED |
| 719 | dream sequence (hub) | 0 | 0 | SKIP |

---

## 23. Crimson City (Custom Region)

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 167 | Crimson City (overworld) | 26 | 90 | NOT_STARTED |
| 065 | Pokemon Center | 6 | 48 | NOT_STARTED |
| 119 | PokeMart | 22 | 23 | NOT_STARTED |
| 168 | Crimson City (house) | 2 | 18 | NOT_STARTED |
| 169 | Crimson City (house) | 5 | 11 | NOT_STARTED |
| 170 | Crimson City (house) | 5 | 24 | NOT_STARTED |
| 176 | Crimson Hotel | 5 | 49 | NOT_STARTED |
| 177 | Crimson Hotel (rooms) | 6 | 101 | NOT_STARTED |
| 523 | Waterfall Cave | 3 | 5 | NOT_STARTED |
| 805 | Waterfall Cave (alt) | 3 | 5 | NOT_STARTED |

---

## 24. Halfmoon / Newmoon / Fullmoon Islands

| Map ID | Name | # Events | # Blocks | Status |
|--------|------|----------|----------|--------|
| 819 | Halfmoon Island | 1 | 14 | NOT_STARTED |
| 821 | Newmoon Island | 4 | 27 | NOT_STARTED |
| 822 | Moonlit Forest | 29 | 107 | NOT_STARTED |
| 823 | Fullmoon Island | 3 | 21 | NOT_STARTED |
| 824 | Moonlit Forest (deep) | 58 | 174 | NOT_STARTED |
| 835 | Newmoon Island (inner) | 4 | 27 | NOT_STARTED |

---

## Non-Kanto / Extra (Low Priority -- all SKIP)

### Johto

Maps: 047, 049, 137-138, 230, 235, 237-251, 254-255, 258-289, 292-294,
296-302, 308-313, 319-321, 325-327, 329-340, 342-348, 352-354,
359-360, 363-368, 370, 377, 404, 426, 519-522, 524, 535-541, 545,
547-549, 571-592, 611, 631-632, 635-653, 670-677, 692-698, 709,
716, 730, 769-770, 788, 832, 834, 836-849

### Sevii Islands

Maps: 526-528, 532-534, 557-570, 594, 596-600, 603-610, 612-616,
619-630, 654, 656, 731-732, 738, 752-756, 760-766, 773-774, 786-787, 789, 806, 810-815, 826

### Pinkan Island

Maps: 051, 046, 428, 531

### Hoenn / Unova / Other

Maps: 621-623, 790-796

### Underwater / Deep Sea

Maps: 560, 570, 606, 678-691, 810-815

### System / Debug / Intro / Backups

Maps: 033, 067-071, 073, 094, 100, 118, 129, 131, 134, 139, 150, 157, 160,
165, 175, 186, 201, 203, 216-217, 223-225, 252-253, 290, 295, 305, 355-358,
372-374, 376, 378-379, 404, 423-424, 430, 442, 480, 492-493, 497, 508, 525,
550-553, 556, 558, 593, 595, 655, 658-659, 695, 700, 707-708, 715, 718-719,
733, 739-740, 745, 747, 749-751, 767, 790-802, 809, 816, 833, 846-847

---

## Special Logic Areas Reference

*From `docs/special_logic_areas.md` -- these maps need scripting beyond dialogue replacement.*

### Tier 1: Moderate (Dialogue + Switch Logic)

| Area | Maps | Scripting Needed |
|------|------|-----------------|
| S.S. Anne | 017, 027-031, 034-036 | Simplified to dialogue-only; no longer special-logic |
| Mt. Moon Rockets | 102, 105 | Possible new event for rival entrance |
| Cerulean Cave Guard | (new event on Map 322) | Single event with switch-based pages |

### Tier 2: Significant (Path Variants + New Mechanics)

| Area | Maps | Scripting Needed |
|------|------|-----------------|
| Pokemon Tower | 400-403, 467-469 | Mr. Fuji choice (Switch 1150), Project M journal event |
| Rival Path-Variants | Fuchsia (472), Victory Road (306), Champion (328) | Page conditions on path switch (1200/1201) |
| Giovanni's Gym | 085 | Two pages, path switch |
| Blaine's Gym | 221 | Two pages, path switch |

### Tier 3: Heavy (THE FORK and Endings)

| Area | Maps | Scripting Needed |
|------|------|-----------------|
| Silph Co. FORK | 121, 660-668, 757-758, 807 | Choice event, Archer trainer, path switch, post-fork scenes |
| Elite Four + Champion | 315-318, 328 | Lance path-variant, Champion = Rival trainer data |
| Cerulean Cave Postgame | 322-324 | Oak Path vs Giovanni Path Mewtwo encounter |

---

## Coverage by Progression Phase

| Phase | Description | Total Maps | DONE | READY | PLANNED | NOT_STARTED | SPECIAL_LOGIC | SKIP |
|-------|-------------|------------|------|-------|---------|-------------|---------------|------|
| 0 | Pallet Town (Opening) | 9 | 5 | 0 | 0 | 4 | 0 | 0 |
| 1a | Route 1 | 3 | 1 | 0 | 0 | 2 | 0 | 0 |
| 1b | Viridian + Forest | 17 | 6 | 0 | 6 | 5 | 0 | 0 |
| 1c | Route 2 | 8 | 0 | 2 | 0 | 6 | 0 | 0 |
| 1d | Pewter City | 12 | 2 | 1 | 9 | 0 | 0 | 0 |
| 1e | Route 3 | 2 | 0 | 0 | 1 | 1 | 0 | 0 |
| 1f | Mt. Moon | 18 | 0 | 2 | 0 | 12 | 0 | 4 |
| 1g | Route 4 | 4 | 0 | 1 | 0 | 2 | 0 | 1 |
| 1h | Cerulean + Rts 24/25 | 21 | 0 | 12 | 5 | 2 | 0 | 2 |
| 2a | Route 5 + Underground | 6 | 0 | 0 | 2 | 4 | 0 | 0 |
| 2b | Vermilion + Route 6 | 25 | 0 | 3 | 14 | 4 | 0 | 4 |
| 2c | SS Anne | 11 | 0 | 1 | 0 | 0 | 8 | 2 |
| 2d | Rt 9/10, Rock Tunnel | 10 | 0 | 0 | 0 | 10 | 0 | 0 |
| 2e | Lavender + Pkmn Tower | 19 | 0 | 0 | 0 | 11 | 7 | 1 |
| 2f | Route 8 + Underground | 4 | 0 | 0 | 0 | 3 | 0 | 1 |
| 2g | Celadon + Rts 7/16-18 | 62 | 0 | 0 | 0 | 60 | 0 | 2 |
| 3 | Saffron + Silph Co | 51 | 1 | 0 | 33 | 2 | 12 | 3 |
| 4a | Fuchsia + Safari + Rts 12-15 | 48 | 0 | 0 | 22 | 18 | 0 | 8 |
| 4b | Cinnabar + Mansion | 40 | 0 | 0 | 27 | 6 | 1 | 6 |
| 4c | Viridian Return + Rts 22/23 | 4 | 1 | 0 | 2 | 0 | 1 | 0 |
| 4d | Victory Road + Indigo | 12 | 1 | 0 | 9 | 0 | 1 | 1 |
| 5 | Postgame | 14 | 0 | 1 | 0 | 10 | 3 | 0 |
| -- | Crimson City | 10 | 0 | 0 | 0 | 10 | 0 | 0 |
| -- | Moon Islands | 6 | 0 | 0 | 0 | 6 | 0 | 0 |
| -- | Non-Kanto/System/SKIP | ~300 | 0 | 0 | 0 | 0 | 0 | ~300 |
| **TOTAL** | | **~809** | **17** | **23** | **~130** | **~178** | **~33** | **~330** |

---

*Document auto-generated from smoke test output and project docs. Re-run smoke test and update when new dialogue_changes files are added.*
