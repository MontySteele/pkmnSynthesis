#!/bin/bash
# Pre-commit hook for Pokemon: Synthesis
#
# Runs validators that DON'T require game_data/ (which is gitignored and
# only available at build time). These catch structural issues in the
# dialogue JSON files before they're committed.
#
# Install: bash tools/install_hooks.sh

set -e

PROJECT_DIR="$(git rev-parse --show-toplevel)"
FAILED=0

echo "=== Pre-commit: Running dialogue conflict check ==="
if ! ruby "$PROJECT_DIR/tools/validate_conflicts.rb"; then
  FAILED=1
fi

echo ""
echo "=== Pre-commit: Running JoiPlay patcher tests ==="
if ! ruby "$PROJECT_DIR/tools/test_joiplay_patches.rb"; then
  FAILED=1
fi

echo ""
echo "=== Pre-commit: Validating dialogue JSON schema ==="
if ! ruby "$PROJECT_DIR/tools/validate_dialogue_schema.rb"; then
  FAILED=1
fi

if [ $FAILED -ne 0 ]; then
  echo ""
  echo "Pre-commit checks FAILED. Fix the issues above and try again."
  exit 1
fi

echo ""
echo "All pre-commit checks passed."
