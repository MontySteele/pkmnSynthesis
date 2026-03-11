# Endgame Areas — Narrative Plan
## Viridian City (Return), Victory Road, Indigo Plateau

---

## Creative Direction (Revised)

**Rival Demands the Fight.** If the player chooses to trust the rival (Oak path), the rival should DEMAND a fight anyway. The logic: "If I can't beat you, then I can't beat Mewtwo." This isn't ego — it's pragmatic self-assessment.

Key principles:
- The rival fight isn't optional — even mutual trust requires proof of strength
- The rival's demand reframes the Champion battle as a calibration, not a competition
- Dialogue should feel emotionally high-stakes: "Don't hold back. If you hold back, we both lose."
- The Giovanni path rival fight should feel more desperate — trying to stop you, not test you
- Second pass needed for tone, characterization, and emotional impact throughout endgame
- Current endgame dialogue feels "a little lackluster" — needs sharper emotional beats

---

## Area A: Viridian City (Return) — "The Empty Throne"

### 1. Overview

The player returns to Viridian City with seven badges to find Giovanni's gym finally open. But "open" is generous. Team Rocket is dismantled. Giovanni is a man sitting in a room with nothing left but his certainty. The gym battle is the eighth badge, but it should feel nothing like a triumph. It should feel like visiting someone in prison.

**Tone:** Ugly, claustrophobic, bitter. The gym trainers are demoralized loyalists. Giovanni has NOT learned anything. He is not reformed, not reflective, not offering wisdom. He is furious, self-righteous, and constitutionally incapable of accepting fault.

The city itself reflects the post-Rocket collapse. NPCs reference the fallout. The gym guide is shaken. This is the last gym, but the story has already moved past it.

### 2. NPC Inventory

#### Viridian City (Overworld) — Maps 79, 83, 84, 710, 711, 746

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Map 79, Ev16 (Gym Door Guard) | "Gym Leader is out of town" / post-badge states | Post-Rocket: gym is open but hollow. Comments on state of things. |
| Map 79, Ev29 (Aspiring Trainer) | "I tried going to the League..." | Reflects on what badges mean now that the system is shaking. |
| Map 79, Ev7 (Fusion NPC) | "Fusing Pokemon is a lot of fun!" | Wonders aloud whether fusion was worth everything that happened. |
| Map 79, Ev35 (Gym Sign) | "Viridian City Gym / Gym Leader: Giovanni" | Can remain as-is or add a vandalized note: someone scratched "TRAITOR" under Giovanni's name. |
| Map 710/711 (interior NPCs) | Various house NPCs | Rewrites reflecting post-Rocket Viridian. Citizens processing what it means that their Gym Leader was the Rocket boss. |

#### Viridian City Gym — Map 85

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev40 (Gym Guide) | "Yo! Champ in making!" / reveals Giovanni | Shaken. Knows who Giovanni is now. Warns the player this isn't a normal gym fight. Post-badge: stunned silence, then "I don't know what I expected." |
| Ev33 (Trainer) | "Our Leader is back!" | Loyalist. "He gave us purpose. Say what you want about the rest of it." |
| Ev38 (Trainer) | "Working myself into a rage!" | Quiet rage. Not theatrical anymore. Fighting because there's nothing else. |
| Ev34, 35, 31, 32, 37, 15 (Trainers) | Various boasts/post-loss lines | Rewrite as demoralized Rocket remnants or disillusioned gym trainers. They know the gym is finished after this. |
| Ev92 (Giovanni) | Boss fight + Earth Badge + TM26 | **Complete rewrite. Two path variants. See Dialogue Direction below.** |

### 3. Dialogue Direction — Giovanni (Event 92, Map 85)

Giovanni's dialogue is the centerpiece. One event, two complete tracks driven by `SYNTH_GIOVANNI_PATH` (Switch 1131).

#### Pre-Battle: Oak Path (Switch 1131 OFF)

Giovanni recognizes the player as Oak's protege. Sneering contempt. He sees the player as the system's enforcer — someone who chose to protect the people who built a god in a basement.

Key beats:
- "You. The League's good little soldier."
- References Oak, Mewtwo, the hypocrisy of the system the player defended.
- "How does it feel, knowing you protected the people who built a god in a basement?"
- Fights with bitter intensity. This is his last stand.

#### Pre-Battle: Giovanni Path (Switch 1131 ON)

Giovanni's reaction is volatile — fury, envy, grudging recognition. The player took the Master Ball. HIS Ball. The thing he spent years working toward.

