# Fonctionnalités

Spécification fonctionnelle du produit cible. Le périmètre initial des rapports
est défini ; les analyses ultérieures, les aides avancées de Track Assist et
certains paramètres d'interface restent à préciser.

- [Rapports Gratuit et Premium : première version](rapports.md).
- [Données, quotas, copies et sessions](technique.md).
- [Maquette interactive de l’accueil sur la carte](maquettes/index.html).
- [Base de données de l’application](database/app.md).
- [Base de données du serveur](database/server.md).

## 1. Principes et accueil

### Vocabulaire et carnet commun

- **Trace traceur** : enregistrement réalisé en mode traceur.
- **Trace chien** : enregistrement réalisé en mode chien.
- **Piste** : une fiche du carnet, correspondant à une entrée SQL, contenant une
  ou deux traces GPS : traceur seule, chien seule, ou les deux.
- **Rapport** : page de consultation d'une piste, avec des informations et des
  indicateurs calculés. Deux niveaux existent : Gratuit et Premium, selon l'offre.
- **Session** : groupe créé avec l'offre Pro pour organiser les exercices, suivre
  les enregistrements en live et recevoir les traces.
- **Chemin dessiné** : parcours temporaire sur la carte pour guider le traceur,
  partageable, sans ajout au carnet ni enregistrement en base. Il est réservé
  au mode traceur.

Toutes les pistes locales ou reçues sont dans le carnet. Les sessions Pro ajoutent
uniquement des associations et des filtres sur cette base commune.

Avec un compte connecté, le rapport est accessible avec une seule trace. La
présence de deux traces permet également la superposition et les indicateurs
comparatifs.

### Accueil et carte

L'accueil est une carte plein écran, déplaçable, zoomable et rotative, avec des
noms de lieux lisibles horizontalement. Trois fonds sont prévus : classique,
satellite et relief 2D. Le téléchargement de zones hors connexion n'est pas
retenu pour l'instant.

Les commandes prévues permettent de choisir le fond, de se centrer sur sa
position, de remettre le cap au nord et de démarrer ou terminer un enregistrement.
La position courante affiche sa précision et un cap lorsqu'il est disponible.
Le carnet et la participation à une session sont accessibles depuis cet accueil.
La [maquette](maquettes/README.md) illustre cette disposition.

