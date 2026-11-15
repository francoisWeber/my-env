# Ingest : alimenter le wiki

## Déclencheurs

Uniquement sur demande explicite : "ajoute ça au wiki", "note ça dans le wiki", "verse ça à notre base de connaissance", "ingère ce document", et déclinaisons. Ne jamais écrire de manière proactive.

Deux cas :
- **Document source** (PDF, URL, doc) sur lequel l'utilisateur a posé des questions.
- **Discussion technique** : en extraire la substance réutilisable (découvertes, conclusions, décisions), pas le déroulé.

## Procédure

1. **Inventaire.** Lance un query (voir [query.md](query.md)) sur le sujet à persister. Objectifs : éviter les doublons, étendre les articles existants plutôt qu'en créer de nouveaux, identifier les articles à référencer et ceux qui recevront un lien vers le nouveau contenu.
2. **Propositions.** Présente la liste des écritures envisagées, chacune avec un identifiant (`P1`, `P2`…). Types de proposition :
   - créer une source dans `raw/` ;
   - créer un article : nom du fichier, frontmatter, texte complet, ligne d'index avec mots-clés ;
   - modifier un article existant : diff du changement, nouvelle valeur de `updated` ;
   - ajouter un lien retour dans un article existant : diff ;
   - modifier les mots-clés d'une ligne d'index.

   Signale explicitement toute **contradiction** avec un article existant, en exposant les deux versions ; ne l'écrase jamais en silence.
3. **Validation.** Attends la validation explicite de l'utilisateur. Il répond par identifiant pour garder, modifier ou exclure chaque proposition. Aucune écriture avant.
4. **Écriture**, dans cet ordre, pour les seules propositions validées :
   1. sources dans `raw/` ;
   2. articles (créations, modifications, liens retour) ;
   3. `index.md` ;
   4. `graph.tsv` : régénère-le (voir plus bas) ;
   5. `log.md`.

## Sources dans raw/

Nommage : voir [SKILL.md](SKILL.md). Une fois écrite, une source n'est plus jamais modifiée.

- **PDF / document** : copie du fichier sans modification, via le script du skill (vérifie le nom, n'écrase jamais) :
  ```bash
  ~/.claude/skills/wiki-llm/scripts/add-raw.sh "<fichier source>" "PDF 2026-11-14 - HNSW Malkov.pdf"
  ```
- **URL** : fichier `.md` contenant uniquement l'URL.
- **Note migrée** (note personnelle d'un autre vault) : copie sans modification via `add-raw.sh`, nom `note <YYYY-MM-DD> - <titre assaini>.md`.
- **Discussion** : fichier `.md` contenant un court résumé horodaté (questions posées, conclusions), 200 mots maximum.

## Articles

- Format, nommage et limite de 500 mots : voir [SKILL.md](SKILL.md).
- Article trop long : extraire un concept dans un article à part, le référencer depuis l'article initial.
- Modification d'un article existant : relis-le d'abord, change le minimum, ne renomme jamais le fichier, mets à jour `updated`.
- Un nouvel article pointe vers les articles liés identifiés à l'inventaire, et ceux-ci reçoivent un lien retour (propositions dédiées).

## graph.tsv

Après chaque ingest, régénère le graphe complet à partir des liens des articles :

```bash
~/.claude/skills/wiki-llm/scripts/build-graph.sh
```

Ne l'édite jamais à la main. Le script signale sur stderr les liens vers des articles inexistants : corrige-les dans les articles concernés (nouvelle proposition si l'article n'était pas dans les propositions validées).

## log.md

Une ligne par ingest, ajoutée en fin de fichier :

```
YYYY-MM-DD ingest|update — [[page 1]], [[page 2]], raw/<source>
```

`ingest` si au moins un article est créé, `update` si seuls des articles existants sont modifiés.