Key beats:
- "You. You went for the Ball. MY Ball."
- Almost laughing, but it's ugly. He sees the player as a mirror he can't look away from.
- "You're going to tell yourself you're different from me."
- Fights with everything he has left.

#### Post-Battle: Oak Path

Giovanni directs his last words PAST the player, toward the absent rival:
- "Your friend has the Ball. Good. At least someone has the spine to do what needs to be done."
- "I hope they succeed where I couldn't — and I hope you choke on the world you chose to protect."
- He leaves with contempt, not dignity.

#### Post-Battle: Giovanni Path

Pure spite, but he doesn't leave. He sits down. He's done.
- "Go on, then. Open the cave. Catch the god. Rule the world."
- "And when it all falls apart — because it WILL — don't you dare pretend you weren't warned."
- He doesn't exit the map. He stays seated. He's finished.

#### Mechanical Preservation

- Earth Badge awarded in both paths (required for League entry).
- TM26 (Earthquake) given in both paths.
- Badge count check proceeds normally.
- Premium Wonder Trade tickets from base game: REMOVE. Replace with nothing or a thematically appropriate item.

### 4. Player Choices & Switches — Viridian Gym

**No new player choices in this section.** Giovanni's dialogue varies by the existing path switch, but the player does not make a new choice here. The gym fight is mandatory and the badge is mandatory.

Switches READ:
- `SYNTH_FORK_CHOSEN` (1130) — must be ON (player has completed Silph Co.)
- `SYNTH_GIOVANNI_PATH` (1131) — determines Giovanni's dialogue track

Switches SET:
- None new. Base game badge switch (Switch 11) set on Giovanni defeat, as in vanilla.

### 5. Mechanical Info to Preserve

- Gym puzzle (spinning tiles) remains unchanged.
- All 8 gym trainers remain as battles. Their dialogue changes but their teams do not.
- Giovanni's team remains unchanged mechanically.
- Earth Badge + TM26 awarded after defeat.
- Badge count gates Victory Road / Route 23 access.
- Post-defeat, Giovanni's event switches to defeated page (self_switch A or switch1_id 11 as in base game).

### 6. New Events

- **Giovanni stays (Giovanni Path only).** After defeat on the Giovanni Path, Giovanni does not leave the gym. His post-defeat page shows him seated, silent, or with a single bitter line if re-approached: "Still here. What did you expect — an apology?" On the Oak Path, he exits as in vanilla (gym is empty after badge).
- **Gym Guide post-battle reaction.** Event 40 gets a new post-badge page reflecting what just happened.

### 7. Special Logic Flags

```
EVENT: Giovanni (Ev92, Map 85)
  PAGE 0 (pre-battle, Oak Path):
    Condition: SYNTH_FORK_CHOSEN (1130) ON, SYNTH_GIOVANNI_PATH (1131) OFF
    → Oak Path pre-battle dialogue
    → Battle (unchanged team)
    → Oak Path post-battle dialogue
    → Award Earth Badge, TM26
    → Giovanni exits (set self_switch A)

  PAGE 1 (pre-battle, Giovanni Path):
    Condition: SYNTH_FORK_CHOSEN (1130) ON, SYNTH_GIOVANNI_PATH (1131) ON
    → Giovanni Path pre-battle dialogue
    → Battle (unchanged team)
    → Giovanni Path post-battle dialogue
    → Award Earth Badge, TM26
    → Set self_switch A (but Giovanni stays on map — see Page 3)

  PAGE 2 (post-defeat, Oak Path):
    Condition: self_switch A, SYNTH_GIOVANNI_PATH (1131) OFF
    → Giovanni has left. Gym is empty. (Vanilla behavior.)

  PAGE 3 (post-defeat, Giovanni Path):
    Condition: self_switch A, SYNTH_GIOVANNI_PATH (1131) ON
    → Giovanni is seated. One line if re-approached.

NOTE: This can be simplified to a single pre-battle page with
a Conditional Branch on Switch 1131 inside the event commands,
rather than separate pages. Two text blocks, one battle call,
one branch. The post-defeat split still needs two pages (he
leaves on Oak Path, stays on Giovanni Path).
```

**Simplification note:** The gym trainers do NOT need page-level path branching. Their dialogue is the same on both paths (they are demoralized regardless). Simple text rewrites on existing pages. No switch logic needed for trainers.

---

## Area B: Victory Road — "The Last Conversation"

### 1. Overview

Victory Road is the last time the player and rival speak before the Championship. The rival is waiting partway through. They are calm, determined, and kind — but the substance is completely different depending on the path.

**Tone:** Tense, emotional, calm before the storm. Not angry. A farewell.

