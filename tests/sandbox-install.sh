#!/usr/bin/env bash
# End-to-end test of `ricing install` in a throwaway HOME.
#
#   tests/sandbox-install.sh
#
# Nothing touches the real ~/.config, ~/.hypr-switch or the running Hyprland
# session: HOME points at a temporary directory, Hyprland is hidden, and no
# package is installed (every package it needs is already present, or ends up
# in the "install later" report). Exits non-zero on the first failed check.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
export LC_ALL=C
export PATH="$REPO/bin:$PATH"

FH="$(mktemp -d "${TMPDIR:-/tmp}/ricecooker-test.XXXXXX")"
trap 'rm -rf "$FH"' EXIT
mkdir -p "$FH/.config/hypr" "$FH/.config/kitty" "$FH/.config/mozilla" "$FH/.local/share" "$FH/repos" "$FH/.hypr-switch"
echo 'hl.config({})' > "$FH/.config/hypr/hyprland.lua"
echo 'font_size 11' > "$FH/.config/kitty/kitty.conf"
echo 'profile' > "$FH/.config/mozilla/p"
echo 'export A=1' > "$FH/.bashrc"
cp -a "$REPO/lib" "$FH/.hypr-switch/lib"
export HOME="$FH"

fail=0
check() {
    local label="$1"; shift
    if "$@"; then echo "  PASS  $label"; else echo "  FAIL  $label"; fail=1; fi
}

ricing bootstrap >/dev/null

# Repo 1: an installer that misbehaves in every way.
R1="$FH/repos/badinstaller"; mkdir -p "$R1/config/hypr" "$R1/config/waybar" "$R1/walls"
cat > "$R1/config/hypr/hyprland.conf" <<'EOF'
$mod = SUPER
general {
    gaps_in = 3
    col.active_border = rgba(ff0000ff) rgba(00ff00ff) 45deg
}
decoration {
    drop_shadow = true
    rounding = 7
}
exec-once = waybar &
exec-once = /home/someoneelse/bin/wall.sh
exec-once = dbus-update-activation-environment --systemd --all
bind = $mod, D, exec, rofi -show drun
windowrulev2 = opacity 0.9 0.9, class:^(kitty)$
monitor = ,1920x1080@144,auto,1
EOF
echo '{"layer":"top","exec":"/home/someoneelse/x.sh"}' > "$R1/config/waybar/config.jsonc"
cat > "$R1/install.sh" <<'EOF'
#!/usr/bin/env bash
set -e
read -rp "go? [y/N] " a; [[ $a == [yY]* ]] || exit 0
sudo pacman -Syu --needed bash coreutils
sudo pacman -Rns bash
mv ~/.config/hypr ~/.config/hypr.bak-123
cp -r config/hypr ~/.config/hypr
cp -r config/waybar ~/.config/waybar
echo "riced" >> ~/.bashrc
hyprctl reload
reboot
false
EOF
echo "# Bad Installer Rice" > "$R1/README.md"
head -c 200000 /dev/urandom > "$R1/walls/wall1.png"

echo "== installer that misbehaves"
ricing install badrice "$R1" -y </dev/null >"$FH/t1.log" 2>&1
S="$HOME/.hypr-switch/shells/badrice"
check "install succeeded"                    test -d "$S/configs/config/hypr"
check "hyprland.conf converted to Lua"        test -f "$S/configs/config/hypr/hyprland.converted.lua"
check "Lua wrapper generated"                 grep -q omarchy_base "$S/configs/config/hypr/hyprland.lua"
check "ricing.conf starts waybar"             grep -qx 'start=waybar' "$S/ricing.conf"
check "foreign /home path rewritten"          bash -c "! grep -rq someoneelse '$S/configs'"
check "installer backup not captured"         bash -c "! ls '$S/configs/config' | grep -q bak"
check "user's .bashrc untouched"              bash -c "! grep -q riced '$HOME/.bashrc'"
check "ricing's .bashrc kept aside"           grep -q riced "$S/extras/home/.bashrc"
check "links back on the active ricing"       bash -c "readlink '$HOME/.config/hypr' | grep -q shells/default"
check "shared link untouched"                 bash -c "readlink '$HOME/.config/mozilla' | grep -q shells/default"
check "no capture left open"                  test ! -d "$HOME/.hypr-switch/.capture_state"
check "package removal refused"               grep -q 'suppression de paquets refusée' "$FH/t1.log"
check "reboot neutralised"                    grep -q 'reboot ignoré' "$FH/t1.log"

# Repo 2: no installer, HyDE-like nested Configs/.config.
R2="$FH/repos/hydelike"; mkdir -p "$R2/Configs/.config/hypr" "$R2/Configs/.config/rofi" "$R2/Configs/.config/dunst"
cp "$R1/config/hypr/hyprland.conf" "$R2/Configs/.config/hypr/"
echo 'configuration {}' > "$R2/Configs/.config/rofi/config.rasi"
echo '[global]' > "$R2/Configs/.config/dunst/dunstrc"
printf '# HyDE-like\n```\nsudo pacman -S --needed bash \\\n  coreutils definitely-not-a-package-xyz\n```\n' > "$R2/README.md"

echo "== no installer"
ricing install "$R2" -y </dev/null >"$FH/t2.log" 2>&1
S2="$HOME/.hypr-switch/shells/hydelike"
check "name derived from the URL"             test -d "$S2"
check "nested Configs/.config found"          test -d "$S2/configs/config/rofi"
check "not merged with the previous ricing"   test ! -e "$S2/configs/config/waybar"
check "launcher bound to rofi"                grep -q '^bind:menu.root=rofi' "$S2/ricing.conf"
check "notifications bound to dunstctl"       grep -q 'dunstctl' "$S2/ricing.conf"

echo "== reinstall"
ricing install hydelike "$R2" -y </dev/null >/dev/null 2>&1
check "reinstall without --force refused"     test $? -ne 0
ricing install hydelike "$R2" -y --force </dev/null >/dev/null 2>&1
check "reinstall with --force works"          test $? -eq 0

exit $fail
