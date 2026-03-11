# Pokemon: Synthesis — Technical Reference

## Data Structure Overview

### .rxdata Files (Ruby Marshal Format)
All game data is stored in Ruby's `Marshal.dump` format. To load these files outside RPG Maker XP, you must define stub classes for the RGSS built-in types (see `tools/rpgmaker_stubs.rb`).

### Map Files (`Data/MapXXX.rxdata`)
Each map file deserializes to an `RPG::Map` object containing:
- **`events`**: Hash of `event_id => RPG::Event` — the NPCs, triggers, signs, etc.
- **`data`**: `Table` — the tile layer data (we never modify this)
- Tileset, BGM, BGS, encounter data (we never modify these)

**Total: 809 map files, 695 with dialogue**

### Event Structure
```
RPG::Event
  ├── id, name, x, y
  └── pages: Array<RPG::Event::Page>
        ├── condition (RPG::Event::Page::Condition)
        │     ├── switch1_valid / switch1_id
        │     ├── switch2_valid / switch2_id
        │     ├── variable_valid / variable_id / variable_value
        │     └── self_switch_valid / self_switch_ch
        ├── graphic (RPG::Event::Page::Graphic)
        └── list: Array<RPG::EventCommand>
              ├── code (integer)
              ├── indent (integer)
              └── parameters (array)
```

Pages are evaluated in **reverse order** — the last page whose conditions are met is the active page.

### Event Command Codes (Key Ones)
| Code | Name | Parameters |
|------|------|-----------|
| 101 | Show Text (first line) | `[text_string]` |
| 401 | Show Text (continuation) | `[text_string]` |
| 102 | Show Choices | `[["Choice1", "Choice2"], cancel_type]` |
| 402 | When [Choice] | `[choice_index, "Choice Text"]` |
| 403 | When Cancel | `[]` |
| 108 | Comment (first line) | `[comment_string]` |
| 408 | Comment (continuation) | `[comment_string]` |
| 111 | Conditional Branch | Varies by condition type |
| 121 | Control Switches | `[start_id, end_id, 0=ON/1=OFF]` |
| 122 | Control Variables | `[start_id, end_id, operation, operand_type, operand]` |
| 355 | Script Call (first line) | `[script_string]` |
| 655 | Script Call (continuation) | `[script_string]` |

A text block = one `101` command followed by zero or more `401` continuations.

### MapInfos.rxdata
Hash of `map_id => RPG::MapInfo` with map names and parent hierarchy.

### System.rxdata
Contains switch/variable name arrays. See Switch/Variable Plan below.

### CommonEvents.rxdata
Array of `RPG::CommonEvent` objects — global event logic not tied to a specific map.

---

## Dialogue Inventory

| Metric | Count |
|--------|-------|
| Total map files | 809 |
| Maps with dialogue | 695 |
| Text blocks (Show Text) | 20,632 |
| Choice blocks (Show Choices) | 1,685 |
| Script message calls | 12 |
| Common events with dialogue | 58 |
| Total dialogue lines | ~27,611 |

### Top Maps by Dialogue Volume
| Map | Name | Text Blocks |
|-----|------|------------|
| 077 | Oak's Lab | 227 |
| 038 | Trainer House | 225 |
| 001 | Cerulean City | 179 |
| 024 | Vermillion City Gym | 179 |
| 051 | Pinkan Island | 172 |
| 546 | Fighting Arena | 165 |
| 171 | Route 22 | 162 |
| 221 | Cinnabar Island Gym | 157 |

### Key Story Location Map IDs
| Location | Primary Map IDs |
|----------|----------------|
| Pallet Town | 042, 076, 205 |
| Oak's Lab | 077 (primary), 847 (backup) |
| Pewter City | 091, 093, 380, 386 (gym) |
| Cerulean City | 001, 004 (gym), 005, 387-389 |
| Cerulean Cave | 322, 323, 324 |
| Vermillion City | 019, 022-024 (gym), 037 |
| S.S. Anne | 017, 027-031 |
| Celadon City | 062-064, 095, 414 (gym) |
| Lavender Town | 050, 419, 420 |
| Pokemon Tower | 401-403, 467-469 |
| Saffron City | 108, 120, 141, 152 (gym), 153, 156, 180, 182-184 |
| Silph Co. | 121, 212 |
| Fuchsia City | 087, 472, 479 (gym), 481-482 |
| Cinnabar Island | 098, 125, 189-190, 221 (gym) |
| Cinnabar Lab | 206, 208-209, 703, 721 |
| Viridian City | 079, 083-085 (gym), 710-711 |
| Victory Road | 304, 306-307 |
| Indigo Plateau | 303 |

---

## Switch/Variable Inventory

### Current Usage
- **Switches**: 1,200 slots allocated, ~1,117 named/in use
- **Variables**: 350 slots allocated, ~333 named/in use
- **Free switch range**: 1126–1175+ (50+ slots available)
- **Free variable range**: 334–350+ (17+ slots available)

The switch/variable arrays can be extended simply by adding new entries — there's no hard limit.

