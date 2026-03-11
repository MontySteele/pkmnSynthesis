#!/bin/bash
# build_and_launch.sh — Clone game data, build mkxp-z, inject dialogue, and launch.
#
# Usage:
#   ./build_and_launch.sh              # Full setup + launch
#   ./build_and_launch.sh --inject     # Re-inject dialogue only (skip clone/build)
#   ./build_and_launch.sh --launch     # Launch only (skip clone/build/inject)
#   ./build_and_launch.sh --build-only # Clone + build mkxp-z, don't launch
#
# Prerequisites (Ubuntu/Debian):
#   sudo apt install git build-essential cmake meson autoconf automake libtool \
#     pkg-config ruby bison zlib1g-dev libbz2-dev xorg-dev libgl1-mesa-dev \
#     libasound2-dev libpulse-dev xxd
#
# On Fedora:
#   sudo dnf install git @development-tools gcc g++ libstdc++-static cmake meson \
#     autoconf automake libtool pkg-config ruby bison zlib-devel bzip2-devel \
#     xorg-x11-server-devel libXext-devel mesa-libGL-devel alsa-lib-devel \
#     pulseaudio-libs-devel perl-FindBin vim-common

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$PROJECT_DIR/game_data"
MKXP_DIR="$PROJECT_DIR/mkxp-z"
MKXP_BIN=""
DATA_DIR="$GAME_DIR/Data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Step 1: Clone game data ─────────────────────────────────────────────────

clone_game() {
  if [ -d "$GAME_DIR/Data" ]; then
    ok "Game data already present at $GAME_DIR"
    return
  fi

  info "Cloning Pokemon Infinite Fusion game data..."
  git clone --depth 1 https://github.com/infinitefusion/infinitefusion-e18 "$GAME_DIR"
  ok "Game data cloned."
}

# ─── Step 2: Build mkxp-z ────────────────────────────────────────────────────

check_build_deps() {
  local missing=()
  for cmd in git cmake meson ruby pkg-config autoconf automake libtool bison; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing build dependencies: ${missing[*]}
Install them with:
  Ubuntu/Debian: sudo apt install git build-essential cmake meson autoconf automake libtool pkg-config ruby bison zlib1g-dev libbz2-dev xorg-dev libgl1-mesa-dev libasound2-dev libpulse-dev xxd
  Fedora:        sudo dnf install git @development-tools gcc g++ libstdc++-static cmake meson autoconf automake libtool pkg-config ruby bison zlib-devel bzip2-devel xorg-x11-server-devel libXext-devel mesa-libGL-devel alsa-lib-devel pulseaudio-libs-devel perl-FindBin vim-common"
  fi
}

build_mkxp() {
  # Check if we already have a usable binary
  if find_mkxp_binary; then
    ok "mkxp-z binary already available: $MKXP_BIN"
    return
  fi

  check_build_deps

  if [ ! -d "$MKXP_DIR" ]; then
    info "Cloning mkxp-z..."
    git clone https://github.com/mkxp-z/mkxp-z "$MKXP_DIR"
  fi

  info "Building mkxp-z dependencies (this may take a while)..."
  cd "$MKXP_DIR/linux"
  make

  info "Building mkxp-z..."
  source vars.sh
  cd "$MKXP_DIR"
  meson setup build --bindir=. --prefix="$MKXP_DIR/dist"
  cd build
  ninja
  ninja install

  cd "$PROJECT_DIR"

  if ! find_mkxp_binary; then
    error "mkxp-z build completed but binary not found. Check $MKXP_DIR for build output."
  fi

  ok "mkxp-z built successfully: $MKXP_BIN"
}

