# Spécifications NoseTrack

Ces documents décrivent le produit cible. Ils ne signifient pas que toutes les
fonctions sont implémentées. L'état du code et les commandes de développement
sont présentés dans le [README du projet](../README.md).

## Où trouver chaque sujet ?

| Document | Contenu de référence |
| --- | --- |
| [Fonctionnalités](fonctionnalites.md) | Vocabulaire, accueil, offres et comportements visibles par l'utilisateur. |
| [Règles techniques](technique.md) | Validité, quota, copies, transitions de compte, live et transferts, calcul de pollution et Track Assist. |
| [Rapports](rapports.md) | Accès avec compte, contenu Gratuit/Premium, calculs, météo, limites et export PDF. |
| [Base de l'application](database/app.md) | Schéma SQLite actuel, tables prévues, préférences et stockage sécurisé. |
| [Base serveur](database/server.md) | Identité commune au site et à l'app, authentification, abonnements et facturation. |
| [Maquette de l'accueil](maquettes/README.md) | Prototype interactif et limites de la simulation. |
| [TODO des spécifications](todo.md) | Liste centrale des décisions restant à préciser. |
| [Localisation native](../docs/tracking.md) | API et format JSONL déjà implémentés. |

Les règles produit sont définies dans les fonctionnalités ; leurs mécanismes
sont détaillés dans les documents spécialisés. Les autres documents y renvoient
sans redéfinir les mêmes règles. Le SQL exécutable actuel reste
[tracks_v1.sql](../assets/sql/tracks_v1.sql).

## État et décisions ouvertes

- **Implémenté** : carte d'accueil, aperçu téléphone sur macOS, API de carte et
  de permissions dans `app-core`, localisation native, catalogue `tracks` v1
  et fichiers JSONL. La tenue GPS sur téléphone réel reste à valider.
- **Spécifié, à développer** : parcours d'enregistrement et de carnet, règles
  d'offres, rapports/PDF, Track Assist, pollution et fonctionnement des sessions.
- **Modèle en cours de définition** : comptes, authentification, abonnements,
  structures locales complémentaires et protocole réseau.
- **Évolution future** : sauvegarde et synchronisation cloud de toutes les pistes.

Les points produit, choix de modèles et évolutions encore ouverts sont regroupés
dans le [TODO des spécifications](todo.md). Les documents spécialisés conservent
les décisions validées et renvoient vers cette liste pour les précisions restantes.