La consultation de la carte utilise la localisation uniquement au premier plan.
Un enregistrement démarre dans l'application active, sur action explicite, puis
continue dans les autres menus, en arrière-plan et écran éteint. Il se termine
normalement avec le bouton d'arrêt dans l'application active. Le changement de
compte et la déconnexion volontaire suivent l'exception de finalisation décrite
au chapitre 9. Une destruction du processus peut interrompre l'acquisition ;
sa reprise exige une action explicite, selon
[le fonctionnement natif](../docs/tracking.md#format-et-récupération).

### Récupération d'une piste interrompue

À l'ouverture, si une piste était en cours lors d'une interruption du processus,
l'app propose trois choix, sans relancer automatiquement le GPS :

| Choix | Comportement |
| --- | --- |
| Reprendre | Continuer le même enregistrement et la même piste, en conservant les points déjà enregistrés. |
| Abandonner et supprimer | Supprimer la piste interrompue et ses traces, sans envoi final. |
| Terminer et sauvegarder | Finaliser les points déjà enregistrés sans relancer le GPS, puis appliquer le traitement normal de fin. |

La reprise ne crée pas une nouvelle utilisation. Terminer suit les règles de
validité, de quota et d'envoi à la session encore active. Un abandon applique
également le décompte d'un enregistrement chien valide avant sa suppression,
selon les droits de l'exercice ; il ne permet pas de contourner le quota.
Un enregistrement invalide ne consomme rien. Les détails de traitement figurent
dans [la récupération technique](technique.md#récupération-à-louverture).

Si la piste contient déjà l'autre trace, la confirmation d'abandon précise
qu'elle sera supprimée elle aussi. L'utilisateur peut annuler ce choix et
conserver la piste interrompue.

## 2. Compte et offres

### Connexion et abonnement

Le site et l'application utilisent le même compte NoseTrack, identifié par un
identifiant interne stable. Chaque compte possède un seul nom/pseudo obligatoire,
non unique, utilisé notamment dans les sessions.

| Sujet | Règle |
| --- | --- |
| Moyens de connexion | E-mail/mot de passe, au maximum un compte Google et un compte Apple liés. |
| E-mail | Obligatoire pour terminer la création ; demandé si le fournisseur ne le transmet pas. Les adresses relais Apple sont acceptées. |
| Activation | Un compte e-mail/mot de passe est utilisable immédiatement ; sa confirmation d'e-mail est proposée ensuite. |
| Liaison | Authentifier le compte existant et valider le nouveau moyen ; aucune fusion automatique par e-mail. |
| Changement d'e-mail | L'ancienne adresse reste active jusqu'à confirmation de la nouvelle. |
| Retrait d'une connexion | Autorisé seulement si un autre moyen validé reste configuré. |
| Appareils | Plusieurs téléphones et le site peuvent rester connectés simultanément, sans limite ni exclusion automatique d'un autre appareil. |

Si une nouvelle identité présente un e-mail déjà utilisé, le parcours propose
une liaison après connexion au compte existant. Un abandon ou un échec ne crée
pas de second compte. Avec des e-mails différents, l'utilisateur doit lui-même
choisir de lier les moyens ; sans liaison, une nouvelle création peut produire
un compte distinct. La liaison est accessible pendant la connexion et dans les
réglages du compte.

Le changement d'e-mail et le retrait d'un moyen demandent une nouvelle
authentification. Ils conservent l'identifiant du compte, ses pistes et ses
abonnements. Une demande de changement d'e-mail expirée ou annulée laisse
l'adresse active inchangée.

Premium et Pro sont proposés en abonnement annuel à renouvellement automatique,
via l'App Store, Google Play ou le site. Les droits sont associés au compte,
indépendamment du moyen de connexion ou de paiement. Le serveur valide les
achats et transmet les droits à l'app. Les parcours détaillés et leurs structures
sont décrits dans [la base serveur](database/server.md#2-connexion).

### Droits sans connexion Internet

Un compte déjà connecté utilise les derniers droits validés par le serveur
jusqu'à leur échéance connue. L'absence de réseau ne retire donc pas un accès
Premium ou Pro dont cette échéance n'est pas atteinte.

À l'échéance, l'app applique les droits Gratuit tant qu'aucun renouvellement
n'a été vérifié. Seuls l'enregistrement en cours et la gestion de la session
déjà créée conservent les outils nécessaires jusqu'à leur fin. Le retour du
réseau déclenche une actualisation auprès du serveur ; si l'abonnement a été
renouvelé, les droits et leur nouvelle échéance sont mis à jour.

### Connexion au compte expirée ou révoquée

L'expiration ou la révocation de la connexion n'arrête pas un enregistrement
GPS local, y compris en arrière-plan. Le contexte du compte et les droits de
l'exercice restent associés à la piste ; l'app ne la transforme pas en piste
invitée et ne supprime pas le carnet.

Les fonctions réseau nécessitant cette connexion sont suspendues, notamment le
live et les envois de pistes. Au retour dans l'application active, l'app demande
de se reconnecter. Arrêter et sauvegarder localement reste possible sans cette
reconnexion. Choisir explicitement de se déconnecter ou de changer de compte
applique en revanche le parcours du chapitre 9.

Ce cas est distinct d'une simple coupure Internet et de l'expiration d'un
abonnement : chacun conserve ses propres règles.

### Sans compte

Sans compte, l'utilisateur peut enregistrer des traces traceur, conserver un
carnet, partager et recevoir des copies de pistes, y compris celles envoyées
par un Pro, et exporter son carnet.

Il peut rejoindre une session avec un pseudo temporaire généré automatiquement
et modifiable. Sa participation permet le live pendant ses enregistrements
traceur et la réception de pistes. Le droit de dessiner un chemin temporaire
pour guider le traceur est disponible pendant cette participation active.

Le carnet sans compte affiche une fiche textuelle minimale : nom du chien,
durée enregistrée et distance estimée, selon les données disponibles. Une valeur
non calculable est indiquée comme indisponible. Cette fiche n'ouvre pas le rapport
avec sa carte, la superposition et les autres contenus réservés aux comptes.

Aucun enregistrement chien ni rapport dans l'application n'est accessible sans
compte. Un compte est nécessaire pour consulter au minimum le rapport Gratuit
et en exporter un PDF. Les pistes reçues restent conservées ; après connexion
et import accepté du carnet, leurs rapports deviennent accessibles selon l'offre.
Le quota chien est lié à un compte, pas à l'installation.

### Gratuit avec compte

- Enregistrer des traces traceur sans limite de nombre.
- Enregistrer **deux traces chien valides par mois civil**, dans le fuseau local.
- Pendant ces enregistrements chien autorisés, utiliser une trace traceur comme
  référence, l'afficher ou la cacher, utiliser la superposition et Track Assist.
- Compléter une piste chien avec une trace traceur.
- Recevoir des pistes contenant une ou deux traces et les ajouter au carnet.
- Partager ses pistes, sans restriction d'offre.
- Exporter son carnet de pistes pour en conserver une sauvegarde.
- Consulter le rapport Gratuit : carte et superposition, durées enregistrées,
  distances estimées, délai entre la pose et le départ du chien, résultat et
  commentaire général, selon les données disponibles.
- Exporter le rapport d'une piste en PDF, avec le contenu correspondant à son
  offre au moment de l'export.
- Rejoindre volontairement une session par code ou proximité.
- Dans une session, envoyer sa trace et recevoir une confirmation de bonne
  réception ou une indication d'erreur.
- Disposer de l'outil de chemin dessiné temporaire pour le mode traceur pendant
  sa participation à une session Pro.

Lorsque le compteur connu indique deux enregistrements chien valides dans le
mois, un nouvel enregistrement chien est refusé. Le quota est synchronisé avec
le serveur ; un dépassement occasionnel lié au décalage entre appareils est
accepté, sans réservation ni blocage distribué. Une troisième piste ainsi
réalisée reste conservée. Les autres fonctions restent disponibles.

Le décompte intervient à la fin d'un enregistrement chien valide : au moins cinq
secondes d'enregistrement effectif et au moins un point GPS. Les périodes
d'interruption ne comptent pas dans cette durée. Un enregistrement trop court ou
sans point n'est pas conservé et ne consomme aucune utilisation. Une reprise du
même enregistrement ne provoque pas de décompte supplémentaire.

La date de fin dans le fuseau local détermine le mois de consommation. Supprimer
une piste ne restitue jamais une utilisation déjà consommée. Recevoir une piste,
même avec une trace chien, ne consomme pas le quota.

Ces deux enregistrements sont une limite d'enregistrement. Ils ne constituent pas
deux rapports Premium offerts et n'ouvrent pas la carte de pollution.

### Premium

Toutes les fonctionnalités gratuites, plus :

- Enregistrer des traces chien sans la limite de deux par mois.
- Afficher ou cacher la piste de référence pendant l'exercice.
- Utiliser Track Assist sans le quota d'enregistrement Gratuit.
- Accéder au rapport Premium : comparaison des distances, vitesse moyenne
  estimée de la trace chien, relecture du parcours, annotations localisées et
  débrief détaillé, selon les données disponibles.
- Consulter la météo associée à la pose et au départ du chien : température,
  humidité, vitesse et direction du vent, également reprises dans l'export PDF.
- Dessiner et partager un chemin temporaire à suivre en mode traceur, hors
  session également.
- Afficher la pollution calculée à partir des traces du carnet, pour la zone et
  la période sélectionnées.

### Pro

Toutes les fonctionnalités Premium, plus les outils de sessions :

- Créer et fermer une session.
- Permettre aux participants de la rejoindre par code ou proximité.
- Voir les participants présents et leurs enregistrements en live.
- Recevoir automatiquement leurs traces à la fin de l'enregistrement.
- Dessiner et partager un chemin temporaire destiné à un participant en mode
  traceur, y compris Gratuit.
- Sélectionner une personne et sa piste pour lancer un enregistrement chien.
- Consulter le rapport puis partager une copie de la piste.
- Relier les pistes du carnet à la session et les filtrer par session.
- Retrouver les sessions par chien, lieu et date et consulter leur synthèse.
- Séparer entraînements personnels et pistes rattachées aux sessions.

Pro s'adresse aussi aux particuliers : deux personnes peuvent organiser une
session à deux pour le live et la réception directe des traces. Il n'est pas
nécessaire d'exercer une activité professionnelle ou de gérer un groupe de quatre
ou cinq personnes.

### Synthèse

| Fonction | Sans compte | Gratuit avec compte | Premium | Pro |
| --- | --- | --- | --- | --- |
| Enregistrement chien | Aucun | Deux valides par mois civil | Sans cette limite | Sans cette limite |
| Fiche textuelle : chien, durée, distance | Oui | Oui | Oui | Oui |
| Rapport individuel | Aucun | Niveau Gratuit | Niveau Premium | Niveau Premium |
| Export PDF du rapport | Non | Niveau Gratuit | Niveau Premium | Niveau Premium |
| Partage et réception de copies de pistes | Sans restriction d'offre | Oui | Oui | Oui |
| Carte de pollution | Non | Non | Oui | Oui |
| Dessin d'un chemin temporaire pour le mode traceur | Pendant une session Pro active | Pendant une session Pro active | Oui | Oui |
| Rejoindre une session | Oui, pseudo temporaire | Oui | Oui | Oui |
| Création de nouvelles sessions | Non | Non | Non | Oui |

Le niveau de rapport suit toujours l'offre actuelle du lecteur, jamais celle de
l'expéditeur. Un passage à Premium enrichit aussi les rapports des anciennes
pistes ; un retour à Gratuit les simplifie, sans perte de données.

Si Premium ou Pro expire pendant un enregistrement, les outils Premium de cet
exercice sont maintenus jusqu'à sa fin. Cette prolongation est limitée à la piste
en cours ; les enregistrements suivants utilisent les droits du compte à leur
démarrage.
Après la fin de l'exercice, son rapport suit l'offre alors applicable au compte.

Une session déjà créée reste gérable par son organisateur jusqu'à sa fermeture
ou son expiration serveur, même si Pro expire ou si l'app redémarre. Cela couvre
le live, la réception des pistes et la fermeture de cette session. Créer une
nouvelle session exige toujours Pro.

Ces deux maintiens sont liés à l'enregistrement ou à la session concernés,
jamais à la durée d'ouverture de l'app. Partout ailleurs, notamment pour les
rapports et la pollution, l'offre actuelle s'applique. Les pistes et leurs liens
restent conservés ; aucun maintien n'est transféré à un autre compte.

## 3. Réutiliser une trace traceur

L'interface propose de réutiliser la trace traceur d'une piste existante pour un
nouvel exercice chien.

- Une nouvelle fiche de piste est créée pour la nouvelle recherche.
- Seule la référence traceur est copiée, sans reprendre l'ancienne trace chien.
- La nouvelle trace chien vient compléter cette nouvelle piste.
- La piste d'origine et son enregistrement chien éventuel restent intacts.
- Les dates GPS de la référence copiée restent celles de son enregistrement réel.

Ce fonctionnement utilise le modèle actuel d'une piste avec au maximum deux
traces. Aucun changement de schéma SQL n'est nécessaire pour la réutilisation.

Le modèle permet également de compléter une fiche avec son rôle manquant.
Le parcours d'interface qui choisit entre compléter la fiche et réutiliser une
copie reste à définir dans le [TODO local](todo.md#3-enregistrement-et-données-locales).

## 4. Partager une copie de piste

Tout utilisateur peut partager une piste, sans restriction d'offre. Le destinataire
reçoit une copie indépendante dans son propre carnet, avec une ou deux traces et
les données complémentaires disponibles.

Chaque import volontaire crée une nouvelle copie indépendante, même si le même
fichier a déjà été importé. L'utilisateur gère ces copies dans son carnet.

Les modifications du nom, du chien, des commentaires ou d'autres métadonnées
restent chez la personne qui les effectue. Il n'existe pas de propagation de ces
modifications vers l'expéditeur ou les autres destinataires.

Un nouveau partage est un nouvel envoi de copie, pas une synchronisation. Le
partage ne modifie ni l'offre du destinataire ni son quota chien. Le niveau du
rapport et les outils disponibles dépendent de ses droits.

### Supprimer une piste dont un envoi est en attente

L'app demande confirmation en indiquant que la suppression arrête les tentatives
d'envoi non encore confirmées par le serveur. Si l'utilisateur confirme, la piste
est supprimée et ces envois sont annulés, sans bloquer la suppression ni conserver
une copie locale uniquement pour forcer leur acheminement ultérieur.

Une copie déjà prise en charge par le serveur ou déjà reçue par une autre personne
reste indépendante : la suppression locale ne l'efface pas à distance.
La suppression et l'annulation d'envoi ne restituent aucune utilisation chien.

## 5. Sessions

### Une session active, portée par le serveur

Une personne ne peut créer ou rejoindre qu'une seule session active à la fois,
qu'elle soit organisatrice ou participante. Elle doit fermer ou quitter la
session courante, ou attendre son expiration, avant d'en utiliser une autre.
Pour un compte, cette règle est commune à ses téléphones ; leur connexion
simultanée ne permet pas de rejoindre plusieurs sessions différentes.

Le serveur porte son état et sa durée : **six heures après sa création** pour
l'instant. La session expire automatiquement à cette échéance, même si aucun
téléphone n'est connecté. L'organisateur peut la fermer avant ; un participant
peut quitter sa propre participation sans fermer la session des autres.

Une coupure réseau ou la fermeture de l'application ne ferme pas la session et
ne vaut pas sortie volontaire. La reconnexion retrouve son état encore valide
sans prolonger l'échéance. En revanche, se déconnecter volontairement du compte
demande de quitter la session ; si l'utilisateur en est l'organisateur, la
demande ferme la session pour tous. La finalisation et l'envoi éventuel précèdent
cette sortie. Sans réseau, seul le départ local est possible, selon les règles
ci-dessous.

Le serveur date la prise d'effet des entrées, sorties et fermetures lorsqu'il
les accepte. Une demande hors réseau n'est pas considérée comme déjà appliquée
sur le serveur. Ces dates d'état restent distinctes des dates de mesure GPS,
qui conservent leur horaire réel sur les traces.

### Rejoindre et voir les participants

- La personne trouve une session à proximité ou utilise son code, puis choisit
  explicitement de la rejoindre. La proximité ne provoque pas d'entrée automatique.
- Sans compte, la participation utilise un pseudo temporaire généré
  automatiquement et modifiable ; elle ne crée pas de compte NoseTrack.
- Un compte Pro qui rejoint la session d'autrui y est un participant Premium en
  interne ; il ne devient pas organisateur.
- Ce niveau interne n'est pas affiché dans la liste des participants.
- Seul l'organisateur dispose de la visibilité de groupe sur les pistes et le live.
  Les participants n'obtiennent pas automatiquement les pistes des autres membres.
- Chacun conserve l'accès à son propre carnet et aux copies explicitement reçues.

### Enregistrement et live

1. Un participant démarre un enregistrement dans la session : ce départ de la
   piste démarre le live.
2. L'organisateur peut voir et suivre cet enregistrement, sans sauvegarder le live.
3. À la fin validée et sauvegardée d'un enregistrement, la piste est transmise à
   l'organisateur si la participation et la session étaient encore actives à
   cet instant. Elle rejoint son carnet uniquement après sa réception complète.
4. Le participant reçoit la confirmation de réception complète par le serveur,
   ou une indication d'erreur. Le serveur prend alors en charge la livraison à
   l'organisateur, qui peut être hors ligne.

Le live est possible **uniquement pendant un enregistrement de trace**. Être dans
la session ou afficher sa position sur la carte ne suffit pas à publier un live.
La fin de l'enregistrement termine ce live. La confirmation d'envoi signifie
que le serveur a reçu et conservé la piste complète pour sa livraison ; elle
n'exige pas que le téléphone de l'organisateur l'ait déjà téléchargée.

Une fois cet envoi final autorisé, son acheminement reste valable même si la
session ferme ou expire ensuite, sauf annulation explicitement confirmée par
l'utilisateur avant prise en charge complète par le serveur. Le carnet de
l'organisateur reçoit la copie après son téléchargement complet et sa validation.
Un retard ou un échec ne
transforme jamais le live en piste de remplacement ; l'état d'envoi reste visible.

Le live n'est jamais enregistré ni utilisé pour reconstruire une piste conservée.
Il sert uniquement à l'affichage temporaire. La copie ajoutée au carnet de
l'organisateur vient toujours de la piste finalisée envoyée par le participant.
Un enregistrement finalement invalide ne produit donc aucune piste chez
l'organisateur, même si son début a été vu en live. Un enregistrement abandonné
depuis la récupération n'est pas envoyé non plus.

Si une personne rejoint la session avec un enregistrement déjà commencé, le live
peut montrer toute la trace depuis son début. La piste reçue après sa fin contient
elle aussi toute la trace, pas seulement la partie réalisée après l'entrée.

La même règle s'applique après une sortie suivie d'une nouvelle entrée dans la
session pendant le même enregistrement. L'état de participation et de session
au moment de la fin détermine l'envoi ; une sortie antérieure ne l'interdit pas
définitivement.

Dans le déroulement habituel, l'organisateur Pro sélectionne la piste traceur
puis effectue l'enregistrement chien. Son compte n'a pas le quota Gratuit. Si un
participant effectue lui-même un enregistrement chien, c'est l'offre et le quota
de son compte qui s'appliquent ; ce n'est pas le déroulement habituel de la session.

### Quitter ou fermer

- Une sortie confirmée par le serveur retire le participant de la liste et du
  live de l'organisateur.
- Fermer la session, ou atteindre son expiration serveur, met fin à la
  participation de tous ses membres et au live.
- Un participant Gratuit ou sans compte perd alors le droit de dessiner un chemin
  lié à cette participation. Son droit illimité d'enregistrer des traces traceur
  est conservé. Pendant un enregistrement traceur en cours, le chemin déjà
  affiché reste visible jusqu'à la fin, sans permettre de nouveau dessin hors session.
- Une sortie ou fermeture de session n'arrête pas l'enregistrement GPS local :
  celui-ci se termine normalement par le bouton d'arrêt dans l'application
  active. Un changement de compte demandé par l'utilisateur le finalise aussi
  avant de poursuivre sa procédure.
- Si la personne n'est plus participante au moment de la fin, l'organisateur ne
  reçoit aucune piste finale pour cet enregistrement. La sortie arrête et efface
  le live ; une nouvelle entrée peut le réactiver et rétablir l'envoi à la fin.
  Une session fermée ou expirée avant la fin ne reçoit aucun nouvel envoi.
- Les pistes déjà présentes dans les carnets restent conservées lorsqu'une
  personne quitte la session ou que celle-ci est fermée.

### Sortie ou fermeture sans réseau

L'app avertit que le serveur ne peut pas confirmer la sortie ou la fermeture,
puis laisse l'utilisateur quitter localement après confirmation. Sur ce
téléphone, le live cesse et les droits liés à la participation cessent de
s'appliquer. Quitter la session seule laisse le GPS local continuer ; une
déconnexion de compte suit la finalisation du chapitre 9.

Aucune commande de sortie ou de fermeture n'est conservée pour un nouvel essai
automatique. Le serveur peut donc garder la participation ou la session jusqu'à
une nouvelle action explicite en ligne ou l'expiration des six heures. L'app
n'annonce pas une fermeture distante réussie et ne garantit pas que les autres
téléphones voient immédiatement ce départ.

Au retour du réseau, l'app affiche l'état réel du serveur. Si la session est
encore active, l'utilisateur peut de nouveau demander de quitter ou de fermer,
ou choisir de continuer dans cette session. Le retour du réseau seul ne reprend
ni le live ni les envois finaux. Tant que l'utilisateur reste sorti localement,
la fin de son enregistrement ne crée aucun nouvel envoi à cette session. Un
choix explicite de continuer dans la session rétablit les règles ordinaires
d'une participation active. Les envois déjà autorisés avant le départ suivent
les règles habituelles, avec annulation confirmée lors d'une transition de
compte si nécessaire.

## 6. Chemin dessiné temporaire

Le chemin dessiné indique au traceur le parcours à suivre sur la carte pendant
la pose de la piste. Il peut être préparé et partagé pour guider temporairement
le destinataire en mode traceur. Il n'est jamais utilisé en mode chien ni comme
référence de Track Assist.

Il n'est jamais enregistré en base et ne crée pas de piste dans le carnet. Il ne
remplace pas la trace traceur d'une piste et ne représente pas un passage réel à
inclure dans la pollution.

Il reste disponible pendant les changements de menu, l'arrière-plan et l'écran
éteint. Il disparaît lors de son remplacement, à la fin de l'enregistrement
traceur concerné ou lorsque le processus de l'application est détruit. Un retour
depuis l'arrière-plan conserve donc le chemin ; un nouveau lancement après
destruction de l'application ne le restaure pas. Sa disparition n'empêche pas
la reprise de l'enregistrement GPS traceur.

Pour un participant Gratuit ou sans compte, une sortie, fermeture ou expiration
de session pendant l'enregistrement traceur conserve le chemin déjà affiché
jusqu'à la fin de cet enregistrement. Le droit de créer de nouveaux dessins
hors session reste réservé à Premium et Pro.

## 7. Track Assist

Track Assist accompagne un enregistrement chien en gardant la référence cachée.
Sa référence est toujours une trace GPS de traceur enregistrée, dans le respect
des droits associés à l'exercice. Le chemin dessiné appartient uniquement au
mode traceur. L'aide est automatique et discrète, utilisable sans regarder
constamment l'écran.

### Première version

- **Alerte d'éloignement** : prévenir lorsque la distance à la référence dépasse
  durablement le seuil choisi. Un point GPS isolé ne suffit pas à déclencher
  l'alerte.
- **Retour dans la zone** : signaler discrètement que l'on est revenu dans le
  couloir de référence après une alerte.
- **Son et/ou vibration** : choisir la manière de recevoir ces indications.
- **Suspension de l'assistance** : couper les alertes sans arrêter
  l'enregistrement GPS ni le live éventuel, puis pouvoir réactiver l'assistance.

L'assistance reste utilisable lors des changements de menu, en arrière-plan et
écran éteint, tant que l'enregistrement continue.

À la reprise d'un enregistrement chien, l'assistance réutilise la trace GPS
traceur conservée avec la piste. Sans trace traceur exploitable, l'enregistrement
chien reste possible, mais Track Assist est indisponible.

### Options paramétrables dans l'interface

L'utilisateur peut configurer Track Assist depuis l'interface :

- Activer ou suspendre l'assistance.
- Choisir la distance de déclenchement de l'alerte, en mètres.
- Activer ou désactiver le son et le vibreur indépendamment : son seul,
  vibration seule, les deux ou aucun.
- Activer ou désactiver la notification de retour dans la zone.
- Configurer les rappels hors zone et les aides de figures lorsqu'ils seront
  disponibles.

### Réglages de départ à tester sur le terrain

| Paramètre | Valeur initiale |
| --- | --- |
| Seuil d'éloignement | Plus de 25 m de la référence. |
| Confirmation de l'éloignement | Pendant 5 secondes consécutives avec des positions exploitables. |
| Retour dans la zone | Moins de 15 m après une alerte d'éloignement. |
| Fréquence des notifications | Une alerte à la sortie, puis une au retour. |

Ces valeurs sont des réglages par défaut à tester ; la distance d'alerte est
modifiable dans l'interface. Elles ne sont pas validées pour tous les téléphones
et terrains. L'écart entre les seuils de sortie et de retour évite les alertes
répétées lorsque l'on reste près d'une limite. Un rappel périodique hors zone
pourra être proposé en option ; sa fréquence reste à définir.

La distance d'alerte et le son/vibreur sont les réglages principaux.
Le délai de confirmation et le seuil de retour peuvent être gérés en interne.
Le seuil de retour s'adapte à la distance choisie et reste inférieur à celle-ci ;
15 m correspond au réglage de départ avec une alerte à 25 m.

### Aides sur les figures, dans une étape suivante

Après validation de la première version sur le terrain, des aides automatiques
ponctuelles pourront concerner :

- Un virage serré apparemment manqué ou une zone de changement de direction
  dépassée.
- Une progression durable en sens inverse de la référence.
- Des portions proches, un retour sur soi-même ou un croisement pouvant faire
  suivre la mauvaise branche.

Le traceur ou l'organisateur pourra aussi préparer des repères sur les zones
difficiles pour guider ces aides, avant une détection entièrement automatique
des figures. Leur définition et leur conservation restent à préciser.

L'utilisateur pourra activer les aides de figures et choisir leur niveau lorsque
ces aides seront disponibles. Elles doivent tenir compte de la progression sur
la référence et de la qualité GPS. Lorsque plusieurs branches restent plausibles,
l'assistance indique une incertitude plutôt qu'une direction présentée comme sûre.

Track Assist ne propose ni bouton « Un indice », ni révélation temporaire d'un
tronçon de référence. La piste reste cachée pendant l'assistance.

Les règles de calcul et les limites sont décrites dans le
[document technique](technique.md#10-track-assist).

## 8. Carnet, rapports et pollution

### Rapports

Le carnet conserve les mêmes données pour toutes les offres et sans compte.
Avec un compte connecté, une piste ouvre une page de rapport, même avec une
seule trace. La seconde trace permet les comparaisons disponibles. Le contenu
Gratuit/Premium, les calculs, la météo et
les règles d'export sont définis dans [les rapports](rapports.md).

Le niveau suit l'offre actuelle du lecteur, y compris pour les anciennes pistes.
Le PDF est un document figé selon les droits de la personne qui l'exporte ; son
destinataire le lit intégralement, indépendamment de son compte.

### Pollution

La pollution est réservée à Premium et Pro. Elle utilise **toutes les traces GPS
du carnet, traceur et chien**, y compris celles de pistes reçues.

Le paramètre initial est une fenêtre des **six dernières heures**, sur les dates
réelles des passages. La date de réception ou de copie ne rajeunit jamais une
trace. La zone est définie autour d'un centre et d'un rayon à préciser.

En Pro, le lien à une session ajoute un filtre sur cette même base. Les sessions
et leurs liens sont persistés ; le résultat de pollution ne l'est jamais.
Les règles de filtrage sont décrites dans
[le document technique](technique.md#9-pollution--toutes-les-traces-du-carnet-six-heures).

## 9. Carnet, connexion et sauvegarde

### Confirmations et annulation

Quand une action nécessite une confirmation, regrouper ses conséquences connues
dans un seul écran : arrêt de l'enregistrement, sortie ou fermeture de session,
suppression du carnet selon le cas. L'export éventuel est proposé avant la
suppression. Éviter de redemander plusieurs fois l'accord pour les mêmes effets.
Une nouvelle erreur de sauvegarde ou d'envoi fait toutefois l'objet d'un choix
explicite, car elle ajoute un risque qui n'était pas prévu au départ.

Avant de lancer le traitement, annuler conserve le contexte courant. Si un arrêt,
une sauvegarde, un envoi ou une fermeture a déjà réussi, renoncer ensuite à la
transition ne l'annule pas : l'app indique ce qui a été effectué, sans redémarrer
automatiquement le GPS ni rappeler une copie déjà envoyée.

### Sans compte vers un compte

Lors de la connexion, l'application demande à l'utilisateur s'il veut importer
son carnet sans compte dans celui du compte cible. L'import dépend de son choix ;
il n'est pas effectué automatiquement.

Si l'utilisateur refuse, le carnet sans compte est supprimé. Cette conséquence
est affichée dans un avertissement avant son choix ; elle ne doit pas être une
suppression silencieuse.

### Déconnexion simple et retour au même compte

Une simple déconnexion conserve le carnet sur le téléphone, isolé et associé
à son compte d'origine. Il n'apparaît pas dans le carnet sans compte ni dans
celui d'un autre utilisateur. Une reconnexion au même compte retrouve ce carnet.
La conservation locale est privilégiée ; elle ne constitue pas une sauvegarde cloud.

### D'un compte vers un autre

Aucun transfert ni proposition d'import n'est effectué entre les deux comptes.
Le carnet de l'ancien compte est supprimé lors du passage à un compte différent,
y compris après une déconnexion intermédiaire. Un avertissement annonce cette
suppression et propose l'export avant la transition. Le carnet sans compte
éventuellement créé entre-temps suit son propre choix d'import.

### Déconnexion ou changement de compte pendant un enregistrement

Avant de poursuivre, l'application avertit que cette action arrête la piste
en cours. Le parcours est séquentiel :

1. Arrêter et finaliser avec le compte ou le contexte sans compte qui a démarré
   l'enregistrement : validation, sauvegarde de la trace valide et décompte
   éventuel du quota.
2. Si un envoi final à l'organisateur est autorisé, envoyer la piste et attendre
   la confirmation de réception complète par le serveur. Les envois déjà
   autorisés en attente suivent le même circuit, sauf annulation explicitement
   confirmée après échec. Le téléphone de l'organisateur peut être hors ligne.
3. Quitter la session comme participant, ou la fermer pour tous comme
   organisateur, puis poursuivre la déconnexion ou le changement de compte avec
   les avertissements, l'export éventuel et le choix d'import applicables au carnet.

La sortie ou fermeture s'applique aussi à un changement d'identité sans
enregistrement en cours, y compris lors du passage d'une participation invitée
à un compte. Rejoindre ensuite une session sous la nouvelle identité reste une
action explicite.

Si un envoi échoue, l'app avertit l'utilisateur et propose de réessayer ou de
continuer après confirmation en annulant les envois non encore acceptés par le
serveur. Cet envoi n'est pas repris automatiquement lors d'une future connexion.
Une copie déjà acceptée par le serveur reste livrable à l'organisateur.
Si la sauvegarde locale échoue, l'app avertit de la perte possible de la piste
et laisse le choix de réessayer, de rester dans le contexte actuel ou de
continuer malgré l'erreur après confirmation explicite. La confirmation permet
de poursuivre la déconnexion ou le changement de compte sans attendre une
sauvegarde réussie. L'enregistrement est arrêté avant de quitter son contexte ;
l'app n'annonce pas une piste sauvegardée et ne crée pas d'envoi final à partir
de données non validées. Les données déjà sauvegardées suivent les règles
habituelles de conservation et d'isolation du carnet.

Après confirmation de départ malgré une indisponibilité réseau, l'app quitte
son contexte local et cesse sa publication, sans mettre en attente de commande
de sortie ou de fermeture. L'état distant suit les règles de
[sortie sans réseau](#sortie-ou-fermeture-sans-réseau).
Aucun envoi annulé n'est transféré au nouveau compte.
L'enregistrement déjà arrêté reste arrêté. Une trace invalide ne déclenche aucun
envoi. L'annulation d'envoi ne change pas une consommation chien déjà validée.

### Export du carnet

L'export est accessible quelle que soit l'offre. Il permet de sauvegarder les
pistes, leurs traces GPS et leurs données complémentaires, sans modifier le
carnet courant. Il ne transfère pas l'abonnement ou le quota du compte. Le format
et les modalités de restauration seront précisés avec cette fonction.

## 10. Points restant à préciser

Les décisions encore ouvertes et les évolutions à définir sont centralisées
dans le [TODO des spécifications](todo.md). Les choix validés restent dans les
chapitres précédents et les documents spécialisés.