find_mkxp_binary() {
  # Search for the mkxp-z binary in common locations
  for candidate in \
    "$MKXP_DIR/dist/mkxp-z" \
    "$MKXP_DIR/dist/mkxp-z.x86_64" \
    "$MKXP_DIR/build/mkxp-z" \
    "$MKXP_DIR/build/mkxp-z.x86_64" \
    "$PROJECT_DIR/mkxp-z-bin/mkxp-z" \
    "$PROJECT_DIR/mkxp-z-bin/mkxp-z.x86_64"; do
    if [ -x "$candidate" ]; then
      MKXP_BIN="$candidate"
      return 0
    fi
  done

  # Also check if the user placed a binary somewhere
  local found
  found=$(find "$PROJECT_DIR" -maxdepth 3 -name "mkxp-z*" -type f -executable 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    MKXP_BIN="$found"
    return 0
  fi

  return 1
}

# ─── Step 3: Back up + inject dialogue ────────────────────────────────────────

inject_dialogue() {
  if [ ! -d "$DATA_DIR" ]; then
    error "Game data not found at $DATA_DIR. Run without --inject first."
  fi

  local changes_dir="$PROJECT_DIR/dialogue_changes"
  local changes_files=("$changes_dir"/*.json)

  if [ ${#changes_files[@]} -eq 0 ] || [ ! -e "${changes_files[0]}" ]; then
    warn "No dialogue change files found in $changes_dir. Skipping injection."
    return
  fi

  # Back up original files on first injection
  local backup_dir="$GAME_DIR/.originals"
  if [ ! -d "$backup_dir" ]; then
    info "Creating backup of original Data/ files..."
    mkdir -p "$backup_dir"
    # Only back up map files that will be modified
    for changes_file in "${changes_files[@]}"; do
      # Extract map IDs from JSON keys
      local map_ids
      map_ids=$(ruby -rjson -e '
        data = JSON.parse(File.read(ARGV[0]))
        (data["maps"] || {}).keys.each { |id| puts "Map%03d.rxdata" % id.to_i }
      ' "$changes_file" 2>/dev/null || true)

      for mapfile in $map_ids; do
        if [ -f "$DATA_DIR/$mapfile" ] && [ ! -f "$backup_dir/$mapfile" ]; then
          cp "$DATA_DIR/$mapfile" "$backup_dir/$mapfile"
        fi
      done
    done
    ok "Originals backed up to $backup_dir"
  fi

  # Restore from backups before injecting (ensures clean injection)
  info "Restoring original files before injection..."
  for bak in "$backup_dir"/*.rxdata; do
    [ -f "$bak" ] && cp "$bak" "$DATA_DIR/$(basename "$bak")"
  done

  # Inject each changes file
  for changes_file in "${changes_files[@]}"; do
    info "Injecting: $(basename "$changes_file")"
    ruby "$PROJECT_DIR/tools/inject_dialogue.rb" "$DATA_DIR" "$changes_file"
  done

  ok "Dialogue injection complete."
}

# ─── Step 4: Generate mkxp.json config ───────────────────────────────────────

generate_config() {
  local config_path="$GAME_DIR/mkxp.json"

  # Only generate if not already present or if ours is newer
  cat > "$config_path" << 'MKXP_CONFIG'
{
    "rgssVersion": 1,
    "gameFolder": ".",
    "anyAltToggleFS": false,
    "smoothScaling": true,
    "smoothScalingMipmaps": false,
    "enableBlitting": true,
    "integerScaling": {
        "active": false,
        "hires": false
    },
    "fixedFramerate": 0,
    "frameSkip": true,
    "syncToRefreshrate": false,
    "solidFonts": false,
    "subImageFix": true,
    "enableHires": false,
    "textInputIndications": "PasswordEntry",
    "gameControllerDBPath": "",
    "SE.sourceCount": 6,
    "BGM.volume": 1.0,
    "SFX.volume": 1.0,
    "customScript": "",
    "preloadScript": [],
    "RTP": [],
    "fontSub": [],
    "rubyLoadpath": [".", "lib"],
    "JITEnable": false,
    "dumpAtlas": false,
    "windowTitle": "Pokemon: Synthesis",
    "fixedAspectRatio": true,
    "defScreenW": 512,
    "defScreenH": 384,
    "screenScaling": 1.5,
    "manualFolderScan": false,
    "pathCache": true,
    "useScriptNames": false,
    "encryptedGraphics": false,
    "encryptedAudio": false,
    "midiSoundFont": "",
    "vsync": true
}
MKXP_CONFIG

  ok "Generated mkxp.json at $config_path"
}

# ─── Step 5: Launch ──────────────────────────────────────────────────────────

launch_game() {
  if ! find_mkxp_binary; then
    # Fallback: try Wine with the Windows Game.exe
    if command -v wine &>/dev/null && [ -f "$GAME_DIR/Game.exe" ]; then
      warn "mkxp-z binary not found. Falling back to Wine..."
      info "Launching with: wine Game.exe"
      cd "$GAME_DIR"
      wine Game.exe
      return
    fi

    error "No mkxp-z binary found and Wine is not available.

Options:
  1. Build mkxp-z:  ./build_and_launch.sh  (runs full setup including build)
  2. Use Wine:      sudo apt install wine && ./build_and_launch.sh --launch
  3. Manual binary: Download or build mkxp-z and place it in:
                    $PROJECT_DIR/mkxp-z-bin/mkxp-z"
  fi

  generate_config

  info "Launching Pokemon: Synthesis..."
  cd "$GAME_DIR"
  "$MKXP_BIN"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local mode="${1:-full}"

  case "$mode" in
    --inject)
      inject_dialogue
      ;;
    --launch)
      launch_game
      ;;
    --build-only)
      clone_game
      build_mkxp
      ;;
    --dry-run)
      clone_game
      info "Dry-run injection preview:"
      for f in "$PROJECT_DIR/dialogue_changes"/*.json; do
        [ -f "$f" ] && ruby "$PROJECT_DIR/tools/inject_dialogue.rb" "$DATA_DIR" "$f" --dry-run
      done
      ;;
    *)
      echo "═══════════════════════════════════════════════"
      echo "  Pokemon: Synthesis — Build & Launch"
      echo "═══════════════════════════════════════════════"
      echo ""
      clone_game
      build_mkxp
      inject_dialogue
      launch_game
      ;;
  esac
}

main "$@"
