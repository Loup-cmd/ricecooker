# Keymap Omarchy et overlay

Problème résolu : un ricing a ses propres keybinds, mais on veut **garder** les raccourcis
Omarchy. Solution : un overlay Lua généré, chargé **après** les keybinds du ricing, qui
traduit les actions Omarchy en actions du ricing cible.

## Fonctionnement

```bash
omarchy-keymap-generate <shell>
```

- Lit le keymap depuis le snapshot stocké de **`default`** — jamais depuis `~/.config`,
  car celui-ci pointe vers le ricing actif.
- Écrit `~/.hypr-switch/keymap/omarchy-keymap.lua`.
- Si `<shell>` vaut `default` : **no-op** (Omarchy possède déjà ses propres binds).

## Injection dans la config du ricing

`ricing-switch` appelle `ensure_keymap_overlay`, puis `patch_keymap_include` : un
`dofile` est ajouté dans le `hyprland.lua` du ricing, marqué par le commentaire :

```lua
-- hypr-switch: Omarchy keymap overlay (generated; do not edit)
```

Le `dofile` est protégé par `pcall` : un overlay cassé affiche un avertissement mais ne
laisse pas l'utilisateur sans bureau.

## Ce qui est lu, ce qui est écrit

| | Chemin |
|---|---|
| source (lecture) | `shells/default/configs/config/hypr/hyprland.lua` |
| sortie (écriture) | `~/.hypr-switch/keymap/omarchy-keymap.lua` |
| injection | `shells/<rice>/configs/config/hypr/hyprland.lua` |
| jamais modifié | `/usr/share/omarchy/**` |

## Surcharges par ricing

`bind:<action>=<commande>` dans `shells/<nom>/ricing.conf` remplace la traduction d'une
action Omarchy (`menu.root`, `ipc.notifications.act`, `omarchy-toggle-bar`…), `none` la
supprime. Voir [ricing-conf](ricing-conf.md).

## Overlay machine

Après le bloc keymap, `ricing-switch` ajoute un bloc `hypr-switch: machine overlay` qui charge
`~/.hypr-switch/lib/machine.lua` : moniteurs de `default` et clavier Omarchy (fr). Les dépôts
upstream codent souvent `kb_layout = "us"` et l'écran de leur auteur.

## Échecs connus

- `WARNING: $HOME/.local/bin/omarchy-keymap-generate is missing or not executable` →
  vérifier les droits (`ls -l ~/.local/bin/omarchy-keymap-generate`).
- `WARNING: could not generate the Omarchy keymap for '<nom>'` → le ricing n'a pas de
  config Hyprland Lua (`patch_keymap_include` le dit aussi).
- Un keymap manquant ne bloque **pas** la bascule : c'est volontaire.
