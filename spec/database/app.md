# Base de données de l’application

Ce document regroupe le stockage local déjà implémenté et les structures prévues
pour les fonctions spécifiées. Il ne crée aucune table ni migration.

- [Base serveur](server.md).
- [Règles fonctionnelles](../fonctionnalites.md).
- [Règles de gestion des données](../technique.md).
- [Implémentation du stockage GPS](../../docs/tracking.md).

## 1. Rôle et état des structures

L’application conserve le carnet, les fichiers GPS et les données nécessaires à
la consultation locale. La base serveur reste la référence pour l’identité et
les droits du compte ; l’application y accède par l’API NoseTrack.

| Structure | Rôle | État |
| --- | --- | --- |
| `tracks` | Catalogue du carnet et références des traces GPS. | Implémentée, schéma v1. |
| Fichiers JSONL | Points GPS de chaque rôle. | Implémentés, hors SQL. |
| `accounts` | Copie locale du profil et des droits courants. | Prévue. |
| `dogs` | Chiens associés au compte. | Prévue. |
| `sessions`, `session_tracks` | Regroupements du carnet pour les outils Pro. | Prévues. |
| SharedPreferences | Réglages de l’installation. | Structure proposée, stockage distinct de SQL. |

Les identifiants de compte sont ceux du serveur. Les identifiants des copies de
pistes restent locaux et indépendants. Le schéma local ne reproduit pas toutes
les tables du serveur.

## 2. Emplacement et conventions

