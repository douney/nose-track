# Base de données du serveur

Modèle logique prévu pour les comptes, la connexion et les abonnements.
Aucun serveur ni schéma de migration correspondant n’est implémenté ici.
Le moteur SQL et l’outil d’authentification restent à choisir ; ce dernier
pourra fournir certaines tables techniques décrites ci-dessous.

- [Base locale de l’application](app.md).
- [Fonctionnalités et offres](../fonctionnalites.md).
- [Règles de gestion des données](../technique.md).

## 1. Une base serveur commune au site et à l’application

Le site et l’application utilisent la même API NoseTrack et la même base
serveur pour les comptes et les droits. L’application possède en complément
son SQLite local. Elle accède à la base serveur par l’API.

Le compte possède un identifiant NoseTrack stable partagé par le site et l’app.
Il est indépendant de l’e-mail, du fournisseur de connexion et du canal de
paiement. Les tables serveur ne sont pas intégralement copiées dans SQLite.

Les identifiants sont décrits ici comme des UUID, les dates comme des instants
UTC, et les booléens comme des valeurs logiques. Leur type SQL physique sera
adapté au moteur retenu.

## 2. Connexion

Trois moyens sont prévus : Google, Apple, et e-mail avec mot de passe. Le compte
créé sur le site est utilisable dans l’application et réciproquement.

Un compte peut disposer d’une connexion e-mail/mot de passe, d’un compte Google
et d’un compte Apple au maximum. La liaison exige l’authentification du compte
existant et la vérification du nouveau moyen. Une égalité d’e-mail ne déclenche
pas de fusion automatique.