The dungeon itself (Maps 304, 306, 307) has regular trainers with minor dialogue rewrites. The narrative weight is entirely on the rival encounter event and the player choice that follows.

### 2. NPC Inventory

#### Route 22 — Map 171

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Various badge-check guards | Check badge count, let player pass | Rewrite as Rangers or League officials. Brief thematic lines. "You've earned the right. Whether you've earned what comes after... that's between you and the mountain." |
| Rival encounter (if present) | Early-game rival fight on Route 22 | This is the EARLY GAME encounter. No changes needed for endgame — the player has already passed through Route 22 long ago. |

#### Route 23 — Map 143

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Badge-check guards (16 text events) | Sequential badge verification NPCs | Rewrite as checkpoint Rangers. Each can have a brief line reflecting the state of things. They've heard rumors. The League is unsettled. Keep these SHORT — the player is pushing through, not stopping for conversation. |

#### Victory Road — Maps 304, 306, 307

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Map 306 trainers (Ev16, 22, 18, 13, etc.) | Standard trainer battles + boasts | Rewrite as serious, veteran trainers. They're here because they believe in the League. Brief pre-battle lines reflecting determination. Post-battle: respect. |
| Map 307 trainers (similar) | Standard trainer battles | Same treatment. These are the strongest trainers outside the E4. |
| **Rival event (NEW)** | Does not exist in base game | **New event placed in Map 306 or 307. The Last Conversation. See Dialogue Direction below.** |

### 3. Dialogue Direction — Rival (Victory Road)

One new event. Two complete dialogue tracks. A player choice in each. Then a battle. This is the emotional climax before the final dungeon.

#### Oak Path (Switch 1131 OFF)

The rival has the Master Ball. They show it openly. No deception.

**Rival's plan:** Become Champion. Reform the League. Deal with Mewtwo honestly. Not Oak's way (hiding). Not Giovanni's way (conquering). A third way.

Key dialogue beats:
- Rival shows the Master Ball. Calm explanation of what they intend.
- "The difference between me and Giovanni is that I'm asking you to stop me if I'm wrong. He never did that."
- "If you make it to the Plateau, and you still think I shouldn't have this — come take it from me. That's how we'll know which of us is right."
- Addresses player with love. This is their best friend. They know what they're asking.

**Player choice (MAJOR):**

| Option | Emotional Register | Switch Set |
|--------|-------------------|------------|
| "I trust you." | Faith. The player believes the rival can do this. | `SYNTH_VROAD_TRUST` (1147) ON |
| "I'll come take it." | Challenge. The player disagrees but respects the rival. | `SYNTH_VROAD_CHALLENGE` (1148) ON |
| "You sound like him." | Fear. The player sees Giovanni's certainty in the rival. | `SYNTH_VROAD_MIRROR` (1149) ON |
| "There has to be another way." | Doubt. The player doesn't know the answer. | None set (default / no flag) |

**Rival response:** Listens with love and sadness regardless of choice. Goes ahead anyway. Then: battle. Not angry. Fierce. The strongest they've ever been. It feels like a goodbye.

#### Giovanni Path (Switch 1131 ON)

The rival does NOT have the Master Ball — the player does. The rival's plan: become Champion specifically to have the authority to stop the player from reaching Cerulean Cave.

Key dialogue beats:
- "I love you. You know that."
- References watching Giovanni after defeat: "He sat there in the wreckage of everything he'd built, and he was still certain."
- "And then I watched you walk toward me holding that Ball, and you had the exact same look on your face."
- The rival's voice breaks. This is not a threat. It's grief.

**Player choice (MAJOR):**

| Option | Emotional Register | Switch Set |
|--------|-------------------|------------|
| "Maybe you're right — but I need to try." | Conflicted. The player hears the rival but can't stop. | `SYNTH_VROAD_TRUST` (1147) ON |
| "You can't stop me." | Defiance. The player has made their choice. | `SYNTH_VROAD_CHALLENGE` (1148) ON |
| "This is different and you know it." | Justification. The player rejects the Giovanni comparison. | `SYNTH_VROAD_MIRROR` (1149) ON |
| "Then I guess I'll have to go through you." | Cold resolve. The darkest option. | None set (default) |

**Rival response:** Nods. They expected this. "Then I'll be waiting." Battle follows. Same fight mechanically. The framing is opposite.

### 4. Player Choices & Switches — Victory Road

**New choice:** Victory Road rival response.

Switches READ:
- `SYNTH_FORK_CHOSEN` (1130) — ON
- `SYNTH_GIOVANNI_PATH` (1131) — determines which conversation plays

