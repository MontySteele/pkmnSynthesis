# 08 — Fuchsia City, Safari Zone & Routes 12-18

**Narrative Phase:** Phase 2 (Post-Saffron if visited after the Fork; pre-Fork visit is valid but lacks the rival encounter)
**Tone:** Quiet after the storm. Contemplative. The player is processing Saffron.
**Gym Leader Archetype:** Koga — "The Pragmatist"

---

## Creative Direction (Revised)

**Tone: Direct Heat.** Fuchsia doesn't do subtlety. By this point the player has (probably) chosen their course; all Fuchsia cares about is whether they have what it takes to survive under the cost of their chosen ideals.

Key principles:
- NPCs know people who have died to wild Pokémon attacks — this is personal, not abstract
- The "strength good, hesitation bad" framework is explicit: people respect resolve, any resolve
- Koga embodies this — he doesn't care which side you're on, he cares if you're strong enough
- The Safari Zone isn't just conservation — it's a reminder that nature doesn't negotiate
- NPC dialogue should have urgency and lived experience, not philosophical musing
- Name the dead. Reference specific losses. Make the stakes visceral, not theoretical.

---

## 1. Overview

Fuchsia City is the narrative exhalation after the Silph Co. crisis. Where Saffron was dense with plot, ideology, and consequence, Fuchsia is sparse and practical. Koga doesn't care about the fusion debate. The Safari Zone raises a new dimension of the debate — ecology, not politics — through a Conservation Ranger rather than through speeches. And the rival encounter, if it fires, is a quiet, devastating check-in that recalibrates the player's relationship with Blue based on the Fork.

The surrounding routes (12-18) are long, winding, and full of fishermen and cyclists. These NPCs provide texture and world-state flavor rather than plot. A few get Synthesis-aware dialogue reflecting what the rest of Kanto is hearing about Saffron, fusion, the League, and the changing wild.

**Design principle:** This is the first area where the player can feel the weight of their Silph Co. choice reflected back at them through someone who loves them. Everything else in Fuchsia is deliberately low-pressure to make the rival scene land harder.

---

## 2. NPC Inventory

### Fuchsia City (Map 472, 481, 482)

| Event ID | Base Name | Role | Synthesis Treatment |
|----------|-----------|------|---------------------|
| 76/77 (Gary) | Rival (Blue) | Rival encounter + battle + Johto starter gift | **FULL REWRITE** — path-variant post-Saffron conversation; battle retained; Johto gift retained as-is after battle |
| 69 (Koga) | Koga (overworld) | Koga outside gym, references darkness quest | Replace with Synthesis flavor — Koga observing the Safari Zone, brief pragmatist dialogue |
| 97 (Koga_2) | Koga (overworld, quest) | Strange plants / darkness quest | **PRESERVE** — base-game quest content, no Synthesis edit needed |
| 79 (EV079) | Koga (darkness event) | Darkness / plant event chain | **PRESERVE** — base-game quest content |
| 29 (EV029) | Dodrio Pokedex NPC | Zoo flavor | Light touch: add one line about Dodrio being a "pure" species that's actually thriving |
| 30 (EV030) | Nidoqueen Pokedex NPC | Zoo flavor | Keep as-is |
| 31 (EV031) | Safari Zone sign NPC | Flavor | Light touch: "Welcome to the Safari Zone — Kanto's last refuge for unfused species." |
| 13 (EV013) | Dodrio admirer | Flavor | Keep as-is |
| 14 (EV014) | Fossil reaction | Flavor | Keep as-is |
| 15 (EV015) | Unova Pokemon NPC | Flavor | Keep as-is |
| 16 (EV016) | Fight watcher | Flavor | Keep as-is |
| 17 (EV017) | Old man / zoo | Flavor | Rewrite: "The Safari Zone used to be a hunting ground, you know. Now it's more like a hospital. These Pokemon can't compete with fused ones in the wild." |
| 42 (EV042) | Traveler with flute | Item giver | Keep as-is (mechanical) |
| 50-53, 75 (Pokedex NPCs) | Various zoo exhibits | Flavor | Keep as-is |
| 71 (EV071) | Heat Wave tutor | Move tutor | Keep as-is (mechanical) |
| 72 (Daisy) | Daisy (groomer) | Grooming service | Keep as-is (mechanical) |
| 78 (venomoth) | Koga's Venomoth | Pokemon cry | Keep as-is |
| 5 (EV005, Map 481) | Musharna / HA tracker | Hidden Ability hint NPC | Keep as-is (mechanical) |
| 5 (EV005, Map 482) | Janine | Koga's daughter, trade quest | Light touch: add one line referencing her father's attitude. "My father says a trainer who can't adapt isn't a trainer at all. That goes for me too." |

