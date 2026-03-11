# Special Logic Areas — Flagged for Later Implementation

These areas require scripting beyond simple dialogue replacement. Per project direction, they are set aside for last and should use **text switches** (dialogue-based branching) rather than complex cutscenes wherever possible.

---

## Tier 1: Moderate Scripting (Dialogue + Switch Logic)

### S.S. Anne (Maps 17, 27-31, 34-36)
**Original plan:** Place gym leader sprites (Erika, Misty, Surge, officials) as NPCs at a party. Player overhears conversations.
**Simplified approach:** Keep the S.S. Anne's existing structure. Replace NPC dialogue to reflect the League diplomatic event through *text only*. Instead of duplicating gym leader sprites:
- Use existing party-goer NPCs and give them overheard-conversation dialogue that references the League meeting
- One NPC mentions Erika's position on fusion regulation
- One NPC mentions Surge arguing for military action
- One NPC mentions Misty pushing for reform
- The Captain's room encounter stays as-is mechanically (get HM Cut)
- **No sprite duplication, no new events, just dialogue replacement**

**Scripting needed:** None beyond dialogue replacement. This is actually NOT special-logic anymore with the simplified approach.

---

### Mt. Moon Rocket Encounter (Maps 102, 105)
**Original plan:** Rework Rockets from "stealing fossils" to distributing fusion tech to unlicensed trainers.
**Simplified approach:**
- Existing Rocket grunts get new dialogue that establishes ideological motivation
- First grunt: earnest, explains the cost of fusion licenses
- Second grunt: more aggressive, initiates the fight
- The fossil scientist stays as-is (fossils are still there as secondary objective)
- Rival appears and helps (may need a new trigger event or can use existing)

**Scripting needed:** Possibly a new event for the rival's entrance if one doesn't exist. Otherwise dialogue-only.

---

### Cerulean Cave Guard (New Event)
**What:** A guard NPC at the cave entrance north of Cerulean.
**Scripting:** Single event with switch-based pages:
- Page 0 (default): "Restricted area. League authorization only."
- Page 1 (post-E4): Access granted / different dialogue

**Scripting needed:** One new event with basic page conditions. Minimal.

---

## Tier 2: Significant Scripting (Path Variants + New Mechanics)

### Pokémon Tower (Lavender Town)
**What needs scripting:**
- Existing Rocket events reframed (dialogue-only for most)
- The record-destruction sequence: Rockets destroying evidence. Player finds a "Project M" reference before it's destroyed. This can be a dialogue event with a timed reveal.
- Mr. Fuji's positional choice (Switch 1150): 4-option choice box affecting later dialogue

**Simplified approach:**
- Keep existing Tower structure and ghost/Channeler encounters
- Replace Rocket dialogue to frame them as destroying records, not stealing skulls
- Mr. Fuji's choice: standard Show Choices command (code 102) setting switches
- "Project M" journal: a single interactable event (bookshelf or document) on one of the upper floors

**Scripting needed:** Choice command for Mr. Fuji + switch-setting. One new bookshelf event for Project M. Moderate.

---

### Rival Path-Variant Encounters
Rival dialogue splits after Saffron. Encounters at:
- **Fuchsia City** — Oak Path vs Giovanni Path dialogue
- **Victory Road** — Oak Path vs Giovanni Path + player choice
- **Champion's Chamber** — Two complete dialogue tracks

**Scripting:** Each uses the main path switch (Switch 1200 = Oak Path, Switch 1201 = Giovanni Path) to select between page variants. The existing rival events likely already have multi-page structures.

**Simplified approach:** Use page conditions based on the path switch. Each rival event gets two pages: one for Oak Path, one for Giovanni Path. Standard RPG Maker page-switching, no custom scripts needed.

---

### Giovanni's Gym (Viridian City Return)
**What:** Giovanni's dialogue has two path variants. Otherwise a standard gym.
**Scripting:** Two pages on Giovanni's event, switched by path flag.
**Simplified approach:** Pure dialogue replacement with page conditions. Low complexity.