Switches SET:
- `SYNTH_VROAD_TRUST` (1147) — Option 1 in either path
- `SYNTH_VROAD_CHALLENGE` (1148) — Option 2 in either path
- `SYNTH_VROAD_MIRROR` (1149) — Option 3 in either path
- Option 4 sets no switch (the "uncertain" default)

Variable SET:
- `SYNTH_VROAD_CHOICE` (Variable 344) — 1, 2, 3, or 4

**Note on Variable 344:** The switch plan says this variable "varies by path." The choice options differ in wording between Oak and Giovanni paths, but map to the same switch IDs (1147/1148/1149). The variable value (1-4) is consistent across both paths. This is clean — no extra branching needed downstream.

### 5. Mechanical Info to Preserve

- Victory Road dungeon puzzle (strength boulders) unchanged.
- All existing trainer battles in Maps 306/307 remain. Dialogue rewrites only.
- Route 23 badge-check gates remain functional. No mechanical changes.
- Rival battle team: identical in both paths. Should be the rival's strongest team short of the Champion fight.
- After the rival battle, the rival leaves Victory Road (exits toward Indigo Plateau). Player continues the dungeon.

### 6. New Events

- **Rival encounter event (Map 306 or 307).** One new event placed partway through Victory Road. Triggers on player approach (touch trigger or autorun with position check). After dialogue + battle, rival exits. Event sets self_switch A to prevent re-trigger.
- **No other new events.** Route 22 and Route 23 are text rewrites only.

### 7. Special Logic Flags

```
EVENT: Rival (new event, Map 306 or 307)
  PAGE 0 (The Last Conversation):
    Condition: SYNTH_FORK_CHOSEN (1130) ON
    Trigger: Player Touch or Autorun

    → Conditional Branch: SYNTH_GIOVANNI_PATH (1131)
      OFF (Oak Path):
        → Oak Path dialogue (rival shows Master Ball, explains plan)
        → Show Choices: 4 options
          → Branch by choice: set Switch 1147/1148/1149 + Variable 344
        → Rival response text (can branch on choice for flavor,
           but converges to same outcome)
        → Battle (rival team — same in both paths)
        → Post-battle: rival departs toward Indigo Plateau
      ON (Giovanni Path):
        → Giovanni Path dialogue (rival confronts player about the Ball)
        → Show Choices: 4 options
          → Branch by choice: set Switch 1147/1148/1149 + Variable 344
        → Rival response text
        → Battle (same team)
        → Post-battle: rival departs — "I'll be waiting."
    → Set self_switch A

  PAGE 1 (post-encounter):
    Condition: self_switch A
    → Empty / rival is gone.

SIMPLIFICATION NOTE: The choice-response dialogue can be handled
with a single Conditional Branch on Variable 344 rather than
nested switch checks. Four short text variations per path,
then convergence to the battle call. Total: one Conditional Branch
for path (1131), one for choice (Var 344). No deep nesting needed.
```

---

## Area C: Indigo Plateau — "The Question"

### 1. Overview

The Indigo Plateau is the endgame gauntlet: four Elite Four battles, then the Champion's Chamber. In Synthesis, the rival is the Champion in both paths. The Elite Four get brief pre-battle dialogue reflecting the story's themes. Lance gets path-variant dialogue. The Champion fight is mechanically identical in both paths but narratively opposite.

After the Champion is defeated, the endings diverge completely.

**Tone:** Epic, bittersweet, unresolved. The Elite Four are monuments. The Champion fight is personal.

### 2. NPC Inventory

#### Indigo Plateau Lobby — Map 303

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev (lobby NPC, 1 text event) | Standard "Welcome to the Pokemon League" | Rewrite: somber. "The League has stood for generations. Whatever happens past those doors... it won't be the same." |

#### Elite 1 (Lorelei) — Map 315

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev (Lorelei, 3 text events) | Standard boss dialogue | **Rewrite pre-battle.** True believer who has grown disillusioned. "I hope you know what you're fighting for. I used to." Post-battle and rematch pages: adjust tone. |

#### Elite 2 (Bruno) — Map 316

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev (Bruno, 3 text events) | Standard boss dialogue | **Rewrite pre-battle.** Simple honor. "I fight because I swore to. I keep my oaths. Do you have something worth swearing to?" Post-battle: respect. |

#### Elite 3 (Agatha) — Map 317

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev (Agatha, 4 text events) | Standard boss dialogue | **Rewrite pre-battle. Critical character.** Agatha KNOWS about Mewtwo. She was present for the early fusion research. "Samuel's chickens coming home to roost. I told him, thirty years ago. I told him what would happen if he played god." Ancient, furious clarity. "He didn't listen. None of you ever listen." Post-battle: no comfort. |

