#!/usr/bin/env bash
# ricecooker uninstaller: removes the commands and the lib, never your data.
#
# ~/.hypr-switch/shells (every ricing, including 'default' = your original
# ~/.config) is kept, and ~/.config stays a set of symlinks into it. To get
# plain directories back, run `ricing switch default` first, then replace each
# ~/.config/<item> link by a copy of its target yourself.
set -euo pipefail

BIN_DIR="${RICECOOKER_BIN:-$HOME/.local/bin}"
STORAGE="$HOME/.hypr-switch"

if [[ -d "$STORAGE/.capture_state" ]]; then
    echo "A capture is in progress: run 'ricing cancel' first." >&2
    exit 1
fi

for b in ricing ricing-switch omarchy-keymap-generate hypr-switch; do
    if [[ -e "$BIN_DIR/$b" || -L "$BIN_DIR/$b" ]]; then
        rm -f "$BIN_DIR/$b" && echo "removed $BIN_DIR/$b"
    fi
done
rm -rf "$STORAGE/lib" && echo "removed $STORAGE/lib"

echo
echo "Kept: $STORAGE/shells (your ricings and your original config)."
echo "Ricings that load ~/.hypr-switch/lib will need it again if you reinstall."
