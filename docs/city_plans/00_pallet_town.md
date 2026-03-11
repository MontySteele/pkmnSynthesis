# Pallet Town & Opening — Narrative Plan

**Phase:** 0 — Opening
**Status:** IMPLEMENTED (pallet_town.json — 195 modifications, 0 failures)
**Maps Covered:** 48 (Player's Room), 43 (Player's House), 42 (Pallet Town), 77 (Oak's Lab), 78 (Route 1)

---

## 1. Overview

### Narrative Role

Pallet Town is the player's home — the last quiet place. Everything that follows in the game is measured against this starting point: the warmth of Mom's kitchen, the excitement of Blue waiting outside, the gravitas of Oak's lab. The opening act establishes the Synthesis world without explaining it: fusion exists, trainers are licensed, Oak is important, and the world outside is bigger and more dangerous than it looks from here.

### Tone

Warm, domestic, tinged with the sense that this peace is borrowed. The opening should feel like the last morning of childhood.

### What the Player Should Feel

- **In the house:** "I'm leaving home. This is exciting and a little sad."
- **Meeting Blue:** "My best friend is here. We're doing this together."
- **In Oak's lab:** "This is real. I'm becoming a trainer. Oak seems... heavy about something."
- **After the choice:** "Why did he ask me that? What does it matter why I want to be a trainer?"
- **After Blue's battle:** "The adventure starts now."

---

## 2. Implementation Summary

### Map 48: Player's Room
- Console, bed, bookshelves, TV — all get environmental flavor text
- TV has a DNA Splicers commercial (first mention of fusion tech as consumer product)
- Stairs NPC reminds player to go downstairs

### Map 43: Player's House
- **Mom (Event 3):** Complete opening scene rewrite
  - Page 0: Trainer license letter arrives. Player reads it aloud. Mom reacts with pride and concern. Names the rival. Sends player to Oak's lab.
  - Page 1: "Professor Oak is waiting" reminder
  - Page 2: Healing + haircut (indices fixed: 7 and 12)
- **Sibling (Event 4):** Gender-variant lines. Excited about player leaving.
- **TV, windows, sink, fridge, kitchen, running shoes:** All get light environmental rewrites

### Map 42: Pallet Town
- **Blue outdoor scene (Event 3):** Childhood friend reunion. "Did you get your letter?" Nostalgic, excited.
- **Oak intro (Event 29):** Prevents player from leaving town without a Pokémon

### Map 77: Oak's Lab
- **Blue in lab (Event 6):** "About time! I've been here since dawn."
- **Oak's main event (Event 7):** Complete 7-page rewrite across all phases:
  - Page 1: Oak arrives, introduces starter selection
  - Page 2: "Go on, choose" + "Take your time"
  - Page 3: Blue's reaction, fusion demo, **"Why be a trainer?" choice** (insert_commands at index 74, indent=1)
  - Pages 5-7: Parcel quest, Pokédex, Poké Balls, DNA Splicers
- **Blue's battle (Events 8/21/43):** Post-fusion-demo challenge. Three variants for starter matchup. Win/lose/no-Pokémon branches.
- **Lab Assistants (Events 5/10-12/17/20):** Synthesis-flavored NPC dialogue
- **Environmental objects:** All 40+ objects get unique descriptions (machines, bookshelves, globe, photograph, TVs, Pokéballs, documents, sink)

### Map 78: Route 1
- **Young trainer (Event 2):** First battle invitation on the road
- **PokéMart employee (Event 3):** DNA Splicers mentioned in inventory

---

## 3. Player Choices

### "Why Be a Trainer?" (Map 77, Event 7, Page 3)
**Type:** Flavor choice (referenced later by rival and Oak)
**Implementation:** insert_commands block before index 74

| Choice | Variable 340 | Switch |
|--------|-------------|--------|
| To protect people | 1 | 1140 |
| To see the world | 2 | 1141 |
| To get stronger | 3 | 1142 |
| I don't know yet | 4 | 1143 |

Oak responds differently to each. The rival references the player's answer later in the game.

---

## 4. Technical Notes

- Mom Page 0 has heavy index shifting due to line-count changes at multiple blocks. Reverse-order processing handles this correctly.
- The insert_commands block is inside an else branch (indent=1), so all inserted commands use indent+1.
- Events 7 and 8 on Map 43 (Windows) have code 111 (conditional branch) at index 0 — the text starts at index 1 with indent=1. Our modifications target the correct indices.
- Validation: 193/195 PASS, 2 expected SKIP (insert_commands index shift)
