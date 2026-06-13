#!/usr/bin/env bash
# Downloads and caches a headless-capable Godot binary used for imports and tests.
set -euo pipefail

GODOT_VERSION="4.4.1-stable"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/.godot-bin"
GODOT_BIN="$BIN_DIR/godot"

if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "4.4.1"; then
    echo "Godot $GODOT_VERSION already installed at $GODOT_BIN"
    exit 0
fi

mkdir -p "$BIN_DIR"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
echo "Downloading Godot $GODOT_VERSION ..."
curl -sL -o "$BIN_DIR/godot.zip" "$URL"
unzip -o -q "$BIN_DIR/godot.zip" -d "$BIN_DIR"
mv "$BIN_DIR/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
rm "$BIN_DIR/godot.zip"
chmod +x "$GODOT_BIN"
"$GODOT_BIN" --version