#### Elite 4 (Lance) — Map 318

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev (Lance, 3 text events) | Standard boss dialogue | **Rewrite pre-battle. Path-variant.** See Dialogue Direction below. |

#### Champion's Chamber — Map 328

| Event | Base Game Role | Synthesis Role |
|-------|---------------|----------------|
| Ev2 (Blue) | Champion Blue — pre-battle boasts, battle, Oak arrives after | **Complete rewrite. Rival replaces Blue. Two full dialogue tracks. See Dialogue Direction below.** |
| Ev5 (Door lock) | "It's locked. You must defeat the League Champion first." | Can remain as-is. Functional gate. |
| Other events (Oak arrival, Hall of Fame, etc.) | Post-victory cutscene | **Rewrite for endings. See Endings section below.** |

### 3. Dialogue Direction

#### Lorelei (Map 315)

Pre-battle. No path variant. She's a true believer watching the institution she loves crack.

- "So you're the one everyone's been talking about."
- "I joined the Elite Four because I believed in what we stood for. Protection. Order. A world where strength served people instead of ruling them."
- "I still believe in that. I'm less certain we ever achieved it."
- "Show me you're fighting for something real."

Post-battle:
- "You're strong enough. Whether you're wise enough... I suppose we'll find out."

#### Bruno (Map 316)

Pre-battle. No path variant. Simple, honorable, direct.

- "I don't understand politics. I never have."
- "I fight because I swore an oath to the League. I keep my oaths."
- "But an oath is only as good as what you swear it to."
- "Do you have something worth swearing to? Show me."

Post-battle:
- "Your strength is real. I have no complaints."

#### Agatha (Map 317)

Pre-battle. No path variant. The only E4 member who KNOWS about Mewtwo. She does not laugh.

- "I know why you're here. I know what's waiting at the end of this road."
- "Samuel's chickens coming home to roost. I told him, thirty years ago. I told him what would happen if he played god."
- She looks at the player with ancient, furious clarity.
- "He didn't listen. None of you ever listen."
- "Well? Come on, then. Let's see if this generation is any different."

Post-battle:
- "You beat an old woman. Congratulations. Now go deal with the mess my generation made."

#### Lance (Map 318) — Path-Variant

**Oak Path (Switch 1131 OFF):**
- "Your friend is strong. Maybe the strongest trainer I've ever fought."
- "They also have something in their bag that scares me more than any Pokemon."
- "Whatever you're doing here — I hope you know what it costs."

**Giovanni Path (Switch 1131 ON):**
- "I know what you're carrying. Your friend told me."
- "They begged me to stop you. I tried."
- A pause.
- "They're waiting for you. Not as your enemy. As the last person who still believes you can make the right choice."

Post-battle (shared):
- "Go. Whatever happens in that chamber... the League will survive it. It always does. Whether it should is another question."

#### Champion — Oak Path (Switch 1131 OFF)

The rival is Champion. The Master Ball is on the table. Pride, grief, resolve.

Pre-battle beats:
- The rival references the player's journey. Not a recap — a reckoning.
- They talk about Mewtwo: what it means that something that powerful exists, what it means that the people who made it spent fifteen years pretending it didn't.
- "Oak hid it. Giovanni wanted to enslave it. The League wants to forget it."
- "I want to be the person who finally decides — openly, honestly, with the authority to back it up."
- "If you're here to stop me... then stop me. That was always the deal."

Post-battle:
- The rival concedes. Exhausted, heartbroken, but not broken.
- "So what are you going to do with it?"
- The player takes the Master Ball. (This is automatic — no choice. The choice is what happens AFTER, in the ending.)

#### Champion — Giovanni Path (Switch 1131 ON)

The rival is Champion. They do NOT have the Master Ball. The player does. The rival became Champion for one reason: to be the last line of defense.

Pre-battle beats:
- "I used to think the hardest part of growing up would be figuring out what I believe. Turns out the hardest part is watching someone you love become someone you have to fight."
- References Giovanni after defeat: "He couldn't stop. Even at the end, he couldn't stop. He was sitting in the rubble of his own gym, telling me that everyone else was wrong."
- "Does this feel like the right choice to you? Because it felt like the right choice to him, too. Every single time."
- The rival is not angry. Sad. Ready.

