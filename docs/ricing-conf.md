# ricing.conf et la lib partagée

Chaque ricing peut décrire comment il démarre dans `~/.hypr-switch/shells/<nom>/ricing.conf`
(hors de `configs/`, donc jamais symlinké). Une seule source lue par quatre consommateurs :

| Lecteur | Ce qu'il en fait |
|---|---|
| `~/.local/bin/ricing-switch` | `start=` au switch à chaud, `stop=` en quittant, `wallpaper=builtin`, `private=`, alerte paquets manquants |
| `~/.hypr-switch/lib/hypr-switch.lua` (`hs.autostart`) | mêmes `start=` au login |
| `~/.local/bin/omarchy-keymap-generate` | `bind:<action>=<cmd>` remplace une action Omarchy dans l'overlay |
| `~/.local/bin/ricing` | `ricing deps` (`packages=`, `aur=`, `setup=`), `ricing doctor` |

Format (clé=valeur, clés répétables) : la référence est le commentaire d'en-tête de
`~/.hypr-switch/lib/hypr-switch.lua`. Clés : `description`, `packages`, `aur`, `setup`,
`start`, `stop`, `wallpaper=builtin`, `private`, `machine_monitors=false`,
`machine_keyboard=false`, `bind:<action>` (valeur `none` = ne pas lier).

## Règles qui en découlent

- Si `start=` existe, il fait autorité au switch : `start_shell` ne devine plus rien.
- `stop_running_shells` tue toujours quickshell, hypridle et les barres/notifs connues
  (waybar, swaync, dunst, mako, eww…), plus les `stop=` du ricing qu'on quitte.
- **Ne jamais mettre `stop=wl-paste`** : le shell Omarchy a ses propres `wl-paste --watch`.
  Les starts de démons partagés doivent être idempotents (`pgrep … || …`).
- `private=` (ou un dossier nommé comme le ricing) : un `config/<x>` que `default` ne possède
  pas suit le ricing. Voir `is_ricing_unit` dans `ricing-switch`.

## La lib `~/.hypr-switch/lib/`

| Fichier | Rôle |
|---|---|
| `hypr-switch.lua` | `hs.omarchy_base({shell=false})` : défauts Omarchy sans son shell ; `hs.autostart(nom)` |
| `machine.lua` | overlay machine : moniteurs de `default` + clavier Omarchy (fr), chargé en dernier |
| `wallpaper/shell.qml` | fond d'écran quickshell (`qs -p`) qui suit `~/.local/state/omarchy/current/background` |
| `conf2lua.lua` | conversion best-effort `hyprland.conf` → Lua utilisée par `ricing install` |

Le shell Omarchy dessine fond, barre et notifications : un ricing sans lui doit fournir les
siens (`wallpaper=builtin` pour le fond).

`ricing-switch` ajoute en fin de `hyprland.lua` deux blocs marqués : keymap Omarchy puis
`hypr-switch: machine overlay`. Voir [keymap](keymap.md).
