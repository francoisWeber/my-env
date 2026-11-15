# my-env

Bootstrap de mon Mac. Dépôt **public**: aucun secret ici (un hook `pre-commit` bloque les plus évidents).

## Sur un Mac vierge

1. Télécharger le zip du dépôt, le dézipper et le placer dans `~/code/my-env`
   (le `.zshrc` pointera vers ce dossier pour toujours: `install.sh` refuse de tourner depuis `~/Downloads` ou `/tmp`).
2. `bash ~/code/my-env/install.sh`, éventuellement avec `--profile perso,pro`.
3. Ouvrir un nouveau terminal.

## Ce que fait `install.sh` (idempotent, relançable)

| Étape   | Effet |
|---------|-------|
| `xcode` | Xcode Command Line Tools (fournissent git) |
| `brew`  | Installe Homebrew, puis `brew bundle` de `common/Brewfile` et de `<profil>/Brewfile` |
| `shell` | Injecte **une fois** un bloc dans `~/.zshrc` qui source `shell/init.sh` (sauvegarde: `~/.zshrc.pre-my-env`) |
| `git`   | Inclut `git/gitconfig` depuis `~/.gitconfig`, `git lfs install` si git-lfs est présent, demande l'identité si absente, active le hook anti-secrets si le dossier est un dépôt git |
| `ssh`   | Génère `~/.ssh/id_ed25519` **s'il n'existe pas** (jamais écrasée), l'ajoute à l'agent et au trousseau, copie la clé publique dans le presse-papiers |
| `skills`| Active les skills Claude listés dans les `skills.list` (voir plus bas) dans `~/.claude/skills` |
| `apps`  | Dépose `apps-configs/RectangleConfig.json` là où Rectangle le lit à son lancement (popup de confirmation) |

```sh
bash install.sh --dry-run             # montre ce qui serait fait, ne modifie rien
bash install.sh --profile perso,pro   # profils superposés (mémorisés dans ~/.config/my-env/profiles)
bash install.sh --skip brew,ssh       # étapes: xcode,brew,shell,git,ssh,skills,apps
```

## Organisation

```
install.sh              point d'entrée
common/                 chargé pour tous les profils
  Brewfile  env.sh  alias.sh  skills.list
perso/  pro/            un dossier par profil, mêmes fichiers (tous optionnels)
  Brewfile  env.sh  alias.sh  skills.list
my-skills/              catalogue de MES skills Claude (un dossier par skill, avec SKILL.md)
shell/init.sh           chargeur sourcé par ~/.zshrc (ne pas y mettre de config perso)
git/gitconfig           alias et réglages git partagés (l'identité reste dans ~/.gitconfig)
apps-configs/           configs d'apps à restaurer (Rectangle)
scripts/                lib.sh (fonctions communes), ssh-key.sh
.githooks/pre-commit    refuse un commit qui ressemble à un secret
```

**Chargement du shell**, à chaque nouveau terminal: `common/` puis chaque profil dans l'ordre donné
(le dernier gagne), d'abord `env.sh` puis `alias.sh`, enfin `~/.config/my-env/local.sh`.
Modifier un alias, une variable ou un Brewfile se fait donc à la main dans le dépôt; les alias et variables
s'appliquent au prochain terminal, sans relancer `install.sh` (qui n'est nécessaire que pour installer les apps).

`~/.config/my-env/local.sh` est **hors dépôt**: c'est là que vont les secrets (clés d'API) et les réglages propres à une machine.

## Skills Claude

`my-skills/` est un **catalogue**; ce sont les `skills.list` de chaque couche qui décident de ce qui est **activé**
(`pro` veut dire « activé en pro », pas « privé »: tout `my-skills/` est public). Une ligne par skill:

```
wiki-llm                                    # mon skill: lien symbolique vers my-skills/wiki-llm
https://github.com/<qui>/<repo>.git  <chemin dans le dépôt>  <SHA complet ou tag>   # skill public, copie figée
```

- Le commit d'un skill public est **obligatoire**: un skill est un prompt exécuté par l'agent, pas de branche flottante.
  Pour monter de version: relire le diff amont, puis changer le SHA (40 caractères) dans la ligne.
- Un dossier déjà présent dans `~/.claude/skills` et non géré par `install.sh` n'est jamais écrasé: il devient `<nom>.pre-my-env`.
- Retirer une ligne ne désinstalle rien: supprimer le dossier à la main dans `~/.claude/skills`.
- Pas de chemin en dur dans un skill: passer par une variable d'environnement définie dans `env.sh`
  (ex: `WIKI_ROOT` dans `pro/env.sh`, résolue par le skill avec `echo "${WIKI_ROOT:-...}"`).
  Elle est absente si Claude est lancé depuis une app qui ne lit pas le `.zshrc`.
- Non gérés ici: les skills `aws-*` (installés par l'outil AWS), et les skills de projet (dans leurs dépôts).

## Maintenance

- **Ajouter une app ou un outil:** une ligne dans le `Brewfile` du bon dossier (`common/`, `perso/` ou `pro/`).
  Il n'y a pas de détection automatique de ce qui serait installé sans être listé.
- **Ajouter un alias ou une variable:** dans `alias.sh` / `env.sh` du bon dossier.
- **Ajouter un skill:** un dossier dans `my-skills/` puis son nom dans un `skills.list`, ou une ligne URL pour un skill public.
- **Mettre à jour la config Rectangle:** l'exporter depuis l'app (Réglages ▸ Export) vers `apps-configs/RectangleConfig.json`.
- **Changer d'éditeur:** `EDITOR` dans `common/env.sh` et `core.editor` dans `git/gitconfig` valent aujourd'hui `code --wait`
  (VS Code n'est pas dans les Brewfiles).
