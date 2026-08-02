#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_LINK="$HOME/.local/bin/ai-sessions"

echo "Installing ai-sessions..."

mkdir -p "$HOME/.local/bin"
if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
elif [[ -e "$BIN_LINK" ]]; then
    echo "error: $BIN_LINK exists and is not a symlink, skipping" >&2
    exit 1
fi
ln -s "$SCRIPT_DIR/ai-sessions" "$BIN_LINK"
chmod +x "$SCRIPT_DIR/ai-sessions"
echo "  Linked $BIN_LINK -> $SCRIPT_DIR/ai-sessions"

echo "Done! Make sure ~/.local/bin is on your PATH."
