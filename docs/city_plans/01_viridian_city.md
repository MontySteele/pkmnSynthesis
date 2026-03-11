# Viridian City (Initial Visit) — Narrative Plan

**Covers:** Viridian City outdoor maps (79, 710, 711), Pokemon Center (80), PokeMart (81), Viridian Houses (83, 84, 746), Viridian City Gym exterior (locked), Viridian Forest (491), Viridian River (40, 669)

**Story Phase:** Phase 1 — Innocence
**Visits:** This document covers the INITIAL visit only. The return visit (Phase 4, post-7-badges, Giovanni's gym open) is flagged for separate treatment.

---

## 1. Overview

Viridian City is a threshold. The player has just left Pallet Town — a tiny place where they know everyone — and arrives in the first real settlement. It should feel bigger, busier, and slightly overwhelming, but never threatening. The tone is **transitional curiosity**: the world is larger than home, there are people with their own lives, and the systems that govern this world (the League, gyms, Pokemon Centers, Marts) are visible for the first time.

Three things anchor the initial visit narratively:

1. **The closed gym.** The player sees Giovanni's name on the sign (or, in some map variants, just "?") and learns the Leader has been absent for a long time. This is pure foreshadowing — a question mark planted early that pays off much later. NPCs should treat this as a mundane annoyance, not a conspiracy. The gym is just... closed. Nobody knows why and nobody is especially alarmed.

2. **The PokeMart and Oak's Parcel.** This is a mechanical quest inherited from Pallet Town. The player picks up Oak's parcel and receives DNA Splicers as a bonus. The Mart clerk should feel like a normal shopkeeper, not a tutorial robot. Keep the parcel handoff quick and natural.

3. **Viridian Forest as first dungeon.** The player's first sustained wild encounter area. Bug catchers are earnest kids, not obstacles. The forest is dense, a little disorienting, and alive. It prepares the player for Pewter City without any major narrative beats of its own.

**Synthesis-specific tone notes:**
- NPCs can mention fusion casually and positively. It is still Phase 1 — fusion is exciting, the League is good, everything works.
- One or two NPCs should mention the Pokemon Academy as a resource for learning about fusion.
- The drunk old man blocking Route 2 is a classic gate. Keep him — he is a charming bit of texture and a soft gate until the parcel quest is done.
- No Rocket references. No tension. The only shadow is the closed gym, and it should be a shadow the player barely notices on their first pass.

---

## 2. Map-by-Map NPC Inventory

### Map 79 / 710 / 711: Viridian City (Outdoor) — 15-17 text events each

Maps 79, 710, and 711 appear to be variants of the same outdoor city map (possibly for different game modes or randomizer settings). They share most events. Inventory below is based on the canonical set:

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV003 | Gym Door | "It appears to be locked..." | Interaction with gym door. Keep as-is mechanically. |
| EV005 | Pokedex Tip NPC | Pokedex can identify opponent types in battle | **Mechanical tip — preserve.** Only on Maps 710/711. |
| EV007 | Fusion Fan | "Fusing Pokemon is a lot of fun!" / Pokemon Academy reference | Rewrite for Synthesis tone. |
| EV009 | Drunk Old Man | Blocks path, slurring dialogue | Classic gate NPC. Keep mechanical blocking behavior. |
| EV016 | Gym Greeter | "Gym Leader is out of town" / later pages hint at Cinnabar, Johto | Page 0 is initial visit. Pages 1-2 are later states. |
| EV022 | Old Man's Granddaughter | "Good grief, Grandpa!" / Page 1: he's gone home | Tied to EV009/EV024 drunk man sequence. |
| EV023 | Academy Sign | "Pokemon Academy" sign text | Keep as-is. |
| EV024 | Old Man (lying down) | "An old man is lying in the street" | Descriptive text for drunk man sprite. |
| EV025 | Cinnabar Scientist | Post-game: gives legendary bird items | **Late-game event.** Not relevant to initial visit. Do not touch. |
| EV029 | Pidgey Trainer | Wants to challenge the League / needs training | Rewrite for Synthesis voice. |
| EV030 | Pidgey | "Chirp! Chirp chirp!" | Keep. |
| EV031 | League Enthusiast | "You should go to the Pokemon League!" | Rewrite for Synthesis voice. |
| EV032 | Trainer House Sign | (Maps 710/711 only) | Keep as-is. |
| EV033 | Pokemon Center Sign | Standard sign | Keep as-is. |
| EV034 | PokeMart Sign | Standard sign | Keep as-is. |
| EV035 | Gym Sign | "Viridian City Gym / Gym Leader: Giovanni" (Map 79) or "Gym Leader: ?" (Maps 710/711) | **Important.** Map 79 names Giovanni; 710/711 use "?". Decide which to use. See Dialogue Direction. |
| EV036 | Wooden Plank NPC | Side quest: battle for wooden planks | Mechanical side quest. Rewrite dialogue but preserve structure. |

### Map 80: Pokemon Center — 9 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV003 | Oak's Assistant | Fusion reward check (5+ fusions = item) | **Mechanical event — preserve fusion count check.** Rewrite dialogue. |
| Nurse | Nurse Joy | Standard healing dialogue + Pokerus explanation | **Mechanical — preserve healing flow.** Rewrite for Synthesis voice. |
| EV009 | Joke Clown | Tells Pokemon jokes, accepts tips | Comic relief. Rewrite jokes or keep. Low priority. |
| EV011 | Move Tutor | Teaches starter moves for $500 | **Mechanical — preserve move tutor system.** Rewrite wrapper dialogue. |
| EV014 | Starter Trader | Trades starters (type-dependent) | **Mechanical — preserve trade logic.** Rewrite wrapper dialogue. |
| EV015 | Graah Pokemon | "Graah!" (3 pages) | Flavor. Keep or cut. |
| EV017 | Fusion Tip (Head) | "Special moves = Head" | **Mechanical tip — preserve information.** |
| EV018 | Fusion Tip (Body) | "Physical attacker = Body" | **Mechanical tip — preserve information.** |
| EV019 | Stat Display | Head stats: HP, Sp.Def, Sp.Atk / Body stats: Atk, Def, Spd | **Mechanical tip — preserve exactly.** |

### Map 81: PokeMart — 10 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV002 | Clerk (Parcel) | Gives Oak's parcel + free DNA Splicers | **Mechanical quest event — preserve parcel handoff and splicer gift.** Page 1: post-delivery flavor line. |
| EV005/6/8/9/22/23 | Shelf Descriptions | "Shelves filled with Pokemon goods!" | Flavor. Rewrite or keep. |
| EV024 | Shopper NPC | Needs potions and Pokeballs | Rewrite for Synthesis voice. |
| EV025 | Shopkeeper | Standard buy/sell interface | **Mechanical — preserve.** |
| Deliveryman | Deliveryman | Mystery Gift delivery | **Mechanical — do not touch.** |

### Map 83 / 746: Viridian House (Nickname House) — 9 / 5 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV002 | Nickname Dad | "Coming up with nicknames is fun" | Flavor. Rewrite. |
| EV003 | Nidoran | "Midoran: Raaaah!" | Keep. |
| EV004 | Nickname Kid | Dad named the Nidoran | Flavor. Rewrite. |
| EV005/6 | TV | Nature documentary playing | Keep or rewrite for Synthesis flavor. |
| EV007 | Empty Shelf | "It's empty." | Keep. |
| EV008 | Plant | "Such a nice plant." | Keep. |
| EV009 | Headache NPC | "Argh, I have a terrible headache" | Flavor. Rewrite. |
| EV010 | Weedle | "Veedle: Prtt!" | Keep. |

### Map 84: Viridian House (Gym Neighbor) — 6 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV002/3 | TV | Foreign movie playing | Keep or rewrite. |
| EV004 | Gym Neighbor | "The Gym next door is always locked. Something shady..." | **Important for foreshadowing.** Rewrite for Synthesis. |
| EV005 | Pokemon | "Shreeeeek!" | Keep. |
| EV006 | Empty Container | "Nothing in here" | Keep. |
| EV007 | Bug Info NPC | Caterpie vs Weedle (poison) tip | **Mechanical tip — preserve poison warning.** Rewrite delivery. |

### Map 85: Viridian City Gym (Interior) — 10 text events

All events here are for the RETURN VISIT (trainers, Giovanni fight, gym guide). **Not relevant to initial visit — the gym is locked.** Flagged for separate treatment in the return visit document.

### Map 491: Viridian Forest — 24 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| Trainer(4) - EV004 | Bug Catcher 1 | "Hey, look at my cool bug Pokemon!" / rematch offer | **Mechanical — preserve trainer battle + rematch system.** Rewrite dialogue. |
| EV008/18 | Forest Signs | "North: Pewter City / South: Viridian City" | Keep as-is (directional). |
| EV009/21/22/23/24/25/37/43 | Spider Webs | Inspectable webs — random Spinarak/Ariados battle, Pecha Berry, Bug Gem, or nothing | **Mechanical — preserve random encounter/item system.** Keep interaction text. |
| Trainer(2) - EV011 | Bug Catcher 2 | "Bug Pokemon are totally great!" / rematch + Brock reference | **Mechanical — preserve trainer battle + rematch.** Rewrite dialogue. |
| Trainer(5) - EV012 | Bug Catcher/Trader | Post-battle trade offer (bug types for fused Pokemon) | **Mechanical — preserve trade system.** Rewrite dialogue. |
| Trainer(1) - EV020 | Lost Trainer | "This is a dead end... Let's battle!" / post-battle: lost, gives item | **Mechanical — preserve battle + item gift.** Rewrite dialogue. |
| EV033 | Mushroom Gatherer | Mushrooms grow back daily, mentions hotel | **Mechanical tip — preserve mushroom respawn info.** Rewrite. |
| EV038 | Kurt (Azalea Town) | Post-game: Kurt studying bugs, rematch offer | **Late-game event.** Not relevant to initial visit. |
| EV044/45/53 | Amber Quest NPCs | Beedrill removal → Old Amber reward | **Side quest — preserve quest structure.** Rewrite dialogue. |
| EV054/62 | Pokemon Nest/Egg | Find a Pokemon egg in a nest | **Mechanical — preserve egg event.** |
| EV055/56 | Shiny Rocks | Item pickup (rocks with shine) | **Mechanical — preserve.** |
| EV057 | Angry Parent Pokemon | Wild battle trigger | **Mechanical — preserve.** |

### Map 40 / 669: Viridian River — 5 / 2 text events

| Event | Name | Base Dialogue Summary | Notes |
|-------|------|----------------------|-------|
| EV004 (Map 40) | Mew | "Mew!" — scripted Mew appearance | **Major scripted event — do not alter trigger logic.** |
| EV006/9/10 (Map 40) | Starter Pokemon | Starter cries during river sequence | **Scripted sequence — preserve.** |
| EV001 (Map 669) | Fisherman/Trainer | "A Pokemon Trainer... rare sight" / pure water attracts rare Pokemon | Rewrite for Synthesis voice. |
| EV002 (Map 669) | Empty Spot | "Nice try... It's empty." | Keep. |

---

## 3. Dialogue Direction

### City NPCs — "First Real City"

**Goal:** Viridian should feel like a place where people live, not a tutorial gauntlet. NPCs have their own concerns — a sick Nidoran, a drunk grandfather, a gym that never opens. The player is passing through, not the center of attention.

**EV007 — Fusion Fan:**
- Base: Generic enthusiasm about fusion + Academy plug.
- Synthesis: Keep the enthusiasm genuine. This is Phase 1 — fusion IS exciting. But ground it. Instead of "Fusing Pokemon is a lot of fun!", try something like: "My neighbor fused her Pidgey with a Spearow and it learned moves neither of them knew on their own. The Pokemon Academy has a whole course on it if you're interested." Mention the Academy naturally.

**EV029 — Pidgey Trainer:**
- Base: Wants to challenge the League, needs more training.
- Synthesis: A young trainer with a single Pidgey and big dreams. This mirrors the player. "I'm going to challenge the Pokemon League someday. Pidgey and I just need to get a little stronger first." Simple, earnest. Maybe add: "My mom says I should get my fusion license first, but I want to earn my first badge on my own terms."

**EV031 — League Enthusiast:**
- Base: Generic "go to the Pokemon League!" advice.
- Synthesis: Slightly more specific. "The Pokemon League is north of here, past Victory Road. You'll need all eight gym badges to enter. Most trainers never make it that far — but hey, someone has to, right?"

**EV036 — Wooden Plank NPC:**
- Base: Side quest NPC who demands a battle before giving planks.
- Synthesis: Keep the mechanical structure. Rewrite to give this person a reason to exist. "You want the planks? Tell you what — I've been bored out of my mind since the gym closed. Battle me and they're yours." Connects to the closed gym texture.

**Map 83/84 House NPCs:**
- Nickname family: Keep light. Dad named the Nidoran "Midoran" and his kid is embarrassed. This is good texture — keep the spirit, just clean up the prose.
- Gym Neighbor (EV004, Map 84): **Key foreshadowing NPC.** Base: "The Gym next door is always locked. There must be something shady going on..." Synthesis: More grounded suspicion. "That gym's been locked up for as long as I've lived here. The sign says 'Giovanni' but I've never seen the man. The League sends inspectors sometimes, but they always leave without saying anything. You'd think they'd just appoint someone new." This plants three seeds: Giovanni's name, the League's passive behavior, and the idea that institutions sometimes choose not to act.
- Bug Info NPC (EV007, Map 84): Keep the Caterpie/Weedle poison tip. Reframe as a parent warning their kid (or the player): "If you're heading through Viridian Forest, watch out for Weedle. Caterpie are harmless, but Weedle has a Poison Sting that'll make your Pokemon miserable."

### PokeMart — Oak's Parcel

**Goal:** Quick, functional, slightly warm. The clerk is doing their job.

**EV002 — Clerk (Parcel Handoff):**
- Base: Recognizes the order, gives parcel + free DNA Splicers.
- Synthesis: "Oh, you're here for Professor Oak's order? Let me grab that. ...Here you go. And we're running a promotion this month — free DNA Splicers with every delivery. The Professor will know what to do with them." Keep it brisk. The splicer gift is mechanical (player needs them) but frame it as commerce, not tutorial.
- Page 1 (post-delivery): Base says splicers are "selling like hotcakes." Synthesis: "DNA Splicers are our best seller right now. Ever since the League expanded the fusion license program, everyone wants to try it." This is Phase 1 world-building — fusion is popular, the League controls licensing, everything is normal.

**EV024 — Shopper NPC:**
- Base: Needs potions and Pokeballs.
- Synthesis: Keep simple. "I always stock up before heading through Viridian Forest. Potions for the Beedrill, Pokeballs for everything else." Grounds the Mart in practical use and foreshadows the Forest.

### Pokemon Center — Healing and Texture

**Goal:** The nurse is professional. The other NPCs provide fusion tips and side activities. This is the player's first Pokemon Center — make it feel like a real service, not a video game menu.

**Nurse (EV004):**
- Base: Standard healing dialogue.
- Synthesis: Keep the mechanical flow (offer heal → accept/decline → heal animation → farewell). Rewrite the wrapper: "Welcome to the Pokemon Center. We'll take care of your team — no charge, as always. Would you like us to have a look?" The Pokerus explanation can stay mostly as-is; it is mechanical information players need.

**EV003 — Oak's Assistant:**
- Base: Checks fusion count, gives reward at 5+.
- Synthesis: Keep the mechanical check. Rewrite the framing: "Professor Oak asked me to keep an eye out for new trainers who are taking to fusion. If you've fused Pokemon at least five times, I have something for you." This ties the assistant to Oak's mentorship without making Oak omniscient — he asked someone to help, which is what a busy professor would do.

**EV017/18/19 — Fusion Stat Tips:**
- These explain Head vs Body stat splits for fusion. **Preserve the information exactly.** Rewrite the delivery so it sounds like trainers sharing knowledge rather than a textbox: "I learned this the hard way — if your Pokemon is better with Special moves, fuse it as the Head. Head determines HP, Special Attack, and Special Defense. Took me three bad fusions to figure that out."

**EV009 — Joke Clown:**
- Low priority. The jokes are groan-worthy Pokemon puns. They serve as texture and a money sink (tipping). Keep or cut at writer's discretion. If kept, consider trimming to 3-4 jokes instead of 10.

**EV011 — Move Tutor / EV014 — Starter Trader:**
- Both are mechanical services. Rewrite wrapper dialogue to sound natural but preserve all mechanical logic (price check, type check, trade flow).

### Closed Gym — Foreshadowing Giovanni

**Goal:** Plant the seed, do not water it. The player should barely register the gym on first visit. On replay, they will realize the signs were there.

**EV003 — Locked Door:**
- Base: "It appears to be locked..."
- Synthesis: Keep it exactly this terse. Maybe: "The door is locked. A layer of dust coats the handle." Physical detail, no editorializing.

**EV016 — Gym Greeter (Page 0 only for initial visit):**
- Base: "Sorry buddy, but the Gym Leader is out of town."
- Synthesis: "The gym's been closed for... honestly, I've lost count. Months? The Leader just stopped showing up one day. League hasn't appointed a replacement." This is the most the player should hear about the gym on their first visit. It's a loose thread, not a plot hook. The greeter is bored, not worried.
- **Do not use Pages 1-2 for initial visit.** Those reference Cinnabar and Johto — they are return-visit content triggered by progression switches.

**EV035 — Gym Sign:**
- Maps 710/711 use "Gym Leader: ?" which is better for Synthesis. The player should not learn Giovanni's name from a sign — they should learn it when it matters (Silph Co. or the return visit). **Use the "?" variant.**

**Map 84, EV004 — Gym Neighbor:**
- See City NPCs section above. This is the strongest foreshadowing NPC. The key line is that the League knows and does nothing — this mirrors the Mewtwo cover-up at a micro scale, though the player cannot possibly know that yet.

### Viridian Forest — Atmosphere and Bug Catchers

**Goal:** The forest is the player's first real wilderness. It should feel dense, alive, and slightly maze-like. Bug catchers are kids who love bugs — they are not threats. The forest should be atmospheric, not narrative-heavy.

**Bug Catcher 1 (EV004):**
- Base: "Hey, look at my cool bug Pokemon!"
- Synthesis: "You're the first trainer I've seen today! Check out my Caterpie — I caught it right here this morning. Want to battle?" Preserve the rematch offer on Page 1. Keep it friendly and eager.

**Bug Catcher 2 (EV011):**
- Base: "Bug Pokemon are totally great!" / mentions training to defeat Brock.
- Synthesis: "Everyone says Bug types are weak, but they just haven't seen what they can do. I'm training here until I'm ready to challenge the Pewter Gym." The Brock reference is useful — it tells the player where they're headed. Preserve the rematch system.

**Bug Catcher/Trader (EV012):**
- Base: Post-battle trade offer for fused bug Pokemon.
- Synthesis: "I've been experimenting with bug fusions. Want to trade? I'll take any bug type for one of mine." Preserve trade mechanics. The offer of pre-fused Pokemon is a nice early reward.

**Lost Trainer (EV020):**
- Base: "This is a dead end... Let's battle!" / admits to being lost.
- Synthesis: "I think I took a wrong turn about an hour ago. ...Well, since we're both here, want to battle?" Post-battle: "I'd help you find your way, but I'm just as lost. Here, take this — I found it earlier and I don't need it." Preserve item gift.

**Mushroom Gatherer (EV033):**
- Base: Mushrooms respawn daily, mentions hotel.
- Synthesis: "The mushrooms in this forest grow back overnight. If you miss one today, just rest at the hotel in Pewter and come back tomorrow." **Preserve respawn mechanic info.** Light NPC — keep brief.

**Spider Webs (EV009, 21-25, 37, 43):**
- Mechanical interaction: random Spinarak/Ariados encounter, Pecha Berry, Bug Gem, or nothing.
- Synthesis: Keep the inspection text ("inspected the web...") and all random outcomes. No narrative rewrite needed — these are environmental interactions.

**Amber Quest (EV044/45/53):**
- Side quest involving Beedrill removal and Old Amber reward. Preserve quest structure. Rewrite the helper NPC to be a bit more grounded: a researcher or collector, not just a quest-giver. "I found an amber deposit deeper in the forest, but there's a Beedrill nest blocking the path. If you can clear them out, I'll share what we find."

**Forest Signs (EV008/18):**
- Directional signs. Keep exactly as-is.

### Route NPCs

**Viridian River — Map 669:**
- **Fisherman (EV001):** "A Pokemon Trainer... rare sight." Synthesis: "Don't see many trainers down by the river. The water here is some of the cleanest in Kanto — draws all kinds of Pokemon. Keep your eyes open." Simple, atmospheric. Establishes the river as a place worth revisiting.

**Viridian River — Map 40:**
- This map contains the scripted Mew encounter and starter Pokemon sequences. **Do not alter trigger logic or event structure.** These are mechanical/scripted sequences. Dialogue is limited to Pokemon cries ("Mew!" / starter names).

---

## 4. Mechanical Info to Preserve

The following tutorials, tips, and systems MUST be preserved in rewritten dialogue. The information can be reworded but must remain accurate and accessible:

| Mechanic | Source | Information |
|----------|--------|-------------|
| **Healing tutorial** | Map 80, Nurse | Pokemon Center heals for free. Flow: offer → accept → heal → farewell. |
| **Mart tutorial** | Map 81, EV002/EV025 | How to buy items. Oak's parcel pickup triggers Mart access. |
| **DNA Splicers introduction** | Map 81, EV002 | Player receives free DNA Splicers with parcel delivery. |
| **Fusion stat split** | Map 80, EV017/18/19 | Head = HP, Sp.Atk, Sp.Def. Body = Atk, Def, Spd. |
| **Fusion count reward** | Map 80, EV003 | Oak's assistant gives item after 5+ fusions. |
| **Pokedex battle tip** | Maps 710/711, EV005 | Pokedex identifies opponent types mid-battle. |
| **Poison warning** | Map 84, EV007 | Weedle has Poison Sting; Caterpie does not. |
| **Mushroom respawn** | Map 491, EV033 | Forest mushrooms respawn daily. |
| **Web interactions** | Map 491, various | Random encounters/items from spider webs. |
| **Catching tutorial gate** | Map 79, EV009 | Drunk old man blocks Route 2 until parcel quest advances. |
| **Move tutor** | Map 80, EV011 | Starter-exclusive move for $500. |
| **Starter trade** | Map 80, EV014 | Type-specific starter trades. |

---

## 5. New Events Needed

### 5a. Viridian City Outdoor — New NPC: "Traveling Trainer"

**Location:** Near the north exit toward Route 2 / Viridian Forest.
**Purpose:** Establishes the scale of the journey ahead without being prescriptive.
**Dialogue:** "Pewter City is just past Viridian Forest. Brock's gym is there — he's the first Leader most new trainers challenge. Fair warning, the forest can be disorienting if it's your first time. Stick to the paths and you'll be fine."
**Mechanical need:** None. Pure flavor/wayfinding.

### 5b. Viridian Forest — New NPC: "Forest Ranger"

**Location:** Near the southern entrance of Viridian Forest (Map 491).
**Purpose:** Atmospheric world-building. Establishes that the League employs Rangers who maintain route safety — a detail that becomes significant later when Route closures and League authority come into question.
**Dialogue:** "I'm a League Ranger — we keep the routes safe for travelers and trainers. Viridian Forest is well-maintained, but stay alert. The wild Pokemon here aren't aggressive, but they will defend their territory if you stumble into a nest. If your team gets hurt, Viridian City's Pokemon Center is back south."
**Mechanical need:** None. World-building only. Introduces the concept of League Rangers naturally.

### 5c. Viridian Forest — New NPC: "Nervous Trainer"

**Location:** Midway through the forest, near one of the dead-end paths.
**Purpose:** Texture. Shows that not everyone finds the trainer's journey easy or fun.
**Dialogue:** "I thought I was ready for this, but every time a Beedrill buzzes past I freeze up. My Rattata is doing great, though. Braver than I am, honestly."
**Mechanical need:** None. Tone-setting.

### 5d. Pokemon Center — Oak's Motivation Callback

**Location:** Map 80, either as a new NPC or an additional dialogue page on an existing event.
**Purpose:** If the player chose one of Oak's "why be a trainer?" options in Pallet Town (Switches 1140-1143), a Pokemon Center NPC can reflect it back casually. This makes the choice feel noticed without being heavy-handed.
**Dialogue (conditional):**
- Switch 1140 (protect): "You look like the kind of trainer who takes this seriously. Your Pokemon are lucky to have you."
- Switch 1141 (explore): "First time in Viridian? There's a whole world past this city. Enjoy every bit of it."
- Switch 1142 (strength): "I can tell you're hungry for it. That fire's good — just make sure it doesn't burn you."
- Switch 1143 (unsure): "Not sure what you're doing out here yet? That's fine. Nobody is, at first."
- Default (no switch set): "Good luck out there, trainer."
**Mechanical need:** Conditional branch on Switches 1140-1143. Light implementation.

---

## 6. Flagged for Special Logic

### 6a. Viridian Gym (Return Visit) — SEPARATE DOCUMENT

Map 85 contains all Giovanni gym content: trainers, gym guide, Giovanni fight, Earth Badge, and TM26 (Earthquake). This is Phase 4 content requiring:
- 7 badges gate check
- Path-variant Giovanni dialogue (Switch 1131: Oak Path vs Giovanni Path)
- Mewtwo references (Switch 1153)
- Premium Wonder Trade ticket reward

**All Map 85 events are deferred to the Viridian Gym return visit document.**

### 6b. Gym Greeter Pages 1-2

EV016 Pages 1-2 on Maps 710/711 contain progression-dependent dialogue (Cinnabar sighting, Johto rumors). These should be gated behind story progression switches and are not part of the initial visit. Flag for the return visit document.

### 6c. Cinnabar Scientist (EV025)

Post-game event on Maps 79/710/711. References Cinnabar Island events and provides legendary bird tracking items. Gate behind appropriate late-game switch. Not part of initial visit.

### 6d. Kurt (EV038, Map 491)

Post-game Viridian Forest NPC. References Azalea Town (Johto) and offers rematch in Vermillion. Gate behind appropriate late-game switch. Not part of initial visit.

### 6e. Gym Sign — Name Decision

The gym sign currently reads "Gym Leader: Giovanni" on Map 79 and "Gym Leader: ?" on Maps 710/711. **Recommendation: use "?" for the initial visit across all map variants.** Giovanni's identity should be a reveal, not signage. If Map 79 is used for the initial visit, the sign text needs to be changed to match 710/711. On the return visit, the sign can update to show Giovanni's name (or can remain "?" with NPCs providing the name verbally).

### 6f. Mew Encounter (Map 40)

The Viridian River Mew encounter is a scripted event with specific trigger conditions. Do not modify event logic. If Synthesis needs to contextualize Mew (given the Mewtwo storyline), this should be handled through post-encounter dialogue elsewhere, not by altering the encounter itself.

---

## 7. Estimated Word Count

| Section | Events | Est. Words |
|---------|--------|-----------|
| City outdoor NPCs (rewritten) | ~12 speaking NPCs | 350-450 |
| Pokemon Center (rewritten) | ~6 speaking NPCs + Nurse | 400-500 |
| PokeMart (rewritten) | ~3 speaking events | 150-200 |
| House NPCs (rewritten) | ~6 speaking NPCs | 200-250 |
| Viridian Forest (rewritten) | ~8 speaking NPCs + interactions | 350-450 |
| Viridian River (rewritten) | ~1 speaking NPC | 40-60 |
| **New events** | 4 new NPCs | 250-350 |
| **Total (initial visit)** | | **~1,750-2,250** |

This estimate covers dialogue only — no system messages, item descriptions, or battle text. The initial visit is deliberately light. The player should spend more time in the Forest battling and exploring than reading dialogue in the city.