Post-battle:
- "I couldn't stop you. I tried."
- Long pause.
- "Promise me something. When you open that cave... if you catch yourself sounding like Giovanni — still certain, still righteous, still unable to see it... please stop. Even if it feels right. Especially if it feels right."

### 4. Dialogue Direction — Endings

#### Oak Path Ending

After Champion defeat:
1. Player has the Master Ball. Oak arrives (as in vanilla, but rewritten).
2. Scene: Oak acknowledges what the rival tried to do. No condemnation.
3. Player returns to Pallet Town with the Master Ball. Oak is waiting.
4. The player gives the Master Ball back to Oak (this is implicit / scripted — the "choice" was made at Silph Co.).
5. Final exchange: "No more secrets." Oak agrees, wearily.
6. Rival departing scene: quiet, warm, unresolved. Still friends.

**Post-credits (Cerulean Cave):**
- The player stands at Cerulean Cave. The seal is broken.
- They enter carrying the Master Ball — not to capture Mewtwo, but to return it.
- "No one is coming for you. This is yours."
- Mewtwo stirs. A battle begins — not because the player wanted it, but because Mewtwo doesn't trust anyone who carries that Ball.
- **The fight is the ritual. The result doesn't matter.** Win or lose, the scene plays the same.
- Mewtwo regards the player. Long silence. Screen fades.

#### Giovanni Path Ending

After Champion defeat:
1. The player does NOT return to Pallet Town.
2. Player goes directly to Cerulean Cave. The seal is breaking.
3. Oak intercepts at the cave entrance. His last appeal:
   - "I made Mewtwo. I know what it is. It's not a weapon. It's not a tool. It's a person — a person I wronged."
   - "If you walk in there with that Ball, you become me. You become Giovanni."
4. The player enters regardless. The cave. The descent.
5. Mewtwo, waiting. The player throws the Master Ball.
6. **The screen cuts to black at the moment of the throw.** The sound of the Ball activating. Then: nothing.
7. The ambiguity is the point.

#### Shared Ending Element

Both endings conclude with:
- Oak's final line: "I spent my life trying to answer one question. I think maybe the question was wrong."
- Player character shown on Route 1. The game began here.
- Credits roll. City montage. Oak Path: hopeful. Giovanni Path: ambiguous, melancholy. The rival is shown alone somewhere, looking at the sky.

### 5. Player Choices & Switches — Indigo Plateau

**No new player choices in the Indigo Plateau section.** The E4 and Champion fights are mandatory battles with scripted dialogue. The Victory Road choice (Variable 344 / Switches 1147-1149) may be referenced in Champion dialogue for flavor but does not gate anything.

Switches READ:
- `SYNTH_FORK_CHOSEN` (1130) — ON
- `SYNTH_GIOVANNI_PATH` (1131) — path variant for Lance, Champion, endings
- `SYNTH_VROAD_TRUST/CHALLENGE/MIRROR` (1147-1149) — optional flavor in Champion dialogue
- `SYNTH_FUJI_*` (1135-1138) — optional: ending tone can soften/harden based on Lavender stance
- `SYNTH_MEWTWO_KNOWN` (1153) — should be ON by this point; Agatha's dialogue assumes it

Switches SET:
- `SYNTH_CHAMPION_DEFEATED` (1156) — set after Champion battle
- `SYNTH_CAVE_ENTERED` (1157) — set when player enters Cerulean Cave for ending

### 6. Mechanical Info to Preserve

- Elite Four gauntlet structure: four consecutive battles, healing between rooms, no backtracking until champion is defeated. Unchanged.
- All E4 teams unchanged mechanically.
- Champion team: the rival's team. Must be set up as the rival's strongest team. Mechanically identical in both paths.
- Hall of Fame registration after Champion defeat: preserved.
- Post-credits plays after Hall of Fame: this is where the ending cutscene triggers.
- Cerulean Cave access: gated by `SYNTH_CHAMPION_DEFEATED` (1156). The base game gates it by Champion defeat already — Synthesis adds the narrative framing.

**Important:** The base game has Blue as Champion (Event 2, Map 328). Synthesis replaces Blue with the rival. The event structure (pre-battle dialogue, battle call, post-battle dialogue, Oak arrival) can be reused — the event commands are the same shape, just with different text and a path branch.

### 7. New Events

- **Lance path-variant dialogue.** Not a new event — rewrite of existing Lance event (Map 318) with a Conditional Branch on Switch 1131 inside the pre-battle page.
- **Champion rewrite.** Not a new event — rewrite of existing Blue/Champion event (Map 328, Event 2) with path-variant dialogue.
- **Oak arrival rewrite.** The base game has Oak arrive after the Champion fight. This event is rewritten for path-variant endings.
- **Ending sequences.** Two event chains:
  - Oak Path: transition to Pallet Town, Oak scene, Cerulean Cave post-credits.
  - Giovanni Path: transition to Cerulean Cave directly, Oak intercept, cave interior, Master Ball throw, fade to black.