---

### Blaine's Gym (Cinnabar Island)
**What:** Blaine has two path-variant dialogue tracks.
**Scripting:** Same as Giovanni — two pages, path switch.
**Simplified approach:** Pure dialogue replacement with page conditions. Low complexity.

---

## Tier 3: Heavy Scripting (THE FORK and Endings)

### Silph Co. — THE FORK (Saffron City)
**The game's defining moment.** The player chooses between fighting Giovanni or chasing the Master Ball.

**Core mechanics needed:**
1. **The choice event:** Show Choices command setting the path switch (Switch 1200/1201)
2. **Route divergence:** After the choice, the player is directed to one of two rooms/events:
   - Oak Path: Giovanni boss fight (existing boss, new dialogue)
   - Giovanni Path: Archer boss fight (NEW boss trainer)
3. **Post-fight scenes:** Different for each path
4. **Oak's arrival:** Switch-based dialogue

**Simplified approach (per user direction):**
- The fork is a single choice event. After choosing, text describes what happens rather than showing split cutscenes.
- "You charge after Archer down the corridor..." (text) vs animated sequences
- Giovanni fight: use existing boss battle event, replace dialogue
- Archer fight: **needs a new trainer event** — this is unavoidable, but the battle itself is standard
- Post-fight and Oak's arrival: text-only, switch-gated pages

**Scripting needed:** New Archer trainer event, path switch, 2-3 switch-gated events for post-fork scenes. Medium-high complexity but manageable with text-only approach.

---

### Elite Four + Champion's Chamber (Indigo Plateau)
**What needs scripting:**
- E4 members get brief pre-battle dialogue (can overlay on existing events)
- Lance has path-variant dialogue (two pages)
- **Champion = Blue/Rival** instead of the default champion
  - Two complete pre-battle dialogue tracks (Oak Path vs Giovanni Path)
  - The rival's team needs to be set up as a trainer
- Post-battle: path-variant ending text

**Simplified approach:**
- E4 pre-battle dialogue: pure text replacement on existing events
- Lance: two pages with path switch
- Champion replacement: modify the existing champion event to use the rival's sprite and team. Two pages for dialogue.
- Endings: text-only sequences. No cutscenes.

**Scripting needed:** Champion trainer data (rival's team), path-variant pages. Medium complexity.

---

### Cerulean Cave Postgame
**What needs scripting:**
- Oak Path: Mewtwo battle (standard legendary encounter, outcome doesn't change ending)
- Giovanni Path: Cutscene — approach Mewtwo, throw Master Ball, screen fades to black

**Simplified approach:**
- Oak Path: modify existing Mewtwo encounter event, add pre/post dialogue
- Giovanni Path: text event leading to a fade-to-black. No complex animation.

**Scripting needed:** One switch-gated event for the Giovanni Path cutscene. Low-medium.

---

## Implementation Priority Order

1. **Do first (dialogue-only, no scripting):**
   - All city NPCs, route NPCs, gym trainers
   - S.S. Anne (simplified — just dialogue)
   - Mt. Moon Rockets (just dialogue)
   - All environmental objects, signs, bookshelves

2. **Do second (simple switch logic):**
   - Path-variant rival encounters (page conditions)
   - Giovanni gym (page conditions)
   - Blaine gym (page conditions)
   - Lance E4 (page conditions)
   - Mr. Fuji choice (choice command + switch)
   - Misty choice (choice command + switch)
   - Nugget Bridge flag (choice command + switch)

3. **Do third (new events/trainers):**
   - Cerulean Cave guard (new event)
   - Project M journal (new event)
   - Pokémon Mansion journals (new events throughout)
   - Champion = Rival (modify existing champion event + trainer data)

4. **Do last (THE FORK):**
   - Silph Co. fork choice event
   - Archer boss trainer (new)
   - Post-fork scenes (switch-gated events)
   - Oak's revelation (switch-gated event)
   - Cerulean Cave endings (switch-gated events)
