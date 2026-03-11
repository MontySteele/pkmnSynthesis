# Pokemon: Synthesis — Switch & Variable Plan

All Synthesis switches start at ID 1130 to avoid collision with the base game (last used: 1125).
All Synthesis variables start at ID 340 to avoid collision (last used: 333).

---

## Path Switch (The Fork)

| ID | Name | Description |
|----|------|-------------|
| Switch 1130 | `SYNTH_FORK_CHOSEN` | ON after the Silph Co. fork decision is made |
| Switch 1131 | `SYNTH_GIOVANNI_PATH` | ON = Giovanni Path (player chased Master Ball). OFF = Oak Path (player fought Giovanni). Only meaningful when 1130 is ON. |

**Logic:** Check `1130 ON + 1131 OFF` = Oak Path. Check `1130 ON + 1131 ON` = Giovanni Path.

---

## Positional Choice Switches

These record the player's stance on key narrative questions. They affect NPC dialogue downstream.

| ID | Name | Set Where | Description |
|----|------|-----------|-------------|
| Switch 1132 | `SYNTH_MISTY_REFORMIST` | Cerulean Gym | Player agreed with Misty's reform stance |
| Switch 1133 | `SYNTH_MISTY_CAUTIOUS` | Cerulean Gym | Player sided with League caution |
| Switch 1134 | `SYNTH_NUGGET_JOINED` | Nugget Bridge | Player showed interest in Rocket recruiter's pitch |
| Switch 1135 | `SYNTH_FUJI_BAN` | Lavender Town | Player told Fuji fusion should be banned |
| Switch 1136 | `SYNTH_FUJI_FREE` | Lavender Town | Player told Fuji fusion should be available to everyone |
| Switch 1137 | `SYNTH_FUJI_OVERSIGHT` | Lavender Town | Player told Fuji fusion needs better oversight |
| Switch 1138 | `SYNTH_FUJI_UNSURE` | Lavender Town | Player told Fuji "I don't know anymore" |
| Switch 1139 | `SYNTH_ARIANA_ALLY` | Silph Co. | Ariana stood down (requires 1134 ON or specific Fuji choice) |

---

## Flavor Choice Switches

Quick flags that modify immediate or nearby dialogue but don't affect major story beats.

| ID | Name | Set Where | Description |
|----|------|-----------|-------------|
| Switch 1140 | `SYNTH_OAK_WHY_PROTECT` | Pallet Town (Oak's Lab) | "To protect people" |
| Switch 1141 | `SYNTH_OAK_WHY_EXPLORE` | Pallet Town (Oak's Lab) | "To see the world" |
| Switch 1142 | `SYNTH_OAK_WHY_STRENGTH` | Pallet Town (Oak's Lab) | "To get stronger" |
| Switch 1143 | `SYNTH_OAK_WHY_UNSURE` | Pallet Town (Oak's Lab) | "I don't know yet" |
| Switch 1144 | `SYNTH_SURGE_AGREED` | Vermilion Gym | Player agreed with Surge's militarism |
| Switch 1145 | `SYNTH_SURGE_DISAGREED` | Vermilion Gym | Player disagreed with Surge |
| Switch 1146 | `SYNTH_SURGE_COMPLICATED` | Vermilion Gym | Player said "it's complicated" |
| Switch 1147 | `SYNTH_VROAD_TRUST` | Victory Road | Player said "I trust you" (Oak Path) or "Maybe you're right" (Giovanni Path) |
| Switch 1148 | `SYNTH_VROAD_CHALLENGE` | Victory Road | Player said "I'll come take it" / "You can't stop me" |
| Switch 1149 | `SYNTH_VROAD_MIRROR` | Victory Road | Player said "You sound like him" / "This is different" |

---

## Story Progression Switches

Track which key events the player has completed.

| ID | Name | Description |
|----|------|-------------|
| Switch 1150 | `SYNTH_VISITED_LAVENDER` | Player has entered Lavender Town |
| Switch 1151 | `SYNTH_TOWER_COMPLETE` | Pokemon Tower cleared |
| Switch 1152 | `SYNTH_SILPH_COMPLETE` | Silph Co. event completed (either path) |
| Switch 1153 | `SYNTH_MEWTWO_KNOWN` | Player has learned about Mewtwo (from Ariana, Giovanni, or Oak) |
| Switch 1154 | `SYNTH_OAK_CONFESSION` | Player has heard Oak's full Mewtwo revelation |
| Switch 1155 | `SYNTH_MANSION_JOURNALS` | Player has read the key Cinnabar Mansion journal entries |
| Switch 1156 | `SYNTH_CHAMPION_DEFEATED` | Player defeated the rival Champion |
| Switch 1157 | `SYNTH_CAVE_ENTERED` | Player entered Cerulean Cave for the ending |

---

## Variables

| ID | Name | Description |
|----|------|-------------|
| Variable 340 | `SYNTH_OAK_CHOICE` | Oak's "why be a trainer" choice (1=protect, 2=explore, 3=strength, 4=unsure). Redundant with switches but useful for conditional branches with 4+ options. |
| Variable 341 | `SYNTH_FUJI_CHOICE` | Fuji's fusion stance choice (1=ban, 2=free, 3=oversight, 4=unsure) |
| Variable 342 | `SYNTH_MISTY_CHOICE` | Misty's regulation stance (1=reform, 2=caution, 3=undecided) |
| Variable 343 | `SYNTH_SURGE_CHOICE` | Surge response (1=agree, 2=disagree, 3=complicated) |
| Variable 344 | `SYNTH_VROAD_CHOICE` | Victory Road response (1-4, varies by path) |

---

## Switch Dependency Map

```
SYNTH_FORK_CHOSEN (1130)
├── Required for: All path-variant dialogue
└── SYNTH_GIOVANNI_PATH (1131)
    ├── OFF (Oak Path) → Giovanni fight aftermath, rival has Ball
    │   ├── Fuchsia rival: "hope" vs "action" conversation
    │   ├── Viridian Giovanni: sneers, hopes rival succeeds
    │   ├── Victory Road: rival explains reform plan
    │   └── Champion: rival holds Ball, idealist-gone-far
    └── ON (Giovanni Path) → Archer fight, player has Ball
        ├── Fuchsia rival: wary of player, Giovanni mirror
        ├── Viridian Giovanni: furious player took "his" Ball
        ├── Victory Road: rival will stop player
        └── Champion: rival as last line of defense

SYNTH_NUGGET_JOINED (1134) + SYNTH_FUJI_* (1135-1138)
└── Determines: SYNTH_ARIANA_ALLY (1139) at Silph Co.
    └── Ariana ally: Mewtwo named early, smoother Silph progression

SYNTH_MEWTWO_KNOWN (1153)
└── Gates: NPC dialogue changes after Mewtwo reveal
    ├── Cerulean Cave guard dialogue changes
    ├── Cinnabar NPCs reference it
    └── Sabrina dialogue unlocked
```

---

## Reserved Range

Switches 1158–1175 and Variables 345–360 are reserved for future use (additional flavor flags, quest tracking, etc.)