- **Cerulean Cave ending events.** These are on the Cerulean Cave maps, not the Indigo Plateau maps, but they are triggered by `SYNTH_CHAMPION_DEFEATED` and are narratively part of the endgame. They should be planned here but implemented on the cave maps.

### 8. Special Logic Flags

```
=== ELITE FOUR (Maps 315-318) ===

LORELEI (Map 315):
  No switch logic. Single pre-battle text block. Rewrite in place.

BRUNO (Map 316):
  No switch logic. Single pre-battle text block. Rewrite in place.

AGATHA (Map 317):
  No switch logic. Single pre-battle text block. Rewrite in place.
  (Assumes SYNTH_MEWTWO_KNOWN is ON. If not, her dialogue still
   works — she's revealing what she knows independently.)

LANCE (Map 318):
  PAGE 0 (pre-battle):
    → Conditional Branch: SYNTH_GIOVANNI_PATH (1131)
      OFF → Oak Path Lance dialogue
      ON  → Giovanni Path Lance dialogue
    → Battle (unchanged)
    → Post-battle dialogue (shared)

  NOTE: Can be done as a single page with one Conditional Branch.
  No separate pages needed.

=== CHAMPION (Map 328) ===

EVENT: Rival/Champion (replaces Blue, Ev2)
  PAGE 0 (Champion battle):
    Condition: SYNTH_CHAMPION_DEFEATED (1156) OFF

    → Conditional Branch: SYNTH_GIOVANNI_PATH (1131)
      OFF (Oak Path):
        → Oak Path Champion dialogue
        → Optional: Conditional Branch on SYNTH_VROAD_CHOICE (Var 344)
           for flavor lines (rival references what player said
           in Victory Road). Keep brief — 1-2 lines per variant.
        → Battle (rival's Champion team)
        → Oak Path post-battle dialogue
        → Player receives Master Ball (item add? or narrative only?)
        → Set SYNTH_CHAMPION_DEFEATED (1156) ON
      ON (Giovanni Path):
        → Giovanni Path Champion dialogue
        → Optional: Same Var 344 flavor branch
        → Battle (same team)
        → Giovanni Path post-battle dialogue
        → Set SYNTH_CHAMPION_DEFEATED (1156) ON

    → Oak arrival scene (rewritten)
    → Hall of Fame registration
    → Transition to ending sequence

  PAGE 1 (post-game / rematch):
    Condition: SYNTH_CHAMPION_DEFEATED (1156) ON
    → Rematch dialogue (if applicable) or empty.

=== ENDING SEQUENCES ===

ENDING ROUTER (after Hall of Fame, or as post-credits autorun):
  → Conditional Branch: SYNTH_GIOVANNI_PATH (1131)
    OFF (Oak Path):
      → Fade to Pallet Town
      → Oak scene: "No more secrets"
      → Rival farewell scene
      → Fade to credits montage (hopeful tone)
      → Post-credits: Cerulean Cave
        → Player enters cave
        → Set SYNTH_CAVE_ENTERED (1157) ON
        → Mewtwo encounter (standard battle, but outcome
           does not matter — win or lose, same scene)
        → Fade. Oak's final line. Route 1. End.
    ON (Giovanni Path):
      → Fade to Cerulean Cave exterior
      → Oak intercept dialogue
      → Player enters cave
      → Set SYNTH_CAVE_ENTERED (1157) ON
      → Cave interior descent (can be a simple fade/transfer)
      → Mewtwo appears
      → Master Ball throw animation
      → Screen cuts to BLACK at moment of throw
      → Ball activation sound effect
      → Silence
      → Fade. Oak's final line. Route 1. End.

SIMPLIFICATION NOTES:
- The ending sequences are the most complex scripting in the
  endgame but they are LINEAR. No player choices, no branches
  within each path. Once the path is determined (Switch 1131),
  each ending is a straight line of: transfer → dialogue →
  transfer → dialogue → fade → credits.
- The Cerulean Cave "battle" on Oak Path can use a standard
  wild Pokemon battle call. Win/loss both proceed to the same
  post-battle event page.
- The Giovanni Path Cerulean Cave does NOT use a battle call.
  It is a cutscene: show Mewtwo sprite, play throw animation
  (or a simplified version — screen flash + sound effect),
  then immediate fade to black.
- Credits montage: if the base game has a credits sequence
  that can be called, use it. Tone differences between paths
  can be handled by music selection (Switch 1131 branch on
  the credits map/event to pick BGM).
```

