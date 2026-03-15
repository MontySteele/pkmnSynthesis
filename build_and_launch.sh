#!/bin/bash
# build_and_launch.sh — Clone game data, get mkxp-z, inject dialogue, and launch.
#
# Usage:
#   ./build_and_launch.sh              # Full setup + launch
#   ./build_and_launch.sh --inject     # Re-inject dialogue only (skip clone/build)
#   ./build_and_launch.sh --launch     # Launch only (skip clone/build/inject)
#   ./build_and_launch.sh --build-only # Clone + get mkxp-z, don't launch
#   ./build_and_launch.sh --dry-run    # Preview injection without modifying files
#   ./build_and_launch.sh --mobile     # Package injected game for Android (JoiPlay)
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

# Detect Windows (Git Bash, MSYS2, Cygwin)
IS_WINDOWS=false
if [[ "${OS:-}" == "Windows_NT" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
  IS_WINDOWS=true
fi

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

download_mkxp() {
  # Try to download a prebuilt mkxp-z release
  local bin_dir="$PROJECT_DIR/mkxp-z-bin"
  mkdir -p "$bin_dir"

  info "Attempting to download prebuilt mkxp-z..."
  local release_url="https://api.github.com/repos/mkxp-z/mkxp-z/releases/latest"
  local download_url

  if command -v curl &>/dev/null; then
    download_url=$(curl -s "$release_url" 2>/dev/null \
      | grep -oP '"browser_download_url":\s*"\K[^"]*linux[^"]*' \
      | head -1)
  elif command -v wget &>/dev/null; then
    download_url=$(wget -qO- "$release_url" 2>/dev/null \
      | grep -oP '"browser_download_url":\s*"\K[^"]*linux[^"]*' \
      | head -1)
  fi

  if [ -z "$download_url" ]; then
    warn "Could not find prebuilt mkxp-z release for Linux."
    return 1
  fi

  info "Downloading: $download_url"
  local archive="$bin_dir/mkxp-z-release.tar.gz"
  if command -v curl &>/dev/null; then
    curl -L -o "$archive" "$download_url" 2>/dev/null
  else
    wget -O "$archive" "$download_url" 2>/dev/null
  fi

  if [ ! -f "$archive" ]; then
    warn "Download failed."
    return 1
  fi

  info "Extracting..."
  tar xzf "$archive" -C "$bin_dir" 2>/dev/null || {
    # Try .zip if tar fails
    unzip -o "$archive" -d "$bin_dir" 2>/dev/null || {
      warn "Could not extract downloaded archive."
      rm -f "$archive"
      return 1
    }
  }
  rm -f "$archive"

  # Find the extracted binary
  local found
  found=$(find "$bin_dir" -name "mkxp-z*" -type f -executable 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    ok "Downloaded mkxp-z: $found"
    return 0
  fi

  # Maybe it's not marked executable yet
  found=$(find "$bin_dir" -name "mkxp-z*" -type f 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    chmod +x "$found"
    ok "Downloaded mkxp-z: $found"
    return 0
  fi

  warn "Downloaded archive but no mkxp-z binary found inside."
  return 1
}

build_mkxp_from_source() {
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
}

build_mkxp() {
  # On Windows, the game runs natively via Game.exe — no mkxp-z needed
  if $IS_WINDOWS; then
    ok "Windows detected — Game.exe will be used directly (no mkxp-z needed)"
    return
  fi

  # Check if we already have a usable binary
  if find_mkxp_binary; then
    ok "mkxp-z binary already available: $MKXP_BIN"
    return
  fi

  # Try downloading a prebuilt binary first
  if download_mkxp && find_mkxp_binary; then
    ok "Using downloaded mkxp-z: $MKXP_BIN"
    return
  fi

  # Fall back to building from source
  warn "Prebuilt download failed. Attempting to build from source..."
  if build_mkxp_from_source && find_mkxp_binary; then
    ok "mkxp-z built successfully: $MKXP_BIN"
    return
  fi

  # Nothing worked — give clear instructions
  echo ""
  echo -e "${RED}═══════════════════════════════════════════════${NC}"
  echo -e "${RED}  Could not obtain mkxp-z${NC}"
  echo -e "${RED}═══════════════════════════════════════════════${NC}"
  echo ""
  echo "mkxp-z is the open-source RGSS player needed to run the game on Linux."
  echo ""
  echo "Options:"
  echo "  1. Download manually from: https://github.com/mkxp-z/mkxp-z/releases"
  echo "     Place the binary at: $PROJECT_DIR/mkxp-z-bin/mkxp-z"
  echo "     Then run: ./build_and_launch.sh --launch"
  echo ""
  echo "  2. Use Wine instead:"
  echo "     sudo apt install wine"
  echo "     ./build_and_launch.sh --launch"
  echo ""
  echo "  3. Fix build dependencies and retry:"
  echo "     ./build_and_launch.sh"
  echo ""
  exit 1
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

  # Remove encrypted archive so game reads loose Data/ files.
  # RPG Maker XP packages data into Game.rgssad — if present, Game.exe
  # reads from it instead of the individual .rxdata files we modify.
  for archive in "$GAME_DIR"/Game.rgssad "$GAME_DIR"/Game.rgss2a "$GAME_DIR"/Game.rgss3a; do
    if [ -f "$archive" ]; then
      info "Renaming $(basename "$archive") so game reads loose Data files..."
      mv "$archive" "${archive}.bak"
    fi
  done

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
    # Also back up trainers.dat for trainer modifications
    if [ -f "$DATA_DIR/trainers.dat" ] && [ ! -f "$backup_dir/trainers.dat" ]; then
      cp "$DATA_DIR/trainers.dat" "$backup_dir/trainers.dat"
    fi
    ok "Originals backed up to $backup_dir"
  fi

  # Restore from backups before injecting (ensures clean injection)
  info "Restoring original files before injection..."
  for bak in "$backup_dir"/*.rxdata "$backup_dir"/trainers.dat; do
    [ -f "$bak" ] && cp "$bak" "$DATA_DIR/$(basename "$bak")"
  done

  # Add Synthesis trainer entries (e.g., Archer v1 for Silph fork)
  if [ -f "$PROJECT_DIR/tools/add_trainer.rb" ]; then
    info "Adding Synthesis trainer entries..."
    ruby "$PROJECT_DIR/tools/add_trainer.rb" "$GAME_DIR"
  fi

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
  # ── Windows: launch Game.exe directly ──
  if $IS_WINDOWS; then
    if [ -f "$GAME_DIR/Game.exe" ]; then
      info "Launching Pokemon: Synthesis via Game.exe..."
      cd "$GAME_DIR"
      start "" "Game.exe" 2>/dev/null || cmd //c start "" "Game.exe" 2>/dev/null || ./Game.exe
      return
    else
      error "Game.exe not found in $GAME_DIR. Re-run without flags to clone game data first."
    fi
  fi

  # ── Linux: use mkxp-z or Wine ──
  if ! find_mkxp_binary; then
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

  local log_file="$PROJECT_DIR/launch.log"

  info "Launching Pokemon: Synthesis..."
  info "Log file: $log_file"
  cd "$GAME_DIR"
  "$MKXP_BIN" 2>&1 | tee "$log_file"
  local exit_code=${PIPESTATUS[0]}

  if [ $exit_code -ne 0 ]; then
    echo ""
    warn "mkxp-z exited with code $exit_code. Check $log_file for details."
    echo ""
    echo "Common fixes:"
    echo "  1. Missing fonts — copy Windows Fonts/ to $GAME_DIR/Fonts/"
    echo "  2. Missing RGSS RTP — ensure the game's Audio/Graphics folders are complete"
    echo "  3. Try Wine instead: sudo apt install wine && ./build_and_launch.sh --launch"
    echo ""
    echo "Full log saved to: $log_file"
  fi
}

# ─── Mobile packaging (JoiPlay / Android) ─────────────────────────────────────

package_mobile() {
  if [ ! -d "$DATA_DIR" ]; then
    error "Game data not found. Run './build_and_launch.sh' first to clone and inject."
  fi

  local mobile_dir="$PROJECT_DIR/PokemonSynthesis_Mobile"
  local zip_name="PokemonSynthesis_Mobile.zip"

  info "Preparing mobile package..."

  # Clean previous mobile build
  rm -rf "$mobile_dir"
  mkdir -p "$mobile_dir"

  # Copy only what the game needs at runtime — skip build artifacts,
  # backups, .git, Windows binaries, and the encrypted archive
  # (Game.rgssad would override our injected dialogue).
  info "Copying game data..."
  cp -r "$GAME_DIR/Data"      "$mobile_dir/Data"
  cp -r "$GAME_DIR/Graphics"  "$mobile_dir/Graphics"  2>/dev/null || true
  cp -r "$GAME_DIR/Audio"     "$mobile_dir/Audio"      2>/dev/null || true
  cp -r "$GAME_DIR/Fonts"     "$mobile_dir/Fonts"      2>/dev/null || true

  # Copy Game.ini (required by JoiPlay to identify the game)
  [ -f "$GAME_DIR/Game.ini" ] && cp "$GAME_DIR/Game.ini" "$mobile_dir/"

  # Copy script archive if present (Scripts.rxdata holds RGSS scripts)
  [ -f "$DATA_DIR/Scripts.rxdata" ] && cp "$DATA_DIR/Scripts.rxdata" "$mobile_dir/Data/" 2>/dev/null || true

  # Include setup instructions
  cp "$PROJECT_DIR/MOBILE_SETUP.txt" "$mobile_dir/" 2>/dev/null || true

  # Remove things JoiPlay doesn't need that may have been copied
  rm -rf "$mobile_dir"/.git \
         "$mobile_dir"/.originals \
         "$mobile_dir"/*.exe \
         "$mobile_dir"/*.dll \
         "$mobile_dir"/System \
         "$mobile_dir"/Game.rgssad \
         "$mobile_dir"/Game.rgss2a \
         "$mobile_dir"/Game.rgss3a \
         2>/dev/null || true

  # Create the ZIP (use max compression)
  info "Creating $zip_name (this may take a minute)..."
  cd "$PROJECT_DIR"
  if command -v zip &>/dev/null; then
    zip -9 -r -q "$zip_name" "$(basename "$mobile_dir")"
  elif command -v tar &>/dev/null; then
    tar czf "${zip_name%.zip}.tar.gz" "$(basename "$mobile_dir")"
    zip_name="${zip_name%.zip}.tar.gz"
  else
    error "Neither zip nor tar found. Install zip: sudo apt install zip"
  fi

  # Clean up the staging directory
  rm -rf "$mobile_dir"

  local size
  size=$(du -h "$PROJECT_DIR/$zip_name" | cut -f1)
  echo ""
  ok "Mobile package created: $zip_name ($size)"
  echo ""
  echo "To play on Android:"
  echo "  1. Transfer $zip_name to the phone"
  echo "  2. Extract it to internal storage (NOT Google Drive or SD card)"
  echo "  3. Install JoiPlay + RPG Maker XP plugin from the Play Store"
  echo "  4. In JoiPlay, tap '+', set the executable to Game.exe, and"
  echo "     point the game folder to the extracted PokemonSynthesis_Mobile directory"
  echo ""
  echo "See MOBILE_SETUP.txt for detailed instructions."
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
    --mobile)
      clone_game
      inject_dialogue
      package_mobile
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
