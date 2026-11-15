#!/usr/bin/env bash
# ricecooker installer.
#
#   ./install.sh            copy the commands to ~/.local/bin and the lib to ~/.hypr-switch/lib
#   ./install.sh --link     symlink them to this checkout instead (for development:
#                           `git pull` updates the installed commands)
#
# Existing files that differ are backed up to ~/.hypr-switch/.cancelled/ first.
# Nothing in ~/.config is touched: run `ricing bootstrap` yourself afterwards.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${RICECOOKER_BIN:-$HOME/.local/bin}"
STORAGE="$HOME/.hypr-switch"
MODE=copy
[[ "${1:-}" == "--link" ]] && MODE=link

say() { printf '\e[1;35m::\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m::\e[0m %s\n' "$*" >&2; }

[[ $EUID -ne 0 ]] || { echo "run as your user, not root" >&2; exit 1; }

missing=()
for c in bash git lua jq perl; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
if (( ${#missing[@]} )); then
    warn "required: ${missing[*]} — install them first (sudo pacman -S --needed ${missing[*]})"
    exit 1
fi
for c in hyprctl quickshell rofi; do
    command -v "$c" >/dev/null 2>&1 || warn "optional: $c not found (live switching / menu need it)"
done

stamp="$(date +%Y%m%d-%H%M%S)"
backup="$STORAGE/.cancelled/ricecooker-install-$stamp"

place() {
    local src="$1" dest="$2"
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then return 0; fi
        if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
            [[ "$MODE" == copy ]] && return 0
        fi
        mkdir -p "$backup/$(dirname "${dest#"$HOME"/}")"
        mv "$dest" "$backup/${dest#"$HOME"/}"
    fi
    mkdir -p "$(dirname "$dest")"
    if [[ "$MODE" == link ]]; then ln -s "$src" "$dest"; else cp -a "$src" "$dest"; fi
}

say "commands → $BIN_DIR ($MODE)"
for b in ricing ricing-switch omarchy-keymap-generate; do
    chmod +x "$REPO/bin/$b"
    place "$REPO/bin/$b" "$BIN_DIR/$b"
done
# Compatibility alias kept by ricing-switch.
[[ -e "$BIN_DIR/hypr-switch" || -L "$BIN_DIR/hypr-switch" ]] || ln -s ricing-switch "$BIN_DIR/hypr-switch"

say "lib → $STORAGE/lib ($MODE)"
mkdir -p "$STORAGE/lib/wallpaper"
for f in hypr-switch.lua machine.lua conf2lua.lua wallpaper/shell.qml; do
    place "$REPO/lib/$f" "$STORAGE/lib/$f"
done

[[ -d "$backup" ]] && say "previous versions saved in $backup"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in your PATH" ;; esac

echo
if [[ -n "$(ls -A "$STORAGE/shells/default/configs" 2>/dev/null)" ]]; then
    say "already bootstrapped: $(ricing list 2>/dev/null | wc -l) ricing(s). Try: ricing list"
else
    say "next step (once): ricing bootstrap"
    echo "   It moves your current ~/.config into ~/.hypr-switch/shells/default and"
    echo "   replaces each entry with a symlink. Read docs/architecture.md first."
fi
echo "   Then: ricing install <github-url>   ·   ricing switch <name>   ·   ricing help"
