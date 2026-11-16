# ricecooker 🍚

**Change de ricing Hyprland à chaud, sans perdre une fenêtre — et installe n'importe quel
ricing depuis GitHub en une commande.**

Fait pour [Omarchy](https://omarchy.org) (Hyprland 0.56+, config Lua), utilisable sur tout
Arch + Hyprland.

```bash
ricing install https://github.com/LilaccFlowerr/Nebula -y   # clone, installe, capture
ricing switch Nebula                                         # bascule à chaud
ricing switch default                                        # retour à Omarchy
```

## Ce que ça fait

- **Switch à chaud.** Chaque `~/.config/<item>` d'interface (hypr, quickshell, waybar, rofi,
  terminaux, GTK/Qt…) est un lien vers le ricing qui le possède. Changer de ricing = arrêter
  l'ancien shell, réconcilier les liens, recharger Hyprland, démarrer le nouveau. Les fenêtres
  restent ouvertes ; en cas d'échec, retour automatique au ricing précédent.
- **Tes applis ne bougent pas.** Navigateur, Discord, comptes, dotfiles de `$HOME` : tout ce qui
  n'est pas de l'interface reste au ricing `default` (ta config d'origine), quel que soit le
  ricing actif.
- **Ton keymap Omarchy partout.** Un overlay généré rejoue tes raccourcis Omarchy dans chaque
  ricing, traduits vers ses propres outils (lanceur, barre, notifications…). Sans Omarchy
  installé, chaque ricing garde sa propre keymap et l'overlay machine est seul ajouté.
- **Ta machine partout.** Un overlay remet tes écrans et ta disposition clavier : les dotfiles
  upstream codent souvent `kb_layout = "us"` et l'écran de leur auteur.
- **Sélecteur au look du ricing actif.** `ricing switch` sans argument ouvre le sélecteur que le
  ricing déclare (`picker=`), rofi restant le secours en terminal. `hidden=true` retire un ricing
  du sélecteur sans le supprimer (`ricing switch <nom>` marche toujours).
- **Installation automatique robuste.** `ricing install` lance l'installateur du dépôt dans un
  environnement encadré, ou copie sa config s'il n'en a pas, puis adapte le résultat à la machine.

## `ricing install` : ce qui ne casse plus

| Problème | Traitement |
|---|---|
| Paquet déjà installé, en conflit, introuvable | ignoré / on garde l'installé / variantes `-bin` `-git` puis AUR — jamais bloquant, résumé en fin |
| Base pacman périmée, clés PGP, fichiers déjà présents | `-Syu`, `archlinux-keyring`, `--overwrite` ciblé |
| Pas d'`install.sh` | config cherchée partout (HyDE `Configs/.config`, stow, chezmoi `dot_config`), dépendances lues dans `packages.txt` et les `pacman -S` du README |
| Installateur interactif / sudo au milieu | réponses `y`, mot de passe demandé une fois et gardé vivant, délai max 1 h |
| Installateur dangereux | suppressions de paquets, `-Syu`, `reboot`, `chsh`, `hyprctl reload/exit`, gestionnaire de connexion : neutralisés |
| Installateur qui plante | si rien n'est posé, copie directe de la config du dépôt |
| `hyprland.conf` ancien format | converti en Lua, lignes refusées par Hyprland commentées |
| `/home/<auteur>/…`, `.bashrc` réécrit, `hypr.bak-*` | chemins corrigés, ton `.bashrc` gardé, sauvegardes rangées à part |

Limite connue : un dépôt NixOS (flake / Home Manager) ne se convertit pas automatiquement.

## Installation

```bash
git clone https://github.com/Loup-cmd/ricecooker
cd ricecooker
./install.sh            # ou ./install.sh --link pour suivre le dépôt
ricing bootstrap        # une seule fois : ta config actuelle devient le ricing 'default'
```

Dépendances : `bash git lua jq perl`, et pour le switch à chaud `hyprland quickshell`
(`rofi` pour le menu). Désinstaller : `./uninstall.sh` (tes ricings et ta config sont gardés).

## Commandes

| Commande | Effet |
|---|---|
| `ricing switch [nom]` | bascule (menu rofi sans nom) ; `--logout` pour forcer une déconnexion |
| `ricing install [nom] <url>` | installe et capture ; `-y`, `--force`, `--manual`, `--no-installer`, `--no-deps` |
| `ricing deps <nom>` | installe les paquets et le setup déclarés par un ricing |
| `ricing doctor [nom]` | vérifie config, paquets, programmes de démarrage, fond d'écran |
| `ricing list` · `current` · `show <nom>` | état |
| `ricing repair` · `reload` · `cancel` | réparer les liens, recharger, annuler une capture |

URL acceptées : `https://github.com/u/r`, `github.com/u/r`, `u/r`, `git@…`,
`…/tree/<branche>/<sous-dossier>`, ou un dossier local.

## Décrire un ricing : `ricing.conf`

```ini
description=Waybar + swaync + rofi
packages=waybar swaync rofi
start=waybar
start=swaync
stop=waybar
wallpaper=builtin
bind:menu.root=rofi -show drun
bind:omarchy-toggle-bar=pkill -SIGUSR1 waybar
```

Généré par `ricing install`, modifiable à la main. Détail : [docs/ricing-conf.md](docs/ricing-conf.md),
exemples dans [examples/](examples/).

## Documentation

- [docs/architecture.md](docs/architecture.md) — stockage, liens, séquence d'un switch
- [docs/capture.md](docs/capture.md) — capture et pipeline d'installation
- [docs/ricing-conf.md](docs/ricing-conf.md) — format et lib Lua partagée
- [docs/keymap.md](docs/keymap.md) — overlay de keymap Omarchy et overlay machine
- [docs/troubleshooting.md](docs/troubleshooting.md)

## Tests

```bash
tests/sandbox-install.sh   # install de bout en bout dans un HOME jetable, sans toucher ta session
```

## Crédits

Né de [hypr-switch](https://github.com/bobincraft1/hypr-switch) (MIT), un switcher de shells
Hyprland par liens symboliques. Le stockage reste dans `~/.hypr-switch/` et `hypr-switch` est
gardé comme alias de `ricing-switch` pour la compatibilité. Licence : MIT.