---

## Summary: All Switches and Variables for Endgame

### Switches Read

| Switch | Name | Read Where |
|--------|------|-----------|
| 1130 | `SYNTH_FORK_CHOSEN` | All endgame events (gate check) |
| 1131 | `SYNTH_GIOVANNI_PATH` | Giovanni Gym, Lance, Champion, Endings |
| 1135-1138 | `SYNTH_FUJI_*` | Optional: ending tone flavor |
| 1147-1149 | `SYNTH_VROAD_*` | Optional: Champion flavor lines |
| 1153 | `SYNTH_MEWTWO_KNOWN` | Agatha (assumed ON; not gating) |

### Switches Set

| Switch | Name | Set Where |
|--------|------|----------|
| 1147 | `SYNTH_VROAD_TRUST` | Victory Road choice, option 1 |
| 1148 | `SYNTH_VROAD_CHALLENGE` | Victory Road choice, option 2 |
| 1149 | `SYNTH_VROAD_MIRROR` | Victory Road choice, option 3 |
| 1156 | `SYNTH_CHAMPION_DEFEATED` | After Champion battle |
| 1157 | `SYNTH_CAVE_ENTERED` | Cerulean Cave ending sequence |

### Variables Set

| Variable | Name | Set Where |
|----------|------|----------|
| 344 | `SYNTH_VROAD_CHOICE` | Victory Road choice (1-4) |

---

## Word Count Estimate

| Section | Scope | Est. Words |
|---------|-------|-----------|
| **Viridian City overworld NPCs** | ~10 NPCs, simple rewrites | 400-500 |
| **Viridian Gym trainers** (8) | Pre/post battle, no path variant | 500-600 |
| **Viridian Gym Guide** | Pre/post badge, 2 states | 150-200 |
| **Giovanni pre-battle (Oak Path)** | Extended monologue | 250-350 |
| **Giovanni pre-battle (Giovanni Path)** | Extended monologue | 250-350 |
| **Giovanni post-battle (Oak Path)** | Bitter exit | 100-150 |
| **Giovanni post-battle (Giovanni Path)** | Bitter stay | 100-150 |
| **Route 22/23 guards & NPCs** | ~20 NPCs, brief lines | 400-500 |
| **Victory Road trainers** | ~10 trainers, pre/post battle | 400-500 |
| **Victory Road rival (Oak Path)** | Full conversation + choice responses | 500-700 |
| **Victory Road rival (Giovanni Path)** | Full conversation + choice responses | 500-700 |
| **Indigo Plateau lobby** | 1 NPC | 50-75 |
| **Lorelei** | Pre/post battle | 150-200 |
| **Bruno** | Pre/post battle | 100-150 |
| **Agatha** | Pre/post battle (longer) | 200-250 |
| **Lance (Oak Path)** | Pre/post battle | 150-200 |
| **Lance (Giovanni Path)** | Pre/post battle | 150-200 |
| **Champion (Oak Path)** | Full pre/post battle conversation | 500-700 |
| **Champion (Giovanni Path)** | Full pre/post battle conversation | 500-700 |
| **Ending — Oak Path** | Pallet scene + Cerulean Cave | 400-500 |
| **Ending — Giovanni Path** | Cave approach + Oak intercept + cave | 400-500 |
| **Shared ending elements** | Oak's final line, Route 1 | 50-75 |
| | | |
| **TOTAL ESTIMATE** | | **5,550-7,250 words** |

This is the most text-dense section of the game after Silph Co. The bulk is in the four major path-variant conversations (Giovanni Gym, Victory Road rival, Champion, endings), each of which requires two complete dialogue tracks. The E4 members are comparatively light — brief and punchy, not extended conversations.

---

## Implementation Priority

1. **Champion event (Map 328)** — most complex, most important. Get the rival dialogue right first.
2. **Victory Road rival (new event)** — second most complex, sets up the Champion fight emotionally.
3. **Giovanni Gym (Map 85, Ev92)** — path-variant but self-contained. Can be written independently.
4. **Ending sequences** — depend on Champion event structure. Write after Champion is locked.
5. **Lance path-variant (Map 318)** — small but important. Write alongside Champion.
6. **Lorelei, Bruno, Agatha** — no path variants. Can be written any time.
7. **Overworld NPCs / trainers / guards** — lowest priority. Bulk text, no logic complexity.