### Fuchsia City Gym (Map 479)

| Event ID | Base Name | Role | Synthesis Treatment |
|----------|-----------|------|---------------------|
| 1 (EV001) | Koga (Gym Leader) | Gym battle + post-battle Lance scene | **FULL REWRITE** of pre-battle and post-battle dialogue. Lance scene: see Section 3 below |
| 5-10 (Trainers) | Gym trainers (x6) | Pre/post battle lines | Rewrite: shift from generic ninja flair to practical philosophy matching Koga's pragmatism |
| 15 (EV015) | Gym guide | Gym hint | Light rewrite: keep mechanical hint, add flavor |

### Safari Zone Gate (Map 473, 804)

| Event ID | Base Name | Role | Synthesis Treatment |
|----------|-----------|------|---------------------|
| 5/4 (EV005/EV004) | Gate attendant | Safari entry, $500, Safari Balls | **PRESERVE** — mechanical, no change |
| 6 (EV006) | Scyther trainer NPC | Flavor | Rewrite: "I came here for rare Pokemon, but the ranger says some species are only here because they can't survive outside anymore." |
| 3 (EV003) | Greeter NPC | Flavor | Keep as-is |
| **NEW** | Conservation Ranger | **NEW EVENT** — ecological perspective on fusion | See Section 6 |

### Fuchsia Hotel (Map 477, 478)

| Event ID | Base Name | Role | Synthesis Treatment |
|----------|-----------|------|---------------------|
| 15 (EV015, Map 477) | Hotel receptionist | Rest / heal | Keep as-is (mechanical) |
| 5 (EV005, Map 477) | Salon NPC | Hair salon | Keep as-is (mechanical) |
| 12 (EV012, Map 477) | Elite Four rumor NPC | Koga / E4 rumor | Rewrite: "I heard Koga turned down the Elite Four. Said Fuchsia needed him more. Between you and me, I think he just doesn't want to answer to anyone." |
| 11 (EV011, Map 478) | Cyclist racer | Bicycle Race quest | Keep as-is (mechanical quest) |
| 6 (EV006, Map 478) | Grimer quest NPC | Cycling Road cleanup quest | Keep as-is (mechanical quest) |
| 12 (EV012, Map 478) | Carvanha quest NPC | Safari bite mystery quest | Keep as-is (mechanical quest) |
| 7 (EV007, Map 478) | Lost Chansey quest NPC | Chansey reunion quest | Keep as-is (mechanical quest) |

### Routes 12-18 (Maps 159, 437, 438, 440, 444, 146, 517)

These routes contain approximately 95 text-bearing events, primarily trainers (fishermen, bird keepers, bikers, swimmers, couples). Most have generic battle banter.

**Synthesis treatment:** Select 8-12 NPCs across the routes for light Synthesis-flavored rewrites. The rest keep vanilla dialogue.

| Route | NPC Type to Rewrite | Theme |
|-------|---------------------|-------|
| Route 12 | Fisherman (Event 29) | "The fish are changing. Used to be all Magikarp and Goldeen. Now I'm pulling up things I don't have names for. Fused things." |
| Route 12 | Jasmine (Event 6) | **PRESERVE** — her dialogue about Snorlax/Strength/Koga already fits Synthesis tone perfectly |
| Route 13 | Swimmer (Event 5) | Already references cross-region fusion curiosity — keep as-is, it fits |
| Route 13 | Biker (Event 11) | Light rewrite: "Used to be more of us out here. People don't travel much anymore. Say the routes aren't safe." |
| Route 14 | Bird Keeper | "My Pidgeot won't fuse. I've had offers. Good ones, too. But she's been with me since I was ten. What kind of person would I be?" |
| Route 15 | Hiker or NPC near Fuchsia gate | "Koga keeps these routes clear himself when the Rangers can't be bothered. Say what you want about the man — he shows up." |
| Route 16 | Biker (cycling road entrance) | "Saffron's a mess. Heard Team Rocket had the whole city locked down. League finally did something about it, but still." |
| Route 17 | Cycling road bikers (select 2-3) | Mix of post-Saffron gossip and route life. One references Grimers getting worse. |
| Route 18 | Trainer near Fuchsia entrance | "You coming from Celadon? How's the city? We don't get much news out here." |

