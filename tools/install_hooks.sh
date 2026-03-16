#!/bin/bash
# Installs the pre-commit hook for this project.
# Usage: bash tools/install_hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HOOK_DIR="$PROJECT_DIR/.git/hooks"

if [ ! -d "$HOOK_DIR" ]; then
  echo "Error: .git/hooks directory not found. Are you in the project root?"
  exit 1
fi

# Install pre-commit hook
cp "$SCRIPT_DIR/pre-commit-hook.sh" "$HOOK_DIR/pre-commit"
chmod +x "$HOOK_DIR/pre-commit"
echo "Installed pre-commit hook to $HOOK_DIR/pre-commit"
