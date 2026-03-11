# Pokemon: Synthesis

A narrative overhaul mod for Pokemon Infinite Fusion, replacing dialogue across 300+ maps with an original story about the Pokemon League, Team Rocket, and the cost of power.

## Quick Start

### Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt install git build-essential cmake meson autoconf automake libtool \
  pkg-config ruby bison zlib1g-dev libbz2-dev xorg-dev libgl1-mesa-dev \
  libasound2-dev libpulse-dev xxd
```

**Fedora:**
```bash
sudo dnf install git @development-tools gcc g++ libstdc++-static cmake meson \
  autoconf automake libtool pkg-config ruby bison zlib-devel bzip2-devel \
  xorg-x11-server-devel libXext-devel mesa-libGL-devel alsa-lib-devel \
  pulseaudio-libs-devel perl-FindBin vim-common
```

### Build and Play

```bash
# Full setup: clone game data, build mkxp-z, inject dialogue, and launch
./build_and_launch.sh
```

This will:
1. Clone the Pokemon Infinite Fusion game data
2. Download mkxp-z (the open-source RGSS player for Linux), or build from source as fallback
3. Back up original game files
4. Inject all Synthesis dialogue into the game data
5. Launch the game

If the automatic mkxp-z download doesn't work, you can also:
- Download it manually from https://github.com/mkxp-z/mkxp-z/releases and place the binary at `mkxp-z-bin/mkxp-z`
- Or install Wine (`sudo apt install wine`) as a fallback — the launcher detects it automatically

### Other Options

```bash
# Re-inject dialogue only (after editing dialogue files)
./build_and_launch.sh --inject

# Launch without rebuilding or re-injecting
./build_and_launch.sh --launch

# Clone + build mkxp-z without launching
./build_and_launch.sh --build-only

# Preview what injection would do without modifying files
./build_and_launch.sh --dry-run
```

### Using Wine (alternative)

If you can't build mkxp-z, the game can also run via Wine:
```bash
sudo apt install wine
./build_and_launch.sh --launch
```
The launcher will automatically fall back to Wine if no mkxp-z binary is found.

## Project Structure

```
dialogue_changes/    # JSON files defining dialogue modifications (59 files)
tools/               # Ruby scripts for injection, validation, and trainer editing
docs/                # Story bible, city plans, technical docs (SPOILERS)
build_and_launch.sh  # Main entry point
```

## For Playtesters

Just run `./build_and_launch.sh` and play. Stay out of `docs/` and `dialogue_changes/` to avoid spoilers.

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
```