---

## 3. Dialogue Direction

### Koga — Gym Battle

**Pre-battle:**
Koga drops the "ninja master" theatrics of the base game. He is direct, practical, and briefly philosophical in a grounded way. He acknowledges the player has been through something if Saffron is complete (check `SYNTH_SILPH_COMPLETE`).

**Key lines (direction, not final dialogue):**
- If Saffron complete: "I heard what happened in Saffron. The whole region heard. You were there. Good. That means you already know that ideology doesn't stop a fist." Then, pivoting: "Out here, there's no debate. The routes are dangerous, the wild Pokemon are getting stronger, and the only thing that matters is whether you can protect the people who depend on you. Everything else is talk."
- If Saffron NOT complete: Simpler version. "You've come a long way to reach Fuchsia. That tells me you're either very strong or very stubborn. Let's find out which."
- Pre-battle: "We'll use four Pokemon. I won't hold back. If you can't handle poison, you can't handle anything these routes throw at you."

**Post-battle:**
- Awards Soul Badge and TM06 (Toxic). Mechanical lines preserved.
- Koga's respect line: "You've earned this. The Soul Badge, the ability to use Strength outside of battle — these aren't gifts, they're acknowledgments. You can handle yourself. That's the only credential I recognize."
- Brief Koga philosophy closer: "A piece of advice, free of charge. Everyone in Kanto wants to tell you what to believe. Ignore them. Watch what they do. That's what matters."

**Lance scene (post-gym):**
The base game has Lance appear after the Koga fight to deliver the Silph Co. hook (Team Rocket captured legendary birds, please come to Saffron). This scene is **conditionally modified**:
- If `SYNTH_SILPH_COMPLETE` is ON: Lance does NOT appear (Saffron is already resolved). Koga simply gives the badge and the player leaves.
- If `SYNTH_SILPH_COMPLETE` is OFF: Lance appears, but his dialogue is rewritten to fit Synthesis framing. He references the Silph Co. crisis in terms of "the League is losing control of the situation" rather than pure heroics. Koga's reaction is pragmatic: "If the League can't handle this, I'll send Rangers. But you — you might be more useful than Rangers." This preserves the mechanical hook (directing the player to Saffron) while fitting Synthesis tone.

### Gym Trainers

Replace "ninja mystique" lines with practical philosophy:
- "Koga taught us that the strongest technique is the one your opponent doesn't expect. That's not poetry — it's math."
- "I joined this gym because Koga doesn't care where you come from. He only cares if you can fight."
- "People in Saffron argue about who should control fusion. People out here argue about whether their Antidotes will last until the next town."

### City NPCs

General direction: Fuchsia City is remote and self-sufficient. NPCs reflect this with a mild isolationist pride. They're aware of the wider debates but consider them distant problems. A few reference Saffron if `SYNTH_SILPH_COMPLETE` is ON.

- Zoo/exhibit NPCs: mostly keep vanilla Pokedex flavor. The old man at the zoo gets a Synthesis line (see NPC inventory).
- Safari Zone sign: brief conservation framing.
- Hotel NPCs: one rumor about Koga and the Elite Four (see inventory), rest stay mechanical.
- Janine: one additional line reflecting Koga's pragmatist values (see inventory).

### Safari Zone — Conservation Ranger (NEW)

See Section 6 for full details. This is the primary new narrative content in the Safari Zone.

### Rival Encounter — Blue (Encounter 9)

This encounter is the emotional core of the Fuchsia section. It fires ONLY if `SYNTH_SILPH_COMPLETE` (Switch 1152) is ON. If the player reaches Fuchsia before completing Silph Co., the rival simply is not present on the map.

The encounter uses the existing rival event slots (Events 76/77 on Map 472). The battle and Johto starter gift are preserved mechanically. The pre-battle and post-battle dialogue are completely rewritten with two variants.

**Existing Blue dialogue track (from `/docs/blue_dialogue_track.md`, Encounter 9) is the canonical source.** The city plan defers to that document for final line-by-line dialogue. Summary of each variant:

