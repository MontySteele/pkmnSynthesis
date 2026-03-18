#!/bin/bash
# build_transplanted.sh — Clone game data, transplant map events, then run normal build.
#
# Usage:
#   ./build_transplanted.sh              # Transplant + full build + launch
#   ./build_transplanted.sh --inject     # Pass --inject to build_and_launch.sh
#   ./build_transplanted.sh --launch     # Pass --launch to build_and_launch.sh
#   ./build_transplanted.sh --dry-run    # Pass --dry-run to build_and_launch.sh
#   ./build_transplanted.sh --mobile     # Pass --mobile to build_and_launch.sh
#   ./build_transplanted.sh --retransplant  # Force re-clone + re-transplant
#   ./build_transplanted.sh --validate-only # Run validators, no build/launch
#
# This wrapper:
#   1. Clones game_data if not present (reuses build_and_launch.sh logic)
#   2. Runs the map transplant (transplant_events.rb)
#   3. Creates a .transplanted marker so the step is idempotent
#   4. Passes all flags through to build_and_launch.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$PROJECT_DIR/game_data"
DATA_DIR="$GAME_DIR/Data"
MARKER="$GAME_DIR/.transplanted"
SPEC_FILE="$PROJECT_DIR/transplant_full_spec.json"
REPORT_FILE="$PROJECT_DIR/transplant_full_report.json"

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

# ─── Step 2: Transplant map events ───────────────────────────────────────────

