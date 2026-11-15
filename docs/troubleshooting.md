# Troubleshooting

## Table de diagnostic

| Symptôme | Cause probable | Commande |
|---|---|---|
| Un item de `~/.config` pointe vers le mauvais ricing | symlinks désynchronisés | `ricing switch --repair` |
| Un symlink est cassé / pointe dans le vide | snapshot déplacé ou renommé | `ricing switch --repair` |
| « a capture is currently in progress » | `.capture_state/` présent | `ricing switch capture-status` puis `finish`/`cancel` |
| Le live switch n'applique rien | Hyprland injoignable / ricing non-Hyprland | lire le message `Live switch not possible: <raison>` |
| Le ricing ne démarre pas | son shell/quickshell plante | revert auto ; inspecter les logs du shell |
| Le revert échoue aussi | desktop cassé | le script déconnecte automatiquement (récupération propre) |
| Pas de notifications après un live switch | un live switch ne démarre que le shell principal, pas le daemon de notif | se déconnecter/reconnecter, ou relancer le daemon |
| Un terminal garde l'ancienne config | comportement normal | rouvrir le terminal |
| Binds Omarchy absents sur un ricing | overlay non généré/injecté | voir [keymap](keymap.md) |
| Ricing visible mais absent de `ricing list` | présent dans `sources/` mais pas capturé | `ricing install` ou cycle de capture |
| Barre/notifs absentes sur un ricing | paquets manquants (waybar, swaync…) | `ricing doctor <nom>` puis `ricing deps <nom>` |
| Clavier en QWERTY / mauvais écran sur un ricing | overlay machine absent ou désactivé | vérifier le bloc `machine overlay` en fin de `hyprland.lua` |
| « real file/directory, not a hypr-switch symlink » | un programme a recréé `~/.config/<x>` | item privé : garé automatiquement dans `.cancelled/stray-*` ; sinon déplacer à la main |
| Barre de l'ancien ricing reste affichée | processus non listé dans `stop=` | ajouter `stop=<processus>` au `ricing.conf` |

## Commandes de base

```bash
ricing list                      # ricings capturés + nb d'items
ricing current                   # ricing actif
ricing show <nom>                # interface vs partagé
ricing switch <nom>              # bascule live
ricing switch --logout <nom>     # bascule par déconnexion
ricing switch --reload           # recharge la config du ricing actif
ricing switch --repair           # répare les liens, sans redémarrer
```

## Vérifier l'état réel

```bash
cat ~/.hypr-switch/.current_shell
ls -l ~/.config/hypr ~/.config/kitty
ls -d ~/.hypr-switch/.capture_state 2>/dev/null && echo "capture en cours"
```

## Règle d'or

Ne jamais réparer un symlink à la main. `--repair` fait la réconciliation complète et
idempotente ; une réparation manuelle partielle est ce qui casse le plus souvent le
système. Voir [invariants](invariants.md).