**Oak Path** (`SYNTH_FORK_CHOSEN` ON, `SYNTH_GIOVANNI_PATH` OFF):
- Blue is strained but not hostile. He has the Master Ball. He talks about Saffron and Oak's revelation about Mewtwo.
- Core beat: Blue has lost faith in the League's strategy of hope and secrecy. He doesn't trust Oak. He's pulling toward action — not Giovanni's ideology, but a rejection of inaction. "Fifteen years. He had fifteen years and his plan was hope."
- He announces he's heading for the Plateau to "earn the right to make this call."
- No player choice here (choices are reserved for Victory Road). The scene is Blue telling the player what he's decided.

**Giovanni Path** (`SYNTH_FORK_CHOSEN` ON, `SYNTH_GIOVANNI_PATH` ON):
- Blue is wary of the player. He references what he saw after defeating Giovanni — the wreckage of a man who couldn't stop, still arguing, still certain.
- Core beat: Blue sees the same pattern in the player. "You grabbed the Ball instead of fighting him. I need you to tell me that's not the same thing."
- He's not hostile — he loves the player — but he's watching them the way you'd watch someone near a cliff edge.
- He announces he's heading for the Plateau because he "needs to be strong enough. Just in case."

**Post-battle:** In both variants, the battle proceeds. After the battle, Blue gives the Johto starter gift (Chikorita/Cyndaquil/Totodile choice preserved as-is). This mundane gesture after the heavy conversation is intentional — it's Blue being your friend even when he's scared. Then he leaves.

---

## 4. Player Choices

Fuchsia City introduces **no new positional or fork choices**. This is deliberate. The player made their defining choice in Saffron. Fuchsia is where they sit with the consequences.

The only interactive choice is the Johto starter selection (Chikorita / Cyndaquil / Totodile), which is a mechanical/flavor choice with no narrative weight.

**Downstream references:** The Conservation Ranger's dialogue may lightly vary based on `SYNTH_FUJI_*` switches (the player's Lavender Town stance on fusion). If the player told Fuji that fusion should be banned (`SYNTH_FUJI_BAN`), the ranger acknowledges that perspective. If the player said fusion should be free (`SYNTH_FUJI_FREE`), the ranger gently pushes back with ecological evidence. These are flavor variations, not branching content — the ranger's core message (fusion is disrupting ecosystems) is the same regardless.

---

## 5. Mechanical Info to Preserve

These gameplay-critical elements must remain functional. Dialogue around them can be lightly reframed but mechanical triggers, item grants, and event flow must be identical to vanilla.

| Mechanic | Location | Notes |
|----------|----------|-------|
| **Soul Badge** | Fuchsia Gym (Map 479, Event 1) | Grants Strength HM use outside battle. Badge award sequence preserved. |
| **TM06 (Toxic)** | Fuchsia Gym (Map 479, Event 1) | Given by Koga post-battle. Keep. |
| **Strength HM** | Unlocked by Soul Badge | Badge unlock — no event change needed. |
| **Surf HM** | Safari Zone (not in gate dialogue — obtained inside the Zone) | Preserve Safari Zone interior item placement. |
| **Safari Zone entry** | Safari Zone Gate (Map 473, Events 4/5) | $500 fee, 30 Safari Balls, timer. Entirely mechanical — no Synthesis rewrite. |
| **Safari Zone darkness/plant quest** | Map 472 (Events 97, 79, 41), Map 804 | Base-game quest chain involving strange plants, prisms, Koga. Preserve entirely. |
| **Snorlax encounters** | Route 12 (Events 5, 7, 8, 9, 10, 11, 12, 14, 15) | PokeFlute wake mechanic. Preserve entirely. |
| **Jasmine / Snorlax event** | Route 12 (Event 6) | Jasmine helps clear Snorlax, references Koga. Preserve — already fits Synthesis. |
| **Johto starter gift** | Map 472 (Events 76/77) | Chikorita/Cyndaquil/Totodile choice. Preserve choice flow and item grants. |
| **Daisy grooming** | Map 472 (Event 72) | Friendship grooming service. Preserve. |
| **Hidden Ability tracker** | Map 481 (Event 5) | Musharna/HA hint NPC. Preserve. |
| **Janine trade (Golbat for Gligar)** | Map 482 (Event 5) | Trade quest. Preserve mechanical flow, light Synthesis flavor on surrounding lines. |
| **Bicycle Race quest** | Map 478 (Events 10/11) | Racing Bicycle upgrade. Preserve entirely. |
| **Grimer cleanup quest** | Map 478 (Event 6) | Cycling Road quest. Preserve entirely. |
| **Lost Chansey quest** | Map 478 (Event 7/8) | Reunion quest. Preserve entirely. |
| **Hair salon** | Map 477 (Events 5, 16) | Cosmetic. Preserve. |
| **Hotel rest** | Map 477 (Event 15) | Heal/rest. Preserve. |
| **Move tutors** | Map 472 (Event 71 — Heat Wave) | Preserve. |
| **Lance post-gym hook** | Map 479 (Event 1, post-battle) | Conditionally fires only if `SYNTH_SILPH_COMPLETE` is OFF. See Section 3. |
| **Fishing** | Routes 12-13, Safari Zone | Rod usage, fisherman trainers. No mechanical changes. |
| **Premium Wonder Trade tickets** | Map 479 (Event 1) | 2 tickets post-Koga. Preserve. |