transplant_events() {
  if [ -f "$MARKER" ]; then
    ok "Maps already transplanted (marker: $MARKER)"
    return
  fi

  if [ ! -f "$SPEC_FILE" ]; then
    error "Transplant spec not found: $SPEC_FILE"
  fi

  if [ ! -d "$DATA_DIR" ]; then
    error "Game data not found at $DATA_DIR. Cannot transplant."
  fi

  info "Running map transplant..."
  info "Spec: $(basename "$SPEC_FILE")"

  local report
  report=$(ruby "$PROJECT_DIR/tools/transplant_events.rb" "$GAME_DIR" "$SPEC_FILE") || \
    error "Map transplant failed. Check output above."

  # Save the report
  echo "$report" > "$REPORT_FILE"
  ok "Transplant report saved to $(basename "$REPORT_FILE")"

  # Show summary from report
  local total warnings
  total=$(echo "$report" | ruby -rjson -e 'r = JSON.parse(STDIN.read); puts r["summary"]["total_transplants"]' 2>/dev/null || echo "?")
  warnings=$(echo "$report" | ruby -rjson -e 'r = JSON.parse(STDIN.read); puts r["summary"]["total_warnings"]' 2>/dev/null || echo "?")
  ok "Transplanted $total maps ($warnings warnings)"

  # Create the marker with metadata for reproducibility
  local spec_hash
  spec_hash=$(sha256sum "$SPEC_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  cat > "$MARKER" << EOF
transplanted_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
spec_file=$(basename "$SPEC_FILE")
spec_hash=$spec_hash
transplants=$total
warnings=$warnings
EOF
  ok "Marker created: $MARKER"
}

# ─── Validation suite ─────────────────────────────────────────────────────────

run_validators() {
  if [ ! -d "$DATA_DIR" ]; then
    error "Game data not found at $DATA_DIR. Run a full build first."
  fi

  echo ""
  echo "═══════════════════════════════════════════════"
  echo "  Transplant Validation Suite"
  echo "═══════════════════════════════════════════════"
  echo ""

  local pass=0
  local fail=0

  # 1. Transplant-specific validator
  if [ -f "$REPORT_FILE" ]; then
    info "Running transplant validator..."
    if ruby "$PROJECT_DIR/tools/validate_transplant.rb" "$GAME_DIR" "$REPORT_FILE"; then
      ok "validate_transplant.rb passed"
      pass=$((pass + 1))
    else
      warn "validate_transplant.rb FAILED"
      fail=$((fail + 1))
    fi
  else
    warn "Transplant report not found ($REPORT_FILE) — skipping validate_transplant.rb"
  fi

  echo ""

  # 2. Per-map structural validation (transplanted maps only)
  if [ -f "$REPORT_FILE" ]; then
    info "Running validate_map.rb against transplanted maps..."
    local map_ids
    map_ids=$(ruby -rjson -e '
      r = JSON.parse(File.read(ARGV[0]))
      r["transplants"].each { |t| puts t["output_map_id"] }
    ' "$REPORT_FILE" 2>/dev/null | sort -u)

    local map_pass=0
    local map_fail=0
    for mid in $map_ids; do
      local map_file
      map_file=$(printf "%s/Map%03d.rxdata" "$DATA_DIR" "$mid")
      if [ -f "$map_file" ]; then
        if ruby "$PROJECT_DIR/tools/validate_map.rb" "$GAME_DIR" "$map_file" > /dev/null 2>&1; then
          map_pass=$((map_pass + 1))
        else
          map_fail=$((map_fail + 1))
        fi
      fi
    done

    if [ $map_fail -eq 0 ]; then
      ok "validate_map.rb: $map_pass maps passed"
      pass=$((pass + 1))
    else
      warn "validate_map.rb: $map_fail maps FAILED ($map_pass passed)"
      fail=$((fail + 1))
    fi
  fi

  echo ""

  # 3. Injection validation (dry-run mode)
  info "Running validate_injection.rb (dry-run)..."
  if ruby "$PROJECT_DIR/tools/validate_injection.rb" --all "$DATA_DIR" > /dev/null 2>&1; then
    ok "validate_injection.rb passed"
    pass=$((pass + 1))
  else
    warn "validate_injection.rb FAILED"
    fail=$((fail + 1))
  fi

  echo ""

  # 4. Switch collision check
  info "Running validate_switches.rb..."
  if ruby "$PROJECT_DIR/tools/validate_switches.rb" "$GAME_DIR" > /dev/null 2>&1; then
    ok "validate_switches.rb passed"
    pass=$((pass + 1))
  else
    warn "validate_switches.rb FAILED"
    fail=$((fail + 1))
  fi

  echo ""

  # 5. Smoke test
  info "Running smoke_test.rb..."
  if ruby "$PROJECT_DIR/tools/smoke_test.rb" "$DATA_DIR" > /dev/null 2>&1; then
    ok "smoke_test.rb passed"
    pass=$((pass + 1))
  else
    warn "smoke_test.rb FAILED"
    fail=$((fail + 1))
  fi

  echo ""
  echo "═══════════════════════════════════════════════"
  echo -e "  Results: ${GREEN}$pass passed${NC}, ${RED}$fail failed${NC}"
  echo "═══════════════════════════════════════════════"
  echo ""

  if [ $fail -gt 0 ]; then
    exit 1
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local retransplant=false
  local validate_only=false
  local passthrough_args=()

  # Parse our flags, collect the rest for build_and_launch.sh
  for arg in "$@"; do
    case "$arg" in
      --retransplant)
        retransplant=true
        ;;
      --validate-only)
        validate_only=true
        ;;
      *)
        passthrough_args+=("$arg")
        ;;
    esac
  done

  echo "═══════════════════════════════════════════════"
  echo "  Pokemon: Synthesis — Transplanted Build"
  echo "═══════════════════════════════════════════════"
  echo ""

  # --retransplant: nuke game_data and start fresh
  if $retransplant; then
    info "Re-transplant requested. Removing game_data..."
    rm -rf "$GAME_DIR"
    rm -f "$REPORT_FILE"
    ok "game_data and report removed."
  fi

  # --validate-only: just run validators and exit
  if $validate_only; then
    run_validators
    exit 0
  fi

  # Step 1: Ensure game data is present
  clone_game

  # Step 2: Run transplant (idempotent — skips if marker exists)
  transplant_events

  # Step 3: Hand off to build_and_launch.sh with passthrough flags
  info "Handing off to build_and_launch.sh..."
  if [ ${#passthrough_args[@]} -gt 0 ]; then
    exec "$PROJECT_DIR/build_and_launch.sh" "${passthrough_args[@]}"
  else
    exec "$PROJECT_DIR/build_and_launch.sh"
  fi
}

main "$@"