### Planned Synthesis Switches (tentative IDs starting at 1130)
| Switch ID | Name | Purpose |
|-----------|------|---------|
| 1130 | SYNTHESIS_PATH_FORK | 0=not yet chosen, ON=Oak Path |
| 1131 | SYNTHESIS_GIOVANNI_PATH | ON=Giovanni Path |
| 1132 | SYNTHESIS_SILPH_COMPLETE | Silph Co. event completed |
| 1133 | SYNTHESIS_POSITIONAL_MISTY | Sided with Misty |
| 1134 | SYNTHESIS_POSITIONAL_BROCK | Chose courier/Brock option |
| 1135 | SYNTHESIS_POSITIONAL_FUJI | Mr. Fuji positional choice made |
| 1136 | SYNTHESIS_NUGGET_JOINED | Player joined Rocket at Nugget Bridge |
| 1137 | SYNTHESIS_MEWTWO_KNOWN | Player has learned about Mewtwo |
| 1138 | SYNTHESIS_VISITED_LAVENDER | Player visited Lavender Town |
| 1139-1149 | Reserved | Future story flags |

*(These IDs are provisional — verify against the game before implementation.)*

---

## Tooling

### extract_dialogue.rb
Extracts all dialogue from map and common event .rxdata files to JSON.

```bash
ruby tools/extract_dialogue.rb game_data/Data dialogue_dump.json
```

Output structure:
```json
{
  "maps": {
    "1": {
      "name": "Cerulean City",
      "events": {
        "27": {
          "name": "EV027",
          "x": 10, "y": 15,
          "pages": {
            "0": {
              "conditions": {},
              "dialogue_blocks": [
                {
                  "start_index": 5,
                  "type": "text",
                  "lines": ["Line 1", "Line 2"]
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

### inject_dialogue.rb
Injects modified dialogue from a JSON file back into .rxdata files.

```bash
ruby tools/inject_dialogue.rb game_data/Data changes.json
ruby tools/inject_dialogue.rb game_data/Data changes.json --dry-run  # preview only
```

The changes JSON uses the same structure as the extraction output. Only entries present in the JSON are modified; everything else is preserved.

Supports four block types:
- **Text blocks** (`"type": "text"`): Modify existing Show Text (101) at `start_index`. Provide `"lines"` array. Handles adding/removing continuation lines (401) automatically.
- **Choice blocks** (`"type": "choices"`): Modify existing Show Choices (102) at `start_index`. Provide `"choices"` array with new labels and optional `"cancel_type"`.
- **Script messages** (`"type": "script_message"`): Modify existing Script (355) at `start_index`. Provide `"lines"` array. Handles adding/removing continuation lines (655).
- **Insert commands** (`"type": "insert_commands"`): Insert new RPG Maker event commands BEFORE `start_index`. Provide `"commands"` array of `{code, indent, parameters}` objects. Supports any RPG Maker XP event command code.

#### Insert Commands — Details

The `insert_commands` block type allows injecting arbitrary event commands without the RPG Maker editor. This is how we implement new choice branches, switch/variable controls, and conditional logic purely through tooling.

Common RPG Maker XP event command codes:
| Code | Name | Parameters |
|------|------|------------|
| 101 | Show Text | `["First line of text"]` |
| 401 | Text continuation | `["Continuation line"]` |
| 102 | Show Choices | `[["Choice1", "Choice2", ...], cancel_type]` |
| 402 | When [Choice] | `[choice_index, "Choice label"]` |
| 404 | End choices | `[]` |
| 121 | Control Switches | `[start_id, end_id, 0=ON / 1=OFF]` |
| 122 | Control Variables | `[start_id, end_id, operation, operand_type, operand]` (operation: 0=set, operand_type: 0=constant) |
| 355 | Script | `["script line"]` |
| 655 | Script continuation | `["continuation"]` |

Indent levels control nesting: top-level commands use `indent: 0`, content inside a choice branch uses `indent: 1`, etc.

Blocks are processed in **reverse order of `start_index`** to avoid index shifts from insertions. At the same index, modifications (text/choices) process before insertions.

Example — inserting a 4-option choice that sets a variable and switches:
```json
{
  "start_index": 74,
  "type": "insert_commands",
  "commands": [
    {"code": 101, "indent": 0, "parameters": ["What drives you to become a trainer?"]},
    {"code": 102, "indent": 0, "parameters": [["To protect people", "To see the world", "To get stronger", "I don't know yet"], 0]},
    {"code": 402, "indent": 0, "parameters": [0, "To protect people"]},
    {"code": 122, "indent": 1, "parameters": [340, 340, 0, 0, 1]},
    {"code": 121, "indent": 1, "parameters": [1140, 1140, 0]},
    {"code": 101, "indent": 1, "parameters": ["Oak nods slowly."]},
    {"code": 402, "indent": 0, "parameters": [1, "To see the world"]},
    {"code": 122, "indent": 1, "parameters": [340, 340, 0, 0, 2]},
    {"code": 121, "indent": 1, "parameters": [1141, 1141, 0]},
    {"code": 404, "indent": 0, "parameters": []}
  ]
}
```

### Round-Trip Verification
- Byte-identical round-trip confirmed on all 809 map files
- Tested: extract → modify one line → inject → re-extract → verify change present

---

## Text Formatting Conventions (Infinite Fusion)
Discovered in existing dialogue:
- `\PN` — Player name
- `\V[N]` — Variable value
- `\C[N]` — Color change (0=default, 1=blue, 2=red, etc.)
- `<fs=N>` — Font size
- `\n` — Line break within a single text command
- UTF-8 encoding (Pokémon appears as `Pok\xC3\xA9mon` in raw bytes)
