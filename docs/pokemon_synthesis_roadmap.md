# Pokemon: Synthesis — Project Roadmap

## The Big Picture

This project is a story overhaul mod for Pokemon Infinite Fusion. We are forking the existing game and replacing its dialogue, event scripting, and narrative framing while leaving the maps, mechanics, fusion system, and most game data untouched.

The deliverable is a modified version of the Infinite Fusion game files that a player can drop in and play.

**Estimated total dialogue:** ~80,000–100,000 words across two path tracks.
**Estimated total game switches needed:** ~25 (1 path switch, 5–6 positional, 15–20 flavor/state).
**One new boss fight:** Archer (Giovanni Path only).
**No new maps. No new Pokemon. No mechanical changes.**

---

## Phase 0: Technical Foundations
*Must be done first. Everything else depends on this.*

### 0A. Get the game running locally
- Clone the infinitefusion-e18 repo
- Obtain RPG Maker XP (cheap on Steam; 30-day free trial available)
- Get the game to launch and play through the first hour to understand the baseline experience
- Document any setup issues for future reference

**Who does this:** You (the human). Claude can't run RPG Maker XP.

**Why this is first:** If you can't get the game running, nothing else matters. This is the "does this project have legs" gate. It should take an afternoon at most.

### 0B. Understand the data structures
- Use RPG Maker XP to open the project and examine how events are structured
- Identify where dialogue lives: map events (Show Text commands), Ruby scripts (pbMessage calls), common events
- Document the event structure for a few representative NPCs: a gym leader, a random townsperson, a rival encounter, a Team Rocket encounter
- Identify how game switches and variables are currently used and which IDs are free

**Who does this:** You, with Claude's guidance. You open the project, describe what you see, Claude explains what it means and what we need.

**Deliverable:** A short technical reference doc — "here's how events work in this game, here's where dialogue lives, here's the switch/variable numbering plan."

### 0C. Build extraction tooling
- Write a Ruby script that reads the .rxdata map files (Ruby Marshal format), extracts all "Show Text" event commands, and dumps them to a structured format (JSON or CSV) organized by map → event → page → command
- Write a companion script that can take modified dialogue in the same format and write it back into .rxdata files
- Test the round-trip: extract → modify one line → reimport → verify in-game

**Who does this:** Claude writes the scripts. You run them against the actual game files and report results.

**Why this matters:** This is the difference between "paste dialogue into 3,000 event boxes one at a time in a GUI" and "edit a text file and run a script." The round-trip tooling is what makes the project feasible for a small team.

**Risk:** The .rxdata format may have quirks. Pokemon Essentials modifies the base RPG Maker XP data structures, and Infinite Fusion modifies them further. The extraction script may need several iterations. Budget a week of back-and-forth for this.

**Deliverable:** Two working scripts: `extract_dialogue.rb` and `inject_dialogue.rb`, plus documentation.

---

## Phase 1: Writing the Spine
*The narrative content that everything else hangs on.*

### 1A. Game switch and variable plan
Before writing any dialogue, we need a concrete technical plan for every switch and variable the story uses. This is the "wiring diagram" that connects choices to consequences.

- Assign specific switch IDs for: the path fork (Oak/Giovanni), each positional choice, each flavor flag, and any state tracking (has the player visited Lavender, has the player completed Silph Co, etc.)
- Document what each switch controls downstream
- Map out which events check which switches

**Who does this:** Claude drafts it, you verify the IDs are available in the game project.

**Deliverable:** A switch/variable map document. Every subsequent dialogue script will reference this.

### 1B. Blue's (rival's) complete dialogue track
This is the single most important writing task. Blue appears in ~10 encounters across the game, with path variants from Saffron onward. If Blue works, the story works.

Write Blue's dialogue for every encounter, both paths, including:
- Pallet Town (shared)
- Route 22 / pre-Pewter (shared)
- Cerulean City (shared)
- S.S. Anne / Vermilion (shared, if present)
- Lavender Town (shared, with positional-choice variants)
- Silph Co. — pre-fork floors (shared)
- Silph Co. — post-fork vault scene (Oak Path and Giovanni Path)
- Fuchsia City (Oak Path and Giovanni Path)
- Cinnabar (if encounter exists; may be cut)
- Victory Road (Oak Path and Giovanni Path)
- Champion's Chamber (Oak Path and Giovanni Path)
- Post-battle / ending (Oak Path and Giovanni Path)