Le catalogue actuel est `NoseTrack/tracks.sqlite` ; les points sont dans un
JSONL par piste et par rôle. Les chemins Android/Apple et l'arborescence sont
centralisés dans [le stockage natif](../../docs/tracking.md#fichiers-et-sql).
Les références de fichiers SQL sont relatives à cette racine privée.

Dans SQLite : identifiants en `TEXT`, dates UTC en millisecondes dans un
`INTEGER`, coordonnées en degrés WGS84 dans un `REAL`. Les futurs booléens
utiliseront `INTEGER` avec les valeurs `0` et `1`. Dans les exemples JSON des
documents, les dates peuvent être présentées en ISO 8601 pour la lecture.

L’emplacement physique des futures tables, dans le fichier existant ou dans une
base locale dédiée, sera arrêté avec leurs migrations. Le schéma v1 actuel
reste défini par [tracks_v1.sql](../../assets/sql/tracks_v1.sql).

## 3. Table `tracks` : schéma actuel

Une ligne représente une piste contenant au maximum une trace traceur et une
trace chien. Les points GPS sont dans les JSONL, pas dans cette table.

| Colonne | Type SQLite | Signification |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY NOT NULL` | Identifiant local de la piste. |
| `name` | `TEXT NOT NULL` | Nom non vide après suppression des espaces de bord. |
| `description` | `TEXT NULL` | Description modifiable. |
| `dog_name` | `TEXT NULL` | Nom du chien associé à cette piste. |
| `created_at` | `INTEGER NOT NULL` | Création de la fiche locale. |
| `updated_at` | `INTEGER NOT NULL` | Dernière modification de la fiche. |
| `deleted_at` | `INTEGER NULL` | Marqueur technique de suppression en cours. |
| `tracer_file_name` | `TEXT NULL` | Référence du JSONL traceur. |
| `tracer_started_at` | `INTEGER NULL` | Début enregistré de la trace traceur. |
| `tracer_ended_at` | `INTEGER NULL` | Fin enregistrée, si finalisée. |
| `tracer_status` | `TEXT NULL` | `recording`, `interrupted` ou `finished`. |
| `tracer_point_count` | `INTEGER NOT NULL DEFAULT 0` | Nombre de points traceur, positif ou nul. |
| `tracer_start_latitude` | `REAL NULL` | Latitude du premier point traceur, entre −90 et 90. |
| `tracer_start_longitude` | `REAL NULL` | Longitude du premier point traceur, entre −180 et 180. |
| `dog_file_name` | `TEXT NULL` | Référence du JSONL chien. |
| `dog_started_at` | `INTEGER NULL` | Début enregistré de la trace chien. |
| `dog_ended_at` | `INTEGER NULL` | Fin enregistrée, si finalisée. |
| `dog_status` | `TEXT NULL` | `recording`, `interrupted` ou `finished`. |
| `dog_point_count` | `INTEGER NOT NULL DEFAULT 0` | Nombre de points chien, positif ou nul. |
| `dog_start_latitude` | `REAL NULL` | Latitude du premier point chien, entre −90 et 90. |
| `dog_start_longitude` | `REAL NULL` | Longitude du premier point chien, entre −180 et 180. |

Index actuel : `tracks_created_at` sur `created_at DESC`. La version du schéma
est `PRAGMA user_version = 1`.

Le natif est l’unique écrivain du stockage GPS actuel. Les compteurs et premiers
points sont des caches reconstruisibles depuis les JSONL. Une trace finalisée
est immuable ; ajouter le rôle manquant complète la piste. L’API d’édition
modifie uniquement le nom, la description et le nom du chien.

`deleted_at` permet de reprendre une suppression interrompue : marquage de la
ligne, suppression du dossier, puis retrait de la ligne. Ce n’est pas une
corbeille utilisateur ni un historique des consommations du quota.

L'API native actuelle importe un rôle JSONL dans une fiche existante. Le futur
parcours d'import d'une piste complète et la déduplication des reprises réseau
sont décrits dans [les règles de partage](../technique.md#4-partage-de-copies-indépendantes).

## 4. Table `accounts` : profil et droits en cache

Structure prévue, distincte des identifiants techniques de connexion serveur.

| Colonne | Type SQLite prévu | Signification |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY NOT NULL` | Identifiant NoseTrack du serveur. |
| `email` | `TEXT NOT NULL` | E-mail obligatoire reçu du profil serveur ; une adresse relais est acceptée. |
| `email_verified_at` | `INTEGER NULL` | Vérification de l’e-mail reçue du serveur ; vide tant que non vérifié. |
| `display_name` | `TEXT NOT NULL` | Nom/pseudo d’affichage obligatoire et non unique reçu du serveur. |
| `created_at` | `INTEGER NOT NULL` | Date de création du compte sur le serveur. |
| `default_dog_id` | `TEXT NULL` | Chien sélectionné par défaut, appartenant à ce compte. |
| `effective_plan` | `TEXT NOT NULL` | Droits reçus du serveur : `free`, `premium` ou `pro`. |
| `access_until` | `INTEGER NULL` | Échéance d’accès transmise par le serveur. |
| `subscription_provider` | `TEXT NULL` | Canal de l’abonnement présenté : `apple`, `google` ou `web`. |
| `auto_renew` | `INTEGER NULL` | Renouvellement automatique, si applicable. |
| `entitlements_verified_at` | `INTEGER NULL` | Dernière vérification des droits auprès du serveur. |

Les données reçues du serveur permettent l'affichage et le fonctionnement local.
L'app utilise l'offre mémorisée jusqu'à `access_until`, puis les droits Gratuit
tant qu'un renouvellement n'a pas été validé, avec les maintiens d'outils déjà
définis. Le retour du réseau actualise ce cache depuis le serveur. Son expiration
locale ne réécrit pas l'historique de facturation. Voir
[la règle complète](../technique.md#droits-mémorisés-hors-réseau).

Le cache n'est pas une preuve d'achat. `default_dog_id` est un choix local parmi
les chiens du compte ; les autres champs décrivent le profil et les droits reçus.

Les parcours de création, liaison, vérification et changement d'e-mail sont
centralisés dans [la connexion serveur](server.md#2-connexion). Le cache conserve
l'adresse active jusqu'à réception du profil modifié après confirmation.
Aucun champ `pending_email`, lien d'authentification ou jeton temporaire n'est
nécessaire dans cette table. L'interface consulte les moyens liés et les demandes
en attente par l'API.

Plusieurs téléphones peuvent rester connectés sans exclusion automatique.
Chaque connexion dispose de sa propre session serveur et chaque installation
conserve son carnet local. La synchronisation future des pistes entre appareils
reste à définir avec le stockage cloud. `subscription_provider` et `auto_renew`
décrivent l'abonnement présenté ; leur sélection en présence de plusieurs achats
reste à préciser, indépendamment du calcul de `effective_plan` et `access_until`.

L'utilisation sans compte ne crée aucune ligne `accounts` fictive. Son carnet
peut recevoir des pistes sans donner accès aux rapports. Une participation à
une session utilise un pseudo temporaire généré et modifiable, distinct du
profil de compte ; son modèle réseau reste à définir.

Le schéma `tracks` v1 ne possède pas de colonne `account_id`. Son rattachement
et l'isolation physique ou logique restent à préciser dans le
[TODO local](../todo.md#3-enregistrement-et-données-locales). Le contexte propriétaire
est conservé même après une déconnexion : le carnet reste isolé sur le téléphone
et est retrouvé à la reconnexion au même compte. Il est supprimé, après
avertissement/export, lors du passage à un autre compte.

Les parcours de transition et leurs choix en cas d'erreur sont définis dans
[la finalisation avant changement d'identité](../technique.md#finalisation-avant-déconnexion-ou-changement-de-compte).
Les données et envois restent attachés au contexte d'origine jusqu'à la fin ou
l'abandon confirmé de cette transition. Le carnet invité reste distinct du
carnet de compte conservé.

Une expiration ou révocation de connexion n'est pas une transition de compte :
le contexte propriétaire et l'enregistrement local sont conservés pendant que
les fonctions réseau sont suspendues. Les secrets de connexion restent dans
le stockage sécurisé, sans nouvelle table de contrôle des appareils.

## 5. Table `dogs` : chiens du compte

| Colonne | Type SQLite prévu | Signification |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY NOT NULL` | Identifiant du profil chien. |
| `account_id` | `TEXT NOT NULL` | Compte propriétaire, référence vers `accounts.id`. |
| `name` | `TEXT NOT NULL` | Nom du chien. |

Le modèle initial se limite au nom. Sa synchronisation avec le serveur pourra
être ajoutée à terme ; le format de cette synchronisation n’est pas défini.

`tracks.dog_name` reste la donnée déjà prévue pour la piste. Le choix d’un
éventuel lien supplémentaire vers `dogs.id` et l’effet d’un renommage de chien
sur les anciennes pistes restent à préciser. Aucun `dog_id` n’est ajouté au
schéma actuel par ce document.

## 6. Sessions Pro

Ces tables servent aux regroupements locaux du carnet de l’organisateur. Elles
sont utilisées par les outils Pro ; les points GPS restent dans le carnet
commun. Elles sont distinctes des `auth_sessions` de connexion du serveur.
Le serveur porte l'état de la session active et son échéance de six heures ;
ces tables locales conservent le contexte et les liens historiques du carnet.
Une coupure réseau ou la fermeture de l'app conserve la session côté serveur.
La déconnexion volontaire du compte demande la sortie de participation, ou la
fermeture pour tous si l'utilisateur est l'organisateur. Sans réseau, le départ
confirmé est uniquement local, sans commande persistante à rejouer.
Une session créée reste gérable jusqu'à sa clôture ou son expiration serveur,
même après expiration de Pro et redémarrage de l'app.

### Table `sessions`

| Colonne | Type SQLite prévu | Signification |
| --- | --- | --- |
| `id` | `TEXT PRIMARY KEY NOT NULL` | Identifiant de la session. |
| `name` | `TEXT NOT NULL` | Nom. |
| `organizer_id` | `TEXT NOT NULL` | Identifiant du compte organisateur. |
| `created_at` | `INTEGER NOT NULL` | Création de la session côté serveur. |
| `ended_at` | `INTEGER NULL` | Fermeture effective ou expiration, une fois terminée. |
| `expires_at` | `INTEGER NOT NULL` | Échéance serveur, initialement six heures après création ; distincte de la fermeture anticipée. |
| `latitude` | `REAL NULL` | Latitude de référence, si renseignée. |
| `longitude` | `REAL NULL` | Longitude de référence, si renseignée. |

La session est active dès sa création : `created_at` suffit pour son début et
pour calculer son échéance. Aucun état de session planifiée n'est prévu.
Un départ local sans réseau ne renseigne pas une fermeture serveur dans
`ended_at` ; les dates et l'état serveur sont relus à la reconnexion.

### Table `session_tracks`

| Colonne | Type SQLite prévu | Signification |
| --- | --- | --- |
| `session_id` | `TEXT NOT NULL` | Référence vers `sessions.id`. |
| `track_id` | `TEXT NOT NULL` | Référence vers la copie locale dans `tracks.id`. |
| `participant_id` | `TEXT NULL` | Identifiant du participant associé, compte ou invité, si connu ; correspondance à définir avec le protocole réseau. |

Le couple `session_id`/`track_id` est unique. Le lien porte sur une piste déjà
disponible dans le carnet de l'organisateur, reçue ou enregistrée localement.
Pour une piste reçue, l'ajout du lien attend la réception complète et la
validation de la copie finale. Le live ne crée aucune ligne de piste ou de lien.
Les associations historiques suivent les règles de conservation du
[document technique](../technique.md#7-sessions-pro-et-droits-daccès).

## 7. Données prévues dont le stockage reste à préciser

Les besoins suivants sont définis, mais leur traduction en colonnes ou tables
n’est pas encore arrêtée :

- Durée effective cumulée par rôle et contexte de droits de l'exercice,
  nécessaires à la validation, aux rapports et à une reprise après interruption.
  Les seules dates de début et de fin ne suffisent pas.
- Lieu descriptif, résultat manuel, bilan et annotations localisées.
- Contexte de session, organisateur et nom/pseudo du participant lorsqu'ils
  accompagnent une copie partagée, sans créer les tables d'organisation Pro
  chez le participant. Le pseudo peut être celui d'un invité sans compte.
- Météo au départ de la pose et du chien : température, humidité relative,
  vitesse et direction d’origine du vent, date de validité, lieu et source.
  Les conditions d’origine accompagnent la réutilisation d’une trace traceur.
- Métadonnées et mécanismes nécessaires à la reprise des transferts finaux.

Le carnet conserve les mêmes données pour toutes les offres. Les rapports et
la pollution sont calculés depuis ces données ; le niveau de rapport suit
l’offre actuelle. Le PDF est une restitution figée générée à la demande.

Structures exclues du périmètre actuel :

- `account_monthly_usage` : aucune table dédiée pour l'instant. Le quota est
  synchronisé avec le serveur, avec dépassement occasionnel toléré. Son stockage
  minimal et son cache restent à définir ; supprimer une piste ne recrédite rien.
- `report_tier` et `report_tier_set_at` : aucun niveau de rapport figé par piste.
- Table de points GPS SQL : les points sont conservés en JSONL.
- Table de pollution, archive de live ou table de chemins dessinés : la
  pollution est calculée et les deux dernières données restent temporaires.

La référence de Track Assist est le JSONL traceur déjà conservé avec la piste.
Le chemin dessiné est réservé au mode traceur et reste hors du stockage persistant.

## 8. SharedPreferences : réglages locaux

Les petites préférences de l’installation sont séparées des données du compte
et du carnet. Elles fonctionnent également sans compte et peuvent rester lors
d’un changement de compte.

Structure proposée, avec des valeurs d’exemple ; les valeurs initiales de son,
vibration et activation restent à valider dans l’interface :

```json
{
  "app.language": "system",
  "app.theme": "system",
  "app.units": "metric",
  "map.base_layer": "classic",
  "track_assist.enabled_by_default": false,
  "track_assist.alert_distance_m": 25.0,
  "track_assist.sound_enabled": true,
  "track_assist.vibration_enabled": true,
  "track_assist.return_notification_enabled": true
}
```

Chaque propriété est une clé de préférence distincte, avec une valeur scalaire.
`app.language` et `app.theme` peuvent suivre le système. Les unités initialement
proposées sont métriques. `map.base_layer` identifie un fond, sans stocker ses
tuiles. La distance d’alerte est en mètres et reste réglable dans l’interface.

`enabled_by_default` est une préférence pour le démarrage de l’assistance, pas
un enregistrement GPS actif restauré automatiquement au lancement. Les droits
de l’exercice sont vérifiés séparément.

## 9. Secrets et informations relues

Les jetons de connexion NoseTrack sont conservés dans le stockage sécurisé du
téléphone. Les mots de passe, leurs hashes et les tables d’authentification du
serveur ne sont pas copiés dans SQLite ou SharedPreferences.

La version et le numéro de build sont lus depuis l’application installée. Les
autorisations de localisation et de notifications sont interrogées auprès du
système via le module de permissions ; leur état n’est pas une préférence
persistée faisant référence.

## 10. Décisions restantes

Les points de stockage et de migration sont regroupés dans le
[TODO des données locales](../todo.md#3-enregistrement-et-données-locales).
Les modèles réseau et leurs liens au carnet sont dans le
[TODO des sessions et transferts](../todo.md#4-sessions-invités-et-transferts).
