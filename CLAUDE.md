# CLAUDE.md — Project Context for AI Assistants

## What This Project Is

Pokemon: Synthesis is a narrative overhaul mod for **Pokemon Infinite Fusion** (an RPG Maker XP fangame). It replaces dialogue across 300+ maps with an original story. The mod works by injecting modified dialogue into the original game's `.rxdata` files using custom Ruby tooling.

## Repository Layout

```
dialogue_changes/       # 59 JSON files defining dialogue modifications per map/area
tools/                  # Ruby scripts for injection, validation, patching, and testing
docs/                   # Story bible, city plans, roadmap, technical reference
game_data/              # CLONED AT BUILD TIME — the original Pokemon Infinite Fusion repo
                        #   (git clone --depth 1 from infinitefusion/infinitefusion-e18)
                        #   This is the working copy that gets modified by injection.
build_and_launch.sh     # Main entry point: clone game, build mkxp-z, inject dialogue, launch
play.bat                # Windows: auto-installs deps + runs build_and_launch.sh
```

## Build Flow

`./build_and_launch.sh` does these steps:
1. **Clone** the original game into `game_data/` (skips if already present)
2. **Build mkxp-z** (open-source RGSS player for Linux) or download a prebuilt binary
3. **Back up** original `game_data/Data/` files to `game_data/.originals/`
4. **Inject** all dialogue from `dialogue_changes/*.json` into `game_data/Data/`
5. **Launch** the game

Key flags: `--inject` (re-inject only), `--launch` (launch only), `--build-only`, `--dry-run`, `--mobile`

## Mobile Build (JoiPlay / Android)

`./build_and_launch.sh --mobile` creates a `PokemonSynthesis_Mobile.zip` for Android.

### Critical: JoiPlay Ruby 1.8 Compatibility

JoiPlay's RPG Maker XP plugin uses `libmkxp18.so` which embeds **Ruby 1.8**. The original game scripts use Ruby 1.9+/2.0+ syntax that crashes on Ruby 1.8. The mobile build runs `tools/patch_scripts_for_joiplay.rb` to downgrade syntax.

**The patcher (`tools/patch_scripts_for_joiplay.rb`) handles 23 transformations:**

| # | Transform | Example |
|---|-----------|---------|
| 1 | Safe navigation `&.` | `obj&.method` → `(obj && obj.method)` |
| 2 | Symbol hash keys | `{ key: value }` → `{ :key => value }` |
| 3 | Keyword args in `def` | `def foo(key: default)` → options hash extraction |
| 4 | Encoding/force_encoding | Removed (no-op in 1.8) |
| 5 | Symbol#to_proc | `map(&:method)` → `map { \|x\| x.method }` |
| 6 | `chomp: true` | `readlines(f, chomp: true)` → `readlines(f).map{...}` |
| 7 | Trailing commas | `foo(a, b,)` → `foo(a, b)` |
| 8 | Double splat `**kwargs` | Removed |
| 9 | Leading-dot chains | `\n  .method` → joined to previous line |
| 10 | Lookbehind regex | `(?<=X)` → `(X)` |
| 11 | Regex literal braces | `/{WORD}/` → `/\{WORD\}/` |
| 12 | Required after optional params | `def f(a=1, b)` → `def f(b, a=1)` |
| 13 | `deprecate_constant` | Commented out (Ruby 2.3+) |
| 14 | Private `define_method` | `obj.define_method(m)` → `obj.send(:define_method, m)` |
| 15 | `File.exists?` | → `File.exist?` (`exists?` removed in Ruby 3.0+; `exist?` works everywhere) |
| 16 | `.each_char` | → `.split('').each` |
| 17 | `Array#prepend` | → `Array#unshift` |
| 18 | `Dir.exist?`/`Dir.exists?` | → `File.directory?` (`Dir.exist?` not in Ruby 1.8; `Dir.exists?` removed in 3.0; `File.directory?` works everywhere) |
| 19 | `.match?` | → `.match` (`match?` is Ruby 2.4+; `match` works in all versions) |
| 20 | `.to_h` | → `.inject({}) { \|h,(k,v)\| h[k]=v; h }` (`Array#to_h` is Ruby 2.1+) |
| 21 | `.bytesize` | → `.length` (in Ruby 1.8, `String#length` is byte length) |
| 22 | `.bytes` | → `.unpack('C*')` (`String#bytes` is Ruby 1.9+) |
| 23 | `.key?` | → `.has_key?` (`Hash#key?` is Ruby 1.9+; `has_key?` works in all versions) |