---

## 6. New Events

### Conservation Ranger — Safari Zone Gate (Map 473)

**New event** placed in the Safari Zone Gate building (Map 473). One NPC, non-blocking, positioned near the existing greeter.

**Role:** Introduces the ecological angle on fusion — a perspective no other city has raised. This isn't about politics or power; it's about what fusion does to the natural world when fused Pokemon enter wild ecosystems.

**Dialogue direction:**
- The ranger identifies themselves as a Safari Zone warden. They've been working here for years, monitoring wildlife populations.
- Core message: fused Pokemon outcompete natural species in the wild. The Safari Zone exists because it's one of the few places where unfused Pokemon can survive without competition from hybrids. Species that were common ten years ago — Kangaskhan, Chansey, Tauros, Scyther — are now rare in the wild because fused Pokemon are faster, stronger, and more adaptable.
- The ranger is not anti-fusion per se. They're just reporting what they see: "I'm not a politician. I count populations. And the numbers are going down."
- If `SYNTH_FUJI_BAN` is ON: "You think fusion should be banned? I understand that impulse. But even if you stopped all new fusions tomorrow, the fused Pokemon already in the wild aren't going away. This is a problem that's bigger than regulation."
- If `SYNTH_FUJI_FREE` is ON: "You think everyone should have access to fusion? Maybe. But every trainer who fuses a Pokemon and then releases it — or loses it — adds another competitor to an ecosystem that's already struggling. Freedom has a cost that nobody's counting."
- If `SYNTH_FUJI_OVERSIGHT` or `SYNTH_FUJI_UNSURE` or none set: Default version without callback. Just the ecological data.
- Closing line: "Come into the Zone and look around. These Pokemon aren't rare because they're special. They're rare because we made something that's better at surviving than they are."

**Estimated word count:** 120-180 words depending on variant.

**Switch/variable requirements:** Reads `SYNTH_FUJI_BAN` (1135), `SYNTH_FUJI_FREE` (1136). Does not set any new switches.

---

## 7. Special Logic Flags

### Required Switches (Read)

| Switch | Used For |
|--------|----------|
| `SYNTH_FORK_CHOSEN` (1130) | Gates rival encounter. If OFF, rival is absent from Fuchsia. |
| `SYNTH_GIOVANNI_PATH` (1131) | Determines rival dialogue variant. 1130 ON + 1131 OFF = Oak Path. 1130 ON + 1131 ON = Giovanni Path. |
| `SYNTH_SILPH_COMPLETE` (1152) | Gates rival encounter (must be ON). Also gates Koga's post-Saffron gym dialogue variant and suppresses Lance's post-gym appearance. |
| `SYNTH_FUJI_BAN` (1135) | Conservation Ranger variant line |
| `SYNTH_FUJI_FREE` (1136) | Conservation Ranger variant line |
| `SYNTH_FUJI_OVERSIGHT` (1137) | Conservation Ranger fallback check |
| `SYNTH_FUJI_UNSURE` (1138) | Conservation Ranger fallback check |

### New Switches (Set)

| Proposed ID | Name | Set Where | Description |
|-------------|------|-----------|-------------|
| Switch 1160 | `SYNTH_FUCHSIA_RIVAL_SEEN` | Fuchsia City (Map 472) | ON after the rival encounter completes. Prevents repeat firing. Also used downstream to confirm the player has had the post-Fork check-in before Victory Road. |

