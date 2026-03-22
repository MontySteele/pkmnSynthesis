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

### Critical: JoiPlay Ruby 1.9 Compatibility

JoiPlay's RPG Maker XP plugin with **"Use Ruby 1.8" OFF** loads `libmkxp19.so` which embeds **Ruby 1.9**. The original game scripts use Ruby 2.0+ syntax that crashes on Ruby 1.9. The mobile build runs `tools/patch_scripts_for_joiplay.rb` to downgrade syntax.

**The patcher (`tools/patch_scripts_for_joiplay.rb`) handles 14 transformations:**

| # | Transform | Example |
|---|-----------|---------|
| 1 | Safe navigation `&.` | `obj&.method` → `(obj && obj.method)` |
| 2 | Keyword args in `def` | `def foo(key: default)` → options hash extraction |
| 3 | Double splat `**kwargs` | Removed |
| 4 | Leading-dot chains | `\n  .method` → joined to previous line |
| 5 | `.match?` | → `.match` (`match?` is Ruby 2.4+; `match` works in all versions) |
| 6 | `deprecate_constant` | Commented out (Ruby 2.3+) |
| 7 | `.to_h` | → `.inject({}) { \|h,(k,v)\| h[k]=v; h }` (`Array#to_h` is Ruby 2.1+) |
| 8 | `chomp: true` | `readlines(f, chomp: true)` → `readlines(f).map{...}` |
| 9 | `Array#prepend` | → `Array#unshift` (`prepend` is Ruby 2.5+) |
| 10 | Private `define_method` | `obj.define_method(m)` → `obj.send(:define_method, m)` |
| 11 | `File.exists?` | → `File.exist?` (`exists?` removed in Ruby 3.0+; `exist?` works everywhere) |
| 12 | `Dir.exist?`/`Dir.exists?` | → `File.directory?` (cross-version safe) |
| 13 | `File.write` | → `File.open(p,'w'){...}` (`File.write` is Ruby 1.9.3 only) |
| 14 | Backslash paths | `"Graphics\\Battlers\\"` → `"Graphics/Battlers/"` (Linux/Android) |

**Dropped transforms** (available in Ruby 1.9, were only needed for Ruby 1.8 target):
Symbol hash keys, Encoding/force\_encoding, Symbol#to\_proc (&:method), .bytesize, .bytes, .each\_char, .key?, lookbehind regex, regex brace escaping, required-after-optional params, trailing commas.

### Additional mobile fixes (in build_and_launch.sh):

- **005_Deprecation.rb**: Replaced with a no-op stub (uses Ruby 2.0+ keyword args too complex for regex patching)
- **Ruby 2.x polyfills**: Injected as `000_Ruby19_Polyfills.rb` — provides `Comparable#clamp`, `Integer#digits`, `Module#method_added` hook to make `pb*` methods public (RGSS doesn't enforce visibility but JoiPlay does — 20 game files use bare `private` at class level), and `Kernel.method_missing` for private method forwarding
- **OverworldShadows.rb**: Nil guard for `@charbitmap` — prevents "private method `disposed?` called for nil:NilClass" crash during sprite initialization
- **IntroScreen.rb**: GenOneStyle method fix — moves `dispose`/`disposed?`/`wait` from top-level to instance methods
- **Screen dimensions**: Patched to 640x480 to match JoiPlay native resolution
- **PokemonSystem**: Defaults `on_mobile=true` for correct viewport positioning

### Key Lesson: exist? vs exists?

This was a major debugging saga with three wrong turns:
- **Commit 2313ec3**: Added `exist?` → `exists?` (assumed Ruby 1.8 only has `exists?`)
- **Commit ed2889c**: Disabled conversion (user reported `exists?` undefined on JoiPlay)
- **Commit 80def0e**: Re-enabled `exist?` → `exists?` (wrong — re-introduced the crash)
- **Current fix**: Reversed direction to `exists?` → `exist?`

The root cause: JoiPlay may load **`libmkxp30.so` (Ruby 3.0)**, not just `libmkxp19.so`. In Ruby 3.0, `exists?` was **removed entirely**. But there's a second problem: **`Dir.exist?` was only added in Ruby 1.9** — it doesn't exist in Ruby 1.8 at all! So neither `Dir.exist?` nor `Dir.exists?` works across all versions.

**Rules:**
- `File.exists?` → `File.exist?` (works in Ruby 1.8 through 3.x)
- `Dir.exist?` / `Dir.exists?` → `File.directory?` (works in ALL Ruby versions)
- Never use `Dir.exist?` or `Dir.exists?` — neither is cross-version safe

## Key Tools

| Tool | Purpose |
|------|---------|
| `tools/inject_dialogue.rb` | Injects dialogue JSON into .rxdata map files |
| `tools/extract_dialogue.rb` | Extracts all dialogue from .rxdata to JSON |
| `tools/patch_scripts_for_joiplay.rb` | Patches Ruby 2.0+ syntax → Ruby 1.9 for JoiPlay |
| `tools/validate_ruby18_compat.rb` | Validates patched scripts for Ruby 1.9 compatibility |
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
# Ruby 1.9 compatibility check (run against the FULL game scripts)
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
2. **Patcher runs on a COPY**: `--mobile` copies `game_data/` to `PokemonSynthesis_Mobile/` then patches the copy. The original `game_data/` is never patched for Ruby 1.9.
3. **game_data/ is gitignored**: It's cloned at build time from the upstream repo. Don't commit changes to it.
4. **Multi-pass patcher**: Some transforms (safe navigation, keyword args) require multiple passes or produce output that triggers other transforms. Order matters.
5. **Symbol hash key false positives**: No longer an issue — symbol hash keys are valid Ruby 1.9 syntax and the transform was dropped.
6. **JoiPlay "Use Ruby 1.8" must be OFF**: The mobile build targets Ruby 1.9. Users must disable "Use Ruby 1.8" in JoiPlay's RPG Maker XP plugin settings.