### Key Lesson: exist? vs exists?

This was a major debugging saga with three wrong turns:
- **Commit 2313ec3**: Added `exist?` → `exists?` (assumed Ruby 1.8 only has `exists?`)
- **Commit ed2889c**: Disabled conversion (user reported `exists?` undefined on JoiPlay)
- **Commit 80def0e**: Re-enabled `exist?` → `exists?` (wrong — re-introduced the crash)
- **Current fix**: Reversed direction to `exists?` → `exist?`

The root cause: JoiPlay may load **`libmkxp30.so` (Ruby 3.0)**, not just `libmkxp18.so`. In Ruby 3.0, `exists?` was **removed entirely**. But there's a second problem: **`Dir.exist?` was only added in Ruby 1.9** — it doesn't exist in Ruby 1.8 at all! So neither `Dir.exist?` nor `Dir.exists?` works across all versions.

**Rules:**
- `File.exists?` → `File.exist?` (works in Ruby 1.8 through 3.x)
- `Dir.exist?` / `Dir.exists?` → `File.directory?` (works in ALL Ruby versions)
- Never use `Dir.exist?` or `Dir.exists?` — neither is cross-version safe

## Key Tools

| Tool | Purpose |
|------|---------|
| `tools/inject_dialogue.rb` | Injects dialogue JSON into .rxdata map files |
| `tools/extract_dialogue.rb` | Extracts all dialogue from .rxdata to JSON |
| `tools/patch_scripts_for_joiplay.rb` | Patches Ruby 1.9+/2.0+ syntax → Ruby 1.8 for JoiPlay |
| `tools/validate_ruby18_compat.rb` | Validates scripts for Ruby 1.8 compatibility issues |
| `tools/test_joiplay_patches.rb` | Unit tests for the JoiPlay patcher transforms |
| `tools/validate_conflicts.rb` | Checks for cross-file dialogue injection conflicts |
| `tools/validate_fork.rb` | Verifies Silph Co. story fork logic |
| `tools/validate_switches.rb` | Checks switch/variable collision safety |
| `tools/validate_injection.rb` | Validates injection JSON structure |
| `tools/pre_validate.rb` | Pre-commit validation |
| `tools/smoke_test.rb` | Quick smoke test of core functionality |
| `tools/reindex_dialogue.rb` | Reindexes dialogue entries |
| `tools/add_trainer.rb` | Trainer editing utility |
| `tools/rpgmaker_stubs.rb` | RGSS class stubs for loading .rxdata outside RPG Maker |

## Running Validators

```bash
# Ruby 1.8 compatibility check (run against the FULL game scripts)
ruby tools/validate_ruby18_compat.rb game_data/Data/Scripts

# JoiPlay patcher unit tests
ruby tools/test_joiplay_patches.rb

# Dialogue conflict check
ruby tools/validate_conflicts.rb

# Silph Co fork logic
ruby tools/validate_fork.rb game_data

# Switch collision safety
ruby tools/validate_switches.rb game_data

# Full dry-run injection
./build_and_launch.sh --dry-run
```

## Game Data Structure

- Game data is in RPG Maker XP's `.rxdata` format (Ruby Marshal)
- 809 map files, 695 with dialogue, ~27,611 total dialogue lines
- Events contain pages evaluated in **reverse order** (last matching page wins)
- Text blocks: code 101 (first line) + 401 (continuations)
- Choice blocks: code 102 (choices) + 402 (when branch) + 404 (end)
- See `docs/TECHNICAL_REFERENCE.md` for full event command code reference

## Common Pitfalls

1. **exist? vs exists?**: Direction depends on target Ruby version. See "Key Lesson" above.
2. **Patcher runs on a COPY**: `--mobile` copies `game_data/` to `PokemonSynthesis_Mobile/` then patches the copy. The original `game_data/` is never patched for Ruby 1.8.
3. **game_data/ is gitignored**: It's cloned at build time from the upstream repo. Don't commit changes to it.
4. **Multi-pass patcher**: Some transforms (safe navigation, keyword args) require multiple passes or produce output that triggers other transforms. Order matters.
5. **Symbol hash key false positives**: The patcher must avoid converting ternary `:` operators, string contents, and `::` namespace separators.
