# Query : rechercher dans le wiki

## Déclencheurs

- Demande explicite : "cherche dans le wiki", "as-tu un article sur le sujet ?", "que dit notre wiki ?", et déclinaisons.
- Appel interne par un ingest (voir [ingest.md](ingest.md)), pour inventorier les articles en rapport.

## Procédure

1. **Index.** Lis `index.md`. Repère les articles pertinents par leur titre et leurs mots-clés.
2. **Grep.** Complète par une recherche plein texte dans `wiki/` (`grep -ril <terme> wiki/`) avec les termes du sujet et leurs synonymes : elle rattrape les articles dont le titre et les mots-clés ne couvrent pas le terme cherché.
3. **Lecture.** Ouvre les articles retenus.
4. **Élargissement par le graphe.** Pour chaque article retenu, récupère ses voisins dans `graph.tsv` avec les scripts du skill (un titre par ligne en sortie, vide si aucun voisin) :
   ```bash
   # liens entrants : articles qui référencent X
   ~/.claude/skills/wiki-llm/scripts/inlinks.sh "<titre complet de X>"
   # liens sortants : articles référencés par X
   ~/.claude/skills/wiki-llm/scripts/outlinks.sh "<titre complet de X>"
   ```
   Les liens entrants montrent où le sujet est utilisé, les liens sortants ce sur quoi il repose. Ouvre les voisins pertinents pour élargir la réflexion, sur un ou deux niveaux au plus.

## Réponse

- Réponds en citant les articles utilisés (`[[titre complet]]`).
- Distingue ce qui vient du wiki de ce que tu ajoutes par d'autres moyens.
- Si rien de pertinent n'est trouvé, dis-le, puis poursuis la réponse par les moyens habituels.

## Résultat pour un ingest

Quand le query est appelé par un ingest, produis un inventaire :
- articles qui couvrent déjà le sujet (risque de doublon, candidats à une mise à jour) ;
- articles vers lesquels le nouveau contenu doit pointer ;
- articles qui devraient recevoir un lien vers le nouveau contenu ;
- contradictions éventuelles entre le wiki et le nouveau contenu.

Les query ne sont pas journalisées dans `log.md`.
