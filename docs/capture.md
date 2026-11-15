# Capturer un ricing

Une capture enregistre l'état actuel d'un bureau dans `shells/<nom>/configs/`, puis le
déclare propriétaire des units qu'il a modifiés.

## Cycle normal

```bash
ricing switch capture-start <nom>     # 1. ouvre la capture (crée .capture_state/)
#    → installer le ricing à la main, ou lancer son installateur
ricing switch capture-finish <nom>    # 2. diff, claim des units, symlinks
```

Pendant la capture, le message d'aide est explicite : l'état capturé est **live**, donc
inspectable, mais rien n'est formellement appliqué avant `ricing switch <nom>`.

## Ce qui se passe à `capture-start`

- Les items d'interface qui existent en vrai dossier non géré (ex. `gtk-4.0`) sont d'abord
  adoptés dans `default`, pour qu'un installateur ne puisse pas emporter l'unique copie.
- Seuls les items d'interface, les dotfiles `home/*` et les items privés d'un autre ricing sont
  dé-symlinkés. Les items partagés (mozilla, discord…) restent des liens vers `default` :
  ils ne sont ni copiés ni hachés, les applis ouvertes continuent d'écrire au bon endroit.
- L'état est écrit dans `.capture_state/` : c'est la référence pour annuler.

## Ce qui se passe à `capture-finish`

- Diff entre l'état de départ et l'état final.
- Les units modifiés sont revendiqués par le nouveau ricing (uniquement ceux autorisés :
  voir [invariants](invariants.md)).
- Les symlinks sont réconciliés vers le nouveau propriétaire.
- Les changements « partagés » (apps, comptes) sont reportés sur le snapshot de `default`,
  pas sur le ricing ; l'ancienne copie de `default` part dans `.cancelled/<nom>-capture-*/`.
- Un dotfile modifié (`.bashrc`…) n'est **pas** appliqué : l'original est gardé, la version du
  ricing va dans `shells/<nom>/extras/home/`.
- Les sauvegardes faites par l'installateur (`hypr.bak-*`, `*.old`…) sont garées dans
  `.cancelled/` au lieu de devenir des units.
- Les liens partagés déplacés par l'installateur sont recréés (`restore_shared_links`).

## Annuler

```bash
ricing switch capture-status      # où en est-on ?
ricing switch capture-cancel      # restaure tout, garde une copie dans .cancelled/
```

`capture-cancel` restaure les units préexistants tels quels et retire ceux que la capture
avait créés. Il ne touche pas aux units non gérés (ceux que `capture-start` avait
volontairement laissés en place).

## Installer un ricing depuis un dépôt

```bash
ricing install <nom> <url-git>        # clone dans sources/, lance son installateur, capture
ricing install <nom> <url-git> -y     # sans confirmation
```

L'installateur du dépôt est **du code arbitraire**, sans sandbox. `ricing install` le lance
quand même de façon encadrée (détail dans le commentaire d'en-tête de `~/.local/bin/ricing`) :

- mot de passe sudo demandé une fois, gardé vivant ; questions → `y` ; délai max 1 h ;
- cales `pacman`/`yay`/`paru`/`sudo` : paquets déjà là ignorés, conflit avec un paquet installé
  → on garde l'installé, introuvable → variantes `-bin`/`-git` puis AUR, base périmée →
  `-Syu`, clés PGP, fichiers déjà présents ; suppressions de paquets et `-Syu` refusés ;
- `reboot`, `chsh`, `hyprctl reload/exit`, activation d'un gestionnaire de connexion,
  `pkill Hyprland` : neutralisés ;
- installateur en échec sans config posée → copie directe de la config du dépôt ;
- sans installateur : config cherchée partout (`Configs/.config` HyDE, stow, chezmoi
  `dot_config`), dépendances lues dans `packages.txt` et les `pacman -S` du README ;
- après capture : chemins `/home/<autre>` corrigés, `hyprland.conf` converti en Lua
  (lignes refusées par Hyprland commentées), `ricing.conf` généré, liens remis sur le ricing
  actif, puis `ricing doctor`.

Dépôt NixOS (flake) : pas de conversion automatique ; il faut le porter à la main (traduire `hyprland.nix` en Lua, figer les tokens de thème, remplacer les chemins `/nix/store`).
Journal : `~/.hypr-switch/logs/install-<nom>-*.log`.

## Ricing non capturé

Un dossier dans `sources/` ne signifie **pas** que le ricing est utilisable : il faut
l'installer puis le capturer.