**Note:** Switch 1160 is within the reserved range (1158-1175) documented in the switch/variable plan. This is its first allocation.

### Conditional Logic Summary

```
Rival Encounter (Map 472, Events 76/77):
  IF SYNTH_SILPH_COMPLETE (1152) == ON
    AND SYNTH_FUCHSIA_RIVAL_SEEN (1160) == OFF
  THEN:
    IF SYNTH_GIOVANNI_PATH (1131) == ON
      → Giovanni Path rival dialogue
    ELSE
      → Oak Path rival dialogue
    → Battle
    → Johto starter gift
    → Set SYNTH_FUCHSIA_RIVAL_SEEN (1160) = ON

Koga Pre-Battle (Map 479, Event 1):
  IF SYNTH_SILPH_COMPLETE (1152) == ON
    → Post-Saffron variant (references Saffron, longer)
  ELSE
    → Default variant (shorter, no Saffron reference)

Lance Post-Gym Scene (Map 479, Event 1):
  IF SYNTH_SILPH_COMPLETE (1152) == OFF
    → Lance appears, rewritten Synthesis dialogue, directs player to Saffron
  ELSE
    → Scene does not fire

Conservation Ranger (Map 473, NEW):
  IF SYNTH_FUJI_BAN (1135) == ON → Ban variant line
  ELIF SYNTH_FUJI_FREE (1136) == ON → Free variant line
  ELSE → Default (no callback)
```

---

## 8. Word Count Estimate

| Section | Events | Est. Words |
|---------|--------|------------|
| Koga gym (pre-battle, 2 variants) | 1 | 250 |
| Koga gym (post-battle) | 1 | 120 |
| Koga gym trainers (6 trainers, pre+post) | 6 | 300 |
| Gym guide | 1 | 40 |
| Lance post-gym (rewrite, 1 variant) | 1 | 180 |
| Rival encounter — Oak Path | 1 | 200 (defers to blue_dialogue_track.md) |
| Rival encounter — Giovanni Path | 1 | 200 (defers to blue_dialogue_track.md) |
| Conservation Ranger (3 variants) | 1 | 180 |
| City NPCs (rewrites, ~6 NPCs) | 6 | 250 |
| Safari Zone Gate NPC rewrites (~2) | 2 | 60 |
| Janine addition | 1 | 30 |
| Route NPCs (8-12 rewrites) | 10 | 400 |
| **Total new/rewritten Synthesis words** | | **~2,210** |

This is a light-to-moderate implementation. The rival encounter dialogue is already drafted in `blue_dialogue_track.md` and needs only event scripting. The heaviest original writing is Koga's gym dialogue and the Conservation Ranger.

---

## Appendix: Maps Covered

| Map ID | Name | Text Events | Synthesis Work |
|--------|------|-------------|----------------|
| 472 | Fuchsia City (main) | 24 | Heavy (rival, city NPCs) |
| 479 | Fuchsia City Gym | 8 | Heavy (Koga, trainers, Lance) |
| 473 | Safari Zone Gate | 7 | Moderate (ranger, gate NPC) |
| 477 | Fuchsia Hotel (lobby) | 6 | Light (1 NPC rewrite) |
| 478 | Fuchsia Hotel (quests) | 8 | None (mechanical quests) |
| 481 | Fuchsia City (HA house) | 3 | None (mechanical) |
| 482 | Fuchsia City (Janine) | 5 | Light (1 line addition) |
| 804 | Safari Zone Gate (dark) | 2 | None (base quest) |
| 44 | Fuchsia City -old | 8 | None (legacy map, likely unused) |
| 87 | Fuchsia City (alt) | 6 | None (alt map, mirrors 472) |
| 159 | Route 12 | 22 | Light (2-3 NPC rewrites) |
| 437 | Route 13 | 24 | Light (1-2 NPC rewrites) |
| 438 | Route 16 | 6 | Light (1 NPC rewrite) |
| 440 | Route 14 | 8 | Light (1 NPC rewrite) |
| 444 | Route 15 | 14 | Light (1-2 NPC rewrites) |
| 146 | Route 17 | 17 | Light (2-3 NPC rewrites) |
| 517 | Route 18 | 23 | Light (1-2 NPC rewrites) |
