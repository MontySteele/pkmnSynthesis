# Pokemon: Synthesis

A narrative overhaul mod for Pokemon Infinite Fusion, replacing dialogue across 300+ maps with an original story about the Pokemon League, Team Rocket, and the cost of power.

## Quick Start

### Windows

Double-click **`play.bat`**. That's it.

On first run it will automatically install Git and Ruby (via winget), clone the game data, inject the Synthesis dialogue, and launch the game. You may see a Windows permission prompt — click Yes.

If the auto-install doesn't work, you can install manually: [Git for Windows](https://git-scm.com/download/win) and [Ruby](https://rubyinstaller.org/) (choose "Ruby+Devkit"), then double-click `play.bat` again.

### Linux

**Prerequisites (Ubuntu/Debian):**
```bash
sudo apt install git ruby
```

**Prerequisites (Fedora):**
```bash
sudo dnf install git ruby
```

```bash
./build_and_launch.sh
```

This will:
1. Clone the Pokemon Infinite Fusion game data
2. Download mkxp-z (the open-source RGSS player for Linux), or build from source as fallback
3. Back up original game files
4. Inject all Synthesis dialogue into the game data
5. Launch the game

If mkxp-z doesn't work, install Wine as a fallback (`sudo apt install wine`) — the launcher detects it automatically.

### Android (JoiPlay)

```bash
./build_and_launch.sh --mobile
```

This creates `PokemonSynthesis_Mobile.zip` — transfer it to your phone and open with JoiPlay + the RPG Maker XP plugin (both free on the Play Store). See `MOBILE_SETUP.txt` for detailed instructions.

### Other Options

```bash
# Re-inject dialogue only (after editing dialogue files)
./build_and_launch.sh --inject

# Launch without rebuilding or re-injecting
./build_and_launch.sh --launch

# Clone + get mkxp-z without launching (Linux only)
./build_and_launch.sh --build-only

# Preview what injection would do without modifying files
./build_and_launch.sh --dry-run
```

## Project Structure

```
dialogue_changes/    # JSON files defining dialogue modifications (59 files)
tools/               # Ruby scripts for injection, validation, and trainer editing
docs/                # Story bible, city plans, technical docs (SPOILERS)
play.bat             # Windows: double-click to play (auto-installs dependencies)
setup_windows.bat    # Windows: standalone dependency installer
build_and_launch.sh  # Linux/macOS/Git Bash entry point
```

## For Playtesters

**Windows:** Double-click `play.bat` and play. **Linux:** Run `./build_and_launch.sh`.

Stay out of `docs/` and `dialogue_changes/` to avoid spoilers.

If something looks wrong in-game, note the map name and NPC, and file an issue.

## Validation

```bash
# Check for cross-file conflicts
ruby tools/validate_conflicts.rb

# Verify Silph Co fork logic
ruby tools/validate_fork.rb game_data

# Check switch collision safety
ruby tools/validate_switches.rb game_data

# Dry-run all injections
./build_and_launch.sh --dry-run

# Check scripts for JoiPlay/Ruby 1.8 compatibility
ruby tools/validate_ruby18_compat.rb game_data/Data/Scripts

# Run JoiPlay patcher unit tests
ruby tools/test_joiplay_patches.rb
```