**Who does this:** Claude drafts, you review. This will take multiple rounds.

**Deliverable:** A complete Blue dialogue script, formatted as a reference doc with map locations, switch conditions, and exact dialogue text.

### 1C. Giovanni's complete dialogue track
Second priority because he's the second most important character and his tone is specific — bitter, self-righteous, never reformed. Includes:
- Silph Co. boss fight (Oak Path — player fights him; Giovanni Path — offscreen, reported through Blue's reaction)
- Viridian Gym (Oak Path and Giovanni Path)

**Who does this:** Claude drafts, you review.

### 1D. Oak's complete dialogue track
Third priority. Oak appears infrequently but every appearance is critical:
- Pallet Town opening
- Silph Co. aftermath (both paths)
- Oak Path ending (Pallet Town return)
- Giovanni Path ending (Cerulean Cave entrance)

**Who does this:** Claude drafts, you review.

---

## Phase 2: Writing the Cities
*Working outward from the spine to fill in the world.*

The order here is based on narrative importance and implementation complexity, not geographic order:

### 2A. Saffron City / Silph Co. (highest priority, highest complexity)
- All floor events leading up to the fork
- Rocket grunt dialogue (including the Mewtwo propaganda thread)
- Silph Co. president dialogue
- Ariana encounter (with branching based on Nugget Bridge flag)
- The fork scene itself
- Oak Path: Giovanni boss dialogue, post-defeat rage, vault scene
- Giovanni Path: Archer chase/fight, Master Ball acquisition, rival reunion
- Oak's arrival (both paths)
- Sabrina's emergence (both paths)

**This is the largest single writing task in the project.** Probably 15,000–20,000 words across all paths and encounters.

**Status:** Saffron City proper (overworld, gym, Fighting Dojo) has a dialogue JSON (`saffron_city.json` — 3 maps, 60 events). Silph Co. floors and the fork scene still need separate JSONs with heavy SPECIAL_LOGIC scripting.

### 2B. Lavender Town + Pokemon Tower
- Town NPC dialogue
- Mr. Fuji's dialogue (with knowledge boundaries)
- Pokemon Tower event rework (Rocket records destruction, Project M seed)
- Rival encounter (with positional-choice variants)
- Mr. Fuji's positional choice scene

Emotionally critical. ~5,000–8,000 words.

**Status:** Lavender Town proper has a dialogue JSON (`lavender_town.json` — 5 maps, 46 events). Pokemon Tower floors excluded (SPECIAL_LOGIC — Tier 2, Mr. Fuji choice + Project M journals need separate handling).

### 2C. Cinnabar Island + Pokemon Mansion
- Blaine's gym dialogue (both paths)
- Pokemon Mansion journal entries (the Mewtwo creation story in fragments)
- Blaine-Rocket funding connection
- Town NPC dialogue

The journals are a unique writing challenge — they need to tell a compelling story in scattered, out-of-order fragments that reward exploration. ~5,000–8,000 words.

**Status:** Dialogue JSON written (`cinnabar_island.json` — 6 maps, 21 events). Covers gym, mansion, lab, and town NPCs. Blaine framed as haunted Mewtwo project leader. Gym has insert_commands choice block (Switches 1156-1158, Var 347).

### 2D. Indigo Plateau + Endings
- Elite Four pre-battle dialogue (Agatha's Mewtwo awareness)
- Champion's Chamber (both paths — already drafted in 1B)
- Oak Path ending sequence (Pallet return, Cerulean Cave)
- Giovanni Path ending sequence (Cerulean Cave, Master Ball throw)
- Credits vignettes (switch-based city snapshots)

~5,000–8,000 words.

### 2E. Pallet Town + Pewter City + Mt. Moon
- Opening sequence, Oak's lab, rival introduction
- Pewter NPC dialogue, Brock's gym, courier scene
- Mt. Moon Rocket encounter rework

The "tutorial" section. Tonally the simplest — warm, innocent, small cracks. ~4,000–6,000 words.

### 2F. Cerulean City
- Protest NPCs, Misty's gym and positional choice
- Cerulean Cave guard (foreshadowing)
- Nugget Bridge Rocket recruiter
- Bill's house rework

~3,000–5,000 words.

### 2G. Vermilion City + S.S. Anne
- Surge's gym and militarism framing
- S.S. Anne party scene (gym leader sprites + dialogue boxes)
- City NPC dialogue

~3,000–5,000 words.

### 2H. Celadon City + Game Corner / Rocket Hideout
- Erika's gym and aristocratic corruption framing
- Game Corner / Rocket Hideout narrative rework
- City NPC dialogue

~3,000–5,000 words.

**Status:** Dialogue JSON written (`celadon_city.json` — 9 maps, 39 events). Covers gym, Game Corner, Dept Store, Route 7. Erika gym has insert_commands choice block (Switches 1147-1149, Var 344). Rocket Hideout and Sewers not yet covered.

### 2I. Fuchsia City + Safari Zone
- Koga's gym dialogue
- Safari Zone conservation angle
- Rival encounter (both paths, gated behind Saffron)
- City NPC dialogue

~2,000–4,000 words.

**Status:** Dialogue JSON written (`fuchsia_city.json` — 6 maps, 21 events). Covers city, gym, Safari Zone gate, Routes 12-13. Koga gym has insert_commands choice block (Switches 1153-1155, Var 346). Rival path-variant encounter still needs SPECIAL_LOGIC handling.

### 2J. Viridian City (return)
- Giovanni's gym (both paths — already drafted in 1C)
- City NPC dialogue reflecting post-Rocket Kanto

~2,000–3,000 words.

### 2K. Remaining routes and minor locations
- Route NPC dialogue (trainers, rangers, hikers)
- Pokemon Centers, Poke Marts (flavor text)
- Any minor locations with story-relevant NPCs

This is the long tail. Individually low priority per-NPC, but collectively it's what makes the world feel inhabited. ~10,000–15,000 words total. Can be done last and incrementally.

---

## Phase 3: Implementation
*Turning scripts into game data.*

### 3A. Implement the switch/variable system
- Add all planned switches and variables to the game project
- Test that they can be set and read correctly
- Set up any common events needed for switch management

**Who does this:** You, in RPG Maker XP, following Claude's instructions.

### 3B. Implement dialogue via injection tooling
- Use the extract/inject scripts from Phase 0C to do bulk dialogue replacement
- For each city, run the injection script with the new dialogue
- Verify in-game that text displays correctly, line breaks work, and choice branches function

**Who does this:** You run the scripts. Claude troubleshoots any formatting or encoding issues.

### 3C. Implement the fork at Silph Co.
This is the most complex single implementation task:
- Create the Archer boss fight (trainer data, team composition)
- Set up the branching event flow: shared floors → decision point → Oak Path events / Giovanni Path events → shared aftermath with switch-based variants
- Test both paths end-to-end

**Who does this:** Collaborative. Claude provides the event logic and trainer data. You implement in RPG Maker XP.

### 3D. Implement the Champion battle replacement
- Replace the default Champion with Blue
- Set up Blue's team (should mirror the rival's progression throughout the game)
- Implement path-variant pre/post battle dialogue
- Implement ending sequences for both paths

**Who does this:** Same as 3C.

### 3E. Implement the S.S. Anne party
- Duplicate gym leader sprites onto the S.S. Anne map
- Add dialogue events for each
- Connect to Bill's ticket from Cerulean

**Who does this:** You, in RPG Maker XP. Straightforward NPC placement.

### 3F. Implement Cerulean Cave postgame
- Oak Path: set up Mewtwo encounter (standard legendary battle, outcome doesn't matter, same ending scene regardless)
- Giovanni Path: set up cutscene (approach Mewtwo, Master Ball throw, fade to black)
- Both paths: credits sequence with switch-based vignettes

**Who does this:** Collaborative. Claude provides event logic, you implement.

---

## Phase 4: Testing and Polish
*Making sure it actually works.*

### 4A. Full playthrough — Oak Path
- Play through the entire game on the Oak Path
- Document every dialogue error, broken event, switch that doesn't trigger, or moment where the tone feels wrong
- Pay special attention to the fork, the vault scene, and the ending

### 4B. Full playthrough — Giovanni Path
- Same as 4A but taking the other fork
- Verify that all path-variant dialogue triggers correctly
- Check that no Oak Path text leaks into the Giovanni Path or vice versa

### 4C. Edge case testing
- What happens if you go to Fuchsia before Saffron? (Rival shouldn't be there)
- What happens if you revisit cities after the fork? (NPCs should still make sense)
- Do all positional choices actually set their switches?
- Does the Ariana branch work in both directions?

### 4D. Writing polish pass
- Reread all dialogue in-game (not in a script doc — in the actual game, with the music and pacing)
- Cut anything that feels too long
- Tighten anything that feels too vague
- Make sure Blue's voice is consistent across 10+ encounters and two paths

### 4E. Community beta
- Share with your friend and a small group of trusted players
- Collect feedback specifically on: story clarity, pacing, choice satisfaction, any bugs
- Revise based on feedback

---

## Phase 5: Release
- Write a README explaining what the mod is and how to install it
- Package as a patch or fork that players can apply to their Infinite Fusion install
- Post to relevant communities (PokeCommunity, Reddit r/PokemonInfiniteFusion, etc.)
- Credit the original Infinite Fusion team prominently

---

## Dependency Graph

```
Phase 0A (get game running)
  └→ Phase 0B (understand data structures)
      └→ Phase 0C (build extraction tooling)
          └→ Phase 3B (dialogue injection) ──────────────────────────┐
                                                                     │
Phase 1A (switch plan) ─────────────────────────────────────────────┐│
  └→ Phase 1B (Blue dialogue) ──┐                                  ││
  └→ Phase 1C (Giovanni dialogue)├→ Phase 2A–2K (city writing) ────┤│
  └→ Phase 1D (Oak dialogue) ───┘                                  ││
                                                                    ▼▼
                                                      Phase 3A–3F (implementation)
                                                              │
                                                              ▼
                                                      Phase 4 (testing)
                                                              │
                                                              ▼
                                                      Phase 5 (release)
```

**Key insight:** Phase 1 (writing the spine) and Phase 0C (building extraction tooling) can happen in parallel. Claude can be writing Blue's dialogue while you're getting the game running and testing the extraction scripts.

---

## Realistic Timeline

| Phase | Calendar Time | Notes |
|-------|--------------|-------|
| Phase 0 | 1–2 weeks | Depends on RPG Maker XP familiarity |
| Phase 1 | 2–4 weeks | Writing + review cycles |
| Phase 2 | 4–8 weeks | Largest volume of writing; can overlap with Phase 3 as cities are completed |
| Phase 3 | 2–4 weeks | Can start as soon as Phase 0C + first city scripts are ready |
| Phase 4 | 2–3 weeks | Two full playthroughs minimum |
| Phase 5 | 1 week | Packaging and release prep |

**Total: roughly 3–5 months** of active work, assuming a few hours per week of your time and ongoing collaboration with Claude for writing and scripting.

---

## What Claude Does vs. What You Do

| Task | Claude | You |
|------|--------|-----|
| Story bible and narrative design | Primary author | Reviewer and direction-setter |
| All dialogue writing | Primary author | Reviewer and editor |
| Ruby extraction/injection scripts | Author | Runner and tester |
| Event logic and switch plans | Author | Implementer in RPG Maker XP |
| Trainer data (Archer's team, Blue's teams) | Author | Implementer |
| RPG Maker XP event editing | Cannot do this | Primary |
| Sprite placement (S.S. Anne, etc.) | Cannot do this | Primary |
| Playtesting | Cannot do this | Primary |
| Bug documentation | Troubleshooter | Documenter |

---

## Immediate Next Actions

1. **You:** Buy/install RPG Maker XP. Clone the infinitefusion-e18 repo. Get the game running.
2. **Claude:** Begin drafting the switch/variable plan (Phase 1A) and Blue's dialogue track (Phase 1B). These don't require the game to be running.
3. **You (once running):** Open the project in RPG Maker XP and describe the event structure for one gym leader and one rival encounter. Claude uses this to refine the extraction tooling approach.
4. **Claude:** Write the extraction script based on your description of the data format.
5. **You:** Run the extraction script and share results. Begin the feedback loop.
