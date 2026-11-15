# Invariants

Les règles que le code suppose vraies. En casser une produit des bugs silencieux, pas des
erreurs. Chaque règle indique comment la vérifier.

## 1. Un seul propriétaire par unit

Chaque `~/.config/<item>` pointe vers **exactement un** ricing. Il n'y a pas de fusion,
pas d'héritage partiel : soit le ricing possède l'unit, soit c'est `default`.

```bash
ls -l ~/.config/hypr        # doit pointer vers shells/<un seul owner>/configs/config/hypr
ricing show <nom>           # dit explicitement interface / shared
```

## 2. Seuls les units `interface` suivent le ricing

Un ricing ne possède que `SWITCHABLE_CONFIG_ITEMS` + `SWITCHABLE_LOCAL_ITEMS`. Tout le
reste — `mozilla`, `discord`, `gh`, `git`, `systemd`, `home/*` — reste sur `default` pour
toujours. C'est la garantie « changer d'interface ne change pas mes comptes ».

Exception : un item **privé** — `config/<x>` que `default` ne possède pas, nommé comme le
ricing ou listé dans `private=` de son `ricing.conf` (ex. `config/nebula`). Il suit le ricing
et disparaît en revenant à `default`. Voir [ricing-conf](ricing-conf.md).

Vérification : `ricing show <nom>` doit afficher `shared — stays on default` pour ces
items. Si un item d'application apparaît en `interface`, c'est un bug de configuration.

## 3. `home/*` est toujours partagé

Les dotfiles de `$HOME` (`.bashrc`, `.zshrc`, `.themes`, `.icons`, `.fonts`, `.Xresources`,
`.xinitrc`, `.vimrc`, `.gtkrc-2.0`) sont mirés dans `home/` mais **jamais** switchables.
La liste `WATCHED_HOME_ITEMS` est curée à la main ; `$HOME` n'est jamais scanné en entier.

## 4. Denylist absolue

Jamais capturé, même si ajouté par erreur à la liste surveillée :
`.ssh`, `.gnupg`, `.gpg`, `.password-store`, `.aws`, `.gcloud`, `.kube`, `.netrc`,
`.git-credentials`, `.docker`, `.hypr-switch`.

Toute modification de `WATCHED_HOME_ITEMS` doit être relue contre cette liste.

## 5. `~/.config` n'est jamais scanné en bloc

Seuls les units listés sont réconciliés. Un dossier inconnu dans `~/.config` n'est pas
adopté automatiquement : il doit être ajouté explicitement (ou capturé via bootstrap).

## 6. L'overlay keymap est généré depuis `default`

`omarchy-keymap-generate <shell>` lit **le snapshot stocké de `default`**, jamais
`~/.config` (qui pointe vers le ricing actif). Sortie : `~/.hypr-switch/keymap/omarchy-keymap.lua`.
Pour `default` lui-même, le générateur ne fait rien (no-op). Voir [keymap](keymap.md).

## 7. Pas de switch pendant une capture

`do_switch` s'arrête net si `.capture_state/` existe. Finir ou annuler d'abord :

```bash
ricing switch capture-status
ricing switch capture-finish <nom>
ricing switch capture-cancel
```

## 8. Un échec de live switch se répare tout seul

Échec du nouveau shell → revert vers l'ancien. Échec du revert → déconnexion. Ne jamais
« réparer » à la main pendant que ce mécanisme tourne.

## 9. Seul `ricing-switch` touche aux symlinks

Ne jamais `rm` un symlink de `~/.config`, ne jamais le recréer à la main. Utiliser
`ricing switch --repair`, qui réconcilie sans redémarrer quoi que ce soit.

## 10. Le stockage vit hors de `~/.config`

`~/.hypr-switch/` est à la racine du home, précisément pour ne pas être emporté par une
réconciliation de `~/.config`.