Le serveur vérifie les preuves de connexion Google et Apple avant d’utiliser
l’identifiant du fournisseur. Cet identifiant est conservé séparément du profil.
Google recommande l’identifiant `sub` plutôt que l’e-mail pour identifier le
compte. Voir [la validation Google côté serveur](https://developers.google.com/identity/sign-in/web/backend-auth).

### Table `accounts`

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Identifiant NoseTrack. |
| `display_name` | Texte obligatoire, non unique | Nom ou pseudo affiché pour le compte et dans les sessions. |
| `email` | Texte obligatoire, unique après normalisation | E-mail du compte, fourni par le fournisseur ou saisi à la création ; également utilisé pour la connexion e-mail/mot de passe si activée. |
| `email_verified_at` | Date UTC facultative | Vérification de cet e-mail. |
| `password_hash` | Texte facultatif | Hash de mot de passe ; absent pour un compte uniquement Google/Apple. |
| `created_at` | Date UTC | Création. |
| `updated_at` | Date UTC | Dernière modification. |

Le compte possède un seul nom/pseudo d’affichage obligatoire, non vide après
retrait des espaces de bord. Il n’y a pas de champs prénom et nom séparés.
Plusieurs comptes peuvent utiliser le même nom/pseudo ; seul `id` identifie le
compte. Aucune contrainte `UNIQUE` ne porte sur `display_name`.
Le nom fourni par Google ou Apple peut préremplir ce champ ; s’il manque, le
parcours de création demande de le renseigner avant de terminer la création.

Un e-mail est obligatoire pour terminer la création, quel que soit le moyen
de connexion. Si Google ou Apple n’en transmet aucun, le parcours demande à
l’utilisateur d’en saisir un. Une adresse relais Apple est acceptée. La saisie
d’un e-mail ne crée pas de mot de passe et ne prouve pas que l’adresse appartient
à l’utilisateur ; `email_verified_at` reste vide jusqu’à sa vérification.
Si l’adresse saisie correspond à un compte existant, le même parcours de liaison
après authentification s’applique, sans création d’un second compte.

Les contrôles de création, de liaison et de changement d'adresse doivent
identifier un seul compte pour un e-mail normalisé. La normalisation et la
contrainte SQL correspondante seront fixées avec l'outil d'authentification.
Cette unicité ne permet pas d'authentifier ou de fusionner des comptes par leur
seul e-mail. Aucun mot de passe en clair n'est stocké.
L’offre effective est calculée à partir des droits d’abonnement validés, plutôt
que modifiée directement par le client sur cette ligne.

#### Activation et confirmation de l’e-mail

Un compte créé avec e-mail et mot de passe est utilisable immédiatement, selon
les droits de son offre. La confirmation de l’adresse est proposée ensuite et
ne bloque pas l’accès aux fonctions nécessitant un compte.

`email_verified_at` reste vide tant que l’adresse n’est pas vérifiée. Le serveur
renseigne cette date après validation de la preuve correspondante. Cet état ne
remplace pas l’authentification exigée pour lier un nouveau moyen de connexion.

Une adresse relais Apple peut recevoir et confirmer un message tout en restant
privée. `email_verified_at` indique donc une vérification de l’adresse, pas
l’obtention de l’adresse personnelle derrière le relais. Voir le
[fonctionnement du relais Apple](https://www.apple.com/legal/privacy/data/en/sign-in-with-apple/).
Les adresses privées ou relais sont acceptées. Aucune adresse personnelle
supplémentaire n’est demandée pour tenter de reconnaître un compte existant :
l’e-mail peut différer entre deux fournisseurs et ne constitue pas
l’identifiant NoseTrack. Lors d’une connexion ultérieure avec une identité déjà
liée, l’absence d’e-mail dans la réponse du fournisseur n’efface pas celui du
profil et ne déclenche pas une nouvelle demande de saisie.

#### Modification de l’e-mail

L’utilisateur authentifie de nouveau son compte avec un moyen déjà lié avant
de demander une modification. La nouvelle adresse est conservée comme demande
en attente dans `account_action_tokens`, avec le but `change_email` et son
`target_email`. `accounts.email` et sa date de vérification restent inchangés
jusqu’à la confirmation de cette nouvelle adresse.

Pendant cette attente, l’ancienne adresse reste celle du profil et, si un mot
de passe est configuré, celle de la connexion par mot de passe. La nouvelle
adresse ne donne aucun accès au compte. Une nouvelle demande remplace la
précédente en invalidant son jeton ; une demande expirée ou annulée n’a aucun
effet sur l’adresse active.

À la confirmation d’un jeton valide, le serveur vérifie de nouveau l’absence
de conflit avec un autre compte, puis met à jour `accounts.email`,
`email_verified_at` et `updated_at`, et marque le jeton comme utilisé dans
une même transaction. Les autres jetons de vérification, de changement
d’e-mail et de réinitialisation du mot de passe du compte sont invalidés.
Un conflit ne fusionne jamais les comptes et laisse l’ancienne adresse active.

Le changement conserve `accounts.id`, les données, les abonnements et les
identités Google/Apple déjà liées. L’e-mail renvoyé lors d’une connexion sociale
ne remplace pas automatiquement l’adresse du profil choisie et confirmée ici.
La nouvelle authentification pour une modification sensible suit les
[recommandations OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#require-re-authentication-for-sensitive-features).

### Table `auth_identities`

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Identifiant du lien. |
| `account_id` | UUID | Référence vers `accounts.id`. |
| `provider` | Texte | `google` ou `apple`. |
| `provider_user_id` | Texte | Identifiant utilisateur validé du fournisseur. |
| `created_at` | Date UTC | Création du lien. |
| `updated_at` | Date UTC | Dernière modification. |

Deux contraintes d’unicité s’appliquent :

- `UNIQUE(provider, provider_user_id)` : une même identité externe appartient
  à un seul compte NoseTrack.
- `UNIQUE(account_id, provider)` : un compte NoseTrack possède au maximum une
  identité Google et une identité Apple.

La liaison d’un autre compte du même fournisseur est refusée tant que le lien
existant est présent ; il n’est jamais remplacé implicitement. Le mot de passe
du site est porté par `accounts.password_hash`, pas par une fausse identité Google ou Apple.
Une fois l’identité liée, son identifiant fournisseur permet de retrouver le
même compte même si l’e-mail transmis par le fournisseur change.

### Gestion des moyens de connexion

#### Nouvelle identité avec un e-mail déjà utilisé

Si l’identité Google/Apple est déjà liée, la connexion retrouve le compte par
son identifiant fournisseur validé. Une nouvelle identité, encore inconnue de
NoseTrack, dont l’e-mail correspond à un compte existant déclenche une
proposition de liaison :

1. Demander de se connecter au compte existant avec un moyen déjà associé.
2. Après authentification et accord de l’utilisateur, lier la nouvelle identité
   à ce même compte NoseTrack.
3. Conserver son identifiant, ses données et ses abonnements.

Si l’utilisateur abandonne ou si l’authentification échoue, aucun second compte
n’est créé et aucun lien n’est ajouté. L’e-mail seul ne suffit jamais à accorder
l’accès au compte existant. La normalisation utilisée pour comparer les e-mails
reste à préciser.

#### Identités utilisant des e-mails différents

Une identité Google avec une adresse personnelle et une identité Apple avec
une adresse relais ne peuvent pas être reconnues automatiquement comme
appartenant à la même personne. Avant de créer un compte avec une nouvelle
identité, le parcours permet de choisir de se connecter à un compte existant
pour y lier cette identité, après authentification et accord de l’utilisateur.
La liaison est également accessible depuis les réglages du compte connecté.

Sans cette liaison, une création avec une identité inconnue et un e-mail
différent peut créer un autre compte NoseTrack. Un e-mail différent n’autorise
aucune fusion automatique. Toutes les identités explicitement liées pointent
vers le même `accounts.id` ; les données et abonnements restent attachés à cet
identifiant. Le caractère privé de l’e-mail ne change pas ce rattachement.

#### Retrait d’un moyen de connexion

L’utilisateur authentifie de nouveau son compte avant de retirer un moyen de
connexion. Le retrait est refusé s’il ne resterait aucun autre moyen configuré.
L’utilisateur doit d’abord en ajouter un autre et terminer sa validation.

Les moyens pris en compte sont le mot de passe configuré dans
`accounts.password_hash` et les liens Google/Apple dans `auth_identities`.
Un e-mail sans mot de passe et une session de connexion déjà ouverte ne sont
pas des moyens supplémentaires. Cette règle concerne aussi le retrait du
mot de passe d’un compte uniquement e-mail/mot de passe.

Le contrôle et le retrait sont effectués dans une même transaction serveur,
avec sérialisation des changements des moyens de connexion pour ce compte :
deux retraits simultanés ne doivent pas pouvoir supprimer les deux derniers
moyens. Aucun compteur ni champ supplémentaire n’est nécessaire.
Le retrait d’un lien ne supprime ni le compte, ni ses données, ni son abonnement.
Une identité retirée ne permet plus de nouvelles connexions à ce compte.

### Table `auth_sessions`

Il s’agit des connexions par appareil ou navigateur, distinctes des groupes de
mantrailing appelés `sessions` dans le carnet local.

Plusieurs téléphones et navigateurs peuvent rester connectés simultanément au
même compte, sans limite d'appareils ni exclusion automatique. Chaque connexion
dispose de sa propre session et de son propre jeton ; connecter un nouvel
appareil ne révoque pas les précédents.

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Session de connexion. |
| `account_id` | UUID | Référence vers `accounts.id`. |
| `refresh_token_hash` | Texte | Hash du jeton de renouvellement NoseTrack. |
| `created_at` | Date UTC | Création. |
| `expires_at` | Date UTC | Expiration de la session de connexion. |
| `revoked_at` | Date UTC facultative | Révocation explicite. |

Cette structure permet des sessions révocables. Le protocole de renouvellement,
la rotation des jetons et les durées seront définis avec l’authentification.
Plusieurs lignes actives peuvent référencer le même `account_id` : aucune
contrainte d’unicité ne porte sur cette colonne seule. Une session peut être
révoquée indépendamment des autres. Aucune table `devices` ni champ de téléphone
actif n'est nécessaire pour contrôler un remplacement d'appareil.

Une expiration ou révocation empêche les opérations réseau qui exigent cette
connexion. Elle ne commande pas l'arrêt du GPS local : l'app conserve la piste
en cours et demande une reconnexion au retour au premier plan, selon
[les règles de connexion](../technique.md#connexion-au-compte-expirée-ou-révoquée).

### Table `account_action_tokens`

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Identifiant du jeton temporaire. |
| `account_id` | UUID | Référence vers `accounts.id`. |
| `purpose` | Texte | `verify_email`, `change_email` ou `reset_password`. |
| `target_email` | Texte facultatif | Adresse exacte à vérifier ; obligatoire pour `verify_email` et `change_email`. |
| `token_hash` | Texte | Hash du jeton à usage unique. |
| `created_at` | Date UTC | Création. |
| `expires_at` | Date UTC | Expiration. |
| `used_at` | Date UTC facultative | Utilisation du jeton. |

Un jeton est lié à son compte, à son but et, pour une vérification ou un
changement d’e-mail, à l’adresse exacte de la demande. Le serveur ne prend pas
l’adresse à appliquer dans un paramètre fourni au moment de la confirmation.
Un jeton `verify_email` ne peut confirmer que l’adresse encore active du compte.
Un jeton `change_email` ne peut appliquer que son `target_email`.

La demande de changement d’e-mail en attente est déduite du jeton non utilisé,
non expiré et de son adresse cible. Il n’y a pas de champ `pending_email` dans
`accounts`, ni de table dédiée. Un jeton expiré, invalidé ou déjà utilisé est
refusé ; les durées de validité restent à préciser. Les détails du parcours de
récupération du mot de passe restent à définir.

## 3. Abonnements annuels

Premium et Pro sont proposés en abonnement annuel à renouvellement automatique.
Le canal de paiement est indépendant du moyen de connexion au compte.

| Canal d’achat | Intégration prévue |
| --- | --- |
| Application iOS | Achat intégré App Store. |
| Application distribuée sur Google Play | Google Play Billing. |
| Site | Prestataire de paiement web, à choisir. |

L’accès est rattaché au compte NoseTrack et utilisable sur ses appareils.
La connexion précède l’achat pour permettre ce rattachement. La restauration
d’un achat doit retrouver son compte associé ; changer de compte NoseTrack sur
le téléphone ne réattribue pas automatiquement cet achat.

Les achats intégrés sont la règle générale pour ces fonctions numériques ; les
exceptions et possibilités de lien vers le site dépendent du marché et des
programmes applicables. Les parcours de paiement seront validés à la publication
selon les [règles Apple](https://developer.apple.com/app-store/review/guidelines/#payments)
et [Google Play](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en).

### Table `subscriptions`

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Identifiant local au serveur de l’abonnement. |
| `account_id` | UUID | Référence vers `accounts.id`. |
| `provider` | Texte | `apple`, `google` ou `web`. |
| `environment` | Texte | Environnement de production ou de test du fournisseur. |
| `provider_subscription_ref` | Texte | Référence permettant de retrouver l’achat chez le fournisseur. |
| `provider_product_id` | Texte | Produit ou tarif du fournisseur. |
| `plan` | Texte | Offre achetée : `premium` ou `pro`. |
| `status` | Texte | État validé : par exemple en attente, actif, grâce, expiré ou révoqué. |
| `current_period_start` | Date UTC facultative | Début de la période de facturation connue. |
| `current_period_end` | Date UTC facultative | Fin de cette période. |
| `access_until` | Date UTC facultative | Échéance d’accès établie après validation de l’état. |
| `auto_renew` | Booléen | Renouvellement automatique activé ou désactivé. |
| `verified_at` | Date UTC facultative | Dernière validation auprès du fournisseur. |
| `created_at` | Date UTC | Création de la ligne. |
| `updated_at` | Date UTC | Dernière actualisation. |

Le triplet `provider`/`environment`/`provider_subscription_ref` est unique et
rattache un achat identifié à un seul compte NoseTrack. `account_id` n’est pas
unique : l’historique et les changements d’abonnement doivent être représentables.

La référence correspond à l’identifiant de transaction d’origine Apple, au
jeton d’achat Google ou à l’identifiant d’abonnement du prestataire web. Les
détails de chaînage lors des changements de produit, ainsi que les champs
spécifiques aux fournisseurs, seront précisés lors de l’intégration. Les jetons
nécessaires aux vérifications restent dans un stockage serveur protégé et ne
sont pas copiés dans le SQLite de l’app ou exposés dans les journaux.

Le serveur vérifie un achat avant d’accorder les droits. Google décrit notamment
la conservation et la validation du jeton d’achat ainsi que son association au
bon compte dans [ses recommandations de validation](https://developer.android.com/google/play/billing/security).

La liste finale des états et leur correspondance avec les états Apple, Google
et web restent à définir. La fin de facturation et la fin d’accès sont distinctes
pour pouvoir représenter une grâce ou une révocation. Désactiver le prochain
renouvellement ne supprime pas, à lui seul, la période d’accès déjà payée.

### Produits et offre effective

Les produits annuels des trois canaux sont associés aux offres Premium et Pro.
Ce petit catalogue peut rester en configuration dans un premier temps, sans
table supplémentaire. Le prestataire et ses identifiants de tarifs web restent
à choisir.

L’API renvoie l’offre effective et son échéance à l’application. L’ensemble des
abonnements pertinents doit être pris en compte ; le traitement d’une seule
notification ne doit pas effacer un autre droit encore valide. Les règles de
passage Premium/Pro et de prévention des achats simultanés restent à définir.

L'app peut utiliser les derniers droits validés hors réseau jusqu'à l'échéance
transmise, puis appliquer Gratuit en attendant une nouvelle validation, sous
réserve des maintiens d'outils déjà définis. Elle vérifie de nouveau les droits
au retour du réseau. Cette politique locale ne crée aucune période facturée
supplémentaire et ne modifie pas l'état de `subscriptions`.

## 4. Notifications de facturation

Le serveur reçoit les événements Apple, Google et du prestataire web, vérifie
leur provenance et actualise les droits : renouvellement, expiration, paiement
en échec, remboursement ou révocation. Le protocole précis sera adapté à chaque
fournisseur.

### Table `billing_events`

| Colonne | Type logique | Signification |
| --- | --- | --- |
| `id` | UUID, clé primaire | Identifiant interne de l’événement. |
| `provider` | Texte | Canal de facturation. |
| `environment` | Texte | Production ou test. |
| `provider_event_id` | Texte | Identifiant de notification fourni par le canal. |
| `subscription_id` | UUID facultatif | Référence vers `subscriptions.id`, une fois l’achat identifié. |
| `event_type` | Texte | Type d’événement reçu. |
| `received_at` | Date UTC | Réception. |
| `processed_at` | Date UTC facultative | Traitement terminé. |
| `processing_error` | Texte facultatif | Échec de traitement à reprendre. |

Le triplet `provider`/`environment`/`provider_event_id` est unique. Une répétition
de notification n’accorde pas un second abonnement. Une notification ancienne
ou reçue en retard ne doit pas écraser un état fournisseur plus récent ; son
traitement doit établir l’état actuel et supporter les reprises.

La conservation éventuelle des messages bruts n’est pas imposée par ce modèle.

## 5. Autres données et limites du périmètre

### Sessions de mantrailing et transferts

Le serveur porte les sessions actives et les participations. Un compte ne peut
créer ou rejoindre qu'une session à la fois, tous ses téléphones confondus ; la
même règle s'applique à l'identité temporaire d'un invité. L'échéance initiale
est de six heures après création ; fermeture explicite ou expiration termine la session.
Un participant peut quitter avant. Une coupure réseau ou la fermeture de
l'app conserve la participation. Une déconnexion volontaire du compte demande
au contraire de quitter comme participant, ou de fermer pour tous comme
organisateur. Les dates d'effet de ces actions sont attribuées par le serveur
à leur acceptation, sans réécrire les dates de mesure GPS.

Sans réseau, l'utilisateur peut confirmer un départ uniquement local. L'app
ne conserve aucune commande de sortie ou de fermeture à rejouer ; le serveur
peut garder l'état jusqu'à une nouvelle action explicite en ligne ou l'échéance
de six heures. La reconnexion consulte cet état réel, sans fermeture rétroactive.
Cette règle ne supprime pas les mécanismes de reprise des transferts finaux
autorisés et non annulés.

Une session créée reste gérable par son organisateur jusqu'à fermeture ou
expiration, même après expiration de Pro et redémarrage de l'app. L'exception
est liée à cette session et à son organisateur ; créer une nouvelle session
requiert toujours Pro.

Le modèle doit aussi représenter les invités au pseudo temporaire généré et
modifiable, sans créer de faux compte `accounts` ni de session de connexion
`auth_sessions` fictive. Les tables Pro locales ne suffisent pas à ce modèle réseau.

Le serveur reçoit les pistes finalisées, valide leur réception complète et
conserve la copie à livrer avant de confirmer l'envoi au participant. Cet accusé
permet de terminer une déconnexion ou un changement de compte. En cas d'échec,
l'utilisateur peut aussi confirmer la poursuite en annulant les envois restants
non pris en charge. Une suppression volontaire confirmée peut les annuler aussi.
Les copies déjà acceptées par le serveur restent livrables indépendamment.
Le téléphone de l'organisateur peut récupérer la copie plus tard, y compris
après fermeture ou expiration de la session si l'envoi était déjà autorisé.

Le stockage de transit des pistes finalisées doit donc permettre cette livraison.
Son modèle, sa reprise et sa durée de conservation sont à définir. Les points
du live restent éphémères ; ils ne constituent jamais une archive SQL ou fichier.

### Carnet, quota et droits

- Le carnet reste local. La future sauvegarde cloud de toutes les pistes est
  distincte du transit des pistes envoyées dans une session.
- Les profils chiens sont décrits dans [la base de l'app](app.md#5-table-dogs--chiens-du-compte).
  Leur synchronisation future n'a pas encore de schéma serveur.
- Le quota est synchronisé avec le serveur ; un dépassement occasionnel lié au
  décalage entre appareils est accepté. Aucune réservation distribuée ni table
  `account_monthly_usage` n'est prévue pour l'instant. Le stockage minimal reste
  à définir selon [les invariants du quota](../technique.md#3-quota-chien-et-validité).

Les maintiens d'outils Premium/Pro sont des règles d'application, indépendantes
des périodes réellement facturées et non transférables à un autre compte.
Ils concernent uniquement l'enregistrement en cours et la session déjà créée,
sans maintien général lié à la durée d'ouverture de l'app. Leur traduction en
autorisations serveur reste à spécifier.

## 6. Décisions restantes

Les points de connexion, droits, abonnements, quota et modèle réseau sont
centralisés dans le [TODO des spécifications](../todo.md). Les règles déjà
validées restent décrites dans les chapitres précédents.
