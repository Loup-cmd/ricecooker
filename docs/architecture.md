# Architecture

## Le principe en une phrase

Tout `~/.config/<item>` est un **symlink** vers le snapshot d'un ricing propriétaire ;
basculer de ricing = réconcilier ces symlinks, pas déplacer des fichiers.

## Le pipeline

```
sources/<nom>/            clone upstream brut (install.sh, get.sh…)
        │  install / capture
        ▼
shells/<nom>/configs/     snapshot appliqué
  ├── config/<app>/       miroir de ~/.config
  ├── home/<dotfile>      miroir d'une liste curée de dotfiles de $HOME
  └── local/<item>        miroir de ~/.local/share (themes, icons, fonts)
        │  symlinks
        ▼
~/.config/<item>  ──►  shells/<propriétaire>/configs/config/<item>
```

`.current_shell` contient le nom du ricing actif. `.capture_state/` n'existe que pendant
une capture ; `.cancelled/` garde une capture annulée.

## Qui possède quoi

- **`interface`** — les units listés dans `SWITCHABLE_CONFIG_ITEMS` (hypr, quickshell,
  omarchy, waybar, rofi/wofi/fuzzel, mako/dunst/swaync, ags/eww/hyprpanel, hypridle,
  hyprlock, hyprpaper/swww/swaybg, kitty/ghostty/alacritty/foot, gtk-2/3/4, qt5ct/qt6ct,
  Kvantum, xsettingsd) et `SWITCHABLE_LOCAL_ITEMS` (`fonts`). Ils suivent le ricing.
- **`shared`** — tout le reste : apps, navigateurs, `systemd`, `gh`, `git`, credentials,
  `home/*`. Toujours possédés par `default`, jamais par un ricing.

C'est ce qui rend la bascule « seamless » : changer d'interface ne touche ni aux comptes,
ni aux sessions, ni aux données d'applications.

## Séquence d'un live switch

1. Refus si une capture est en cours.
2. `stop_running_shells` — arrête quickshell, hypridle, les barres/notifs connues et les
   `stop=` du ricing courant.
3. `apply_shell_live` :
   - réconciliation des symlinks vers le nouveau propriétaire,
   - `ensure_keymap_overlay` → génère puis injecte l'overlay de keymap,
   - `hyprctl reload`,
   - `start_shell` — démarre le shell du nouveau ricing : `start=` de son `ricing.conf` s'il
     y en a (voir [ricing-conf](ricing-conf.md)), sinon shell Omarchy / quickshell / barre détectés.
4. En cas d'échec : **revert** vers le ricing précédent. Si le revert échoue aussi,
   déconnexion de secours pour retrouver un bureau propre.
5. Les fenêtres restent ouvertes ; les **terminaux déjà ouverts gardent l'ancienne
   config** jusqu'à réouverture (normal).

## Quand le live n'est pas possible

`live=0` et bascule par déconnexion si : `--logout` demandé, ricing cible non-Hyprland,
session courante non-Hyprland, ou `hyprctl` injoignable. Le script l'annonce :
`Live switch not possible: <raison> — using the logout path.`

## Un invariant structurant du code

Le script est le **seul** à devoir créer ou supprimer ces symlinks. Il refuse de scanner
`$HOME` en entier, et `~/.config` est traité par liste explicite (`SWITCHABLE_*`), jamais
par balayage. Voir [invariants](invariants.md) pour la liste complète et [capture](capture.md) pour le cycle de
capture.
