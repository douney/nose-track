# Règles techniques de gestion des données

Ce document décrit les mécanismes du produit cible, sans modifier le code ni
le schéma SQL actuel. Les comportements utilisateur sont définis dans les
[fonctionnalités](fonctionnalites.md). Les API et le format JSONL déjà
implémentés sont décrits dans [la localisation native](../docs/tracking.md).

- [Index des spécifications](README.md).
- [Rapports, calculs et PDF](rapports.md).
- [Schéma local et préférences](database/app.md).
- [Comptes, authentification et abonnements serveur](database/server.md).

## 1. Carnet commun et rapport calculé

Une piste correspond à une fiche `tracks` et à une ou deux traces JSONL : traceur,
chien ou les deux. Les points sources sont immuables. Ajouter le rôle manquant
complète la même fiche sans réécrire l'autre trace ; reprendre une trace
interrompue continue son journal, sans modifier ses points antérieurs.

Toutes les offres conservent les mêmes données GPS et métadonnées. Le rapport
est une vue calculée de la fiche, sans entité ou fichier de rapport indépendant.
Son contenu et ses règles de calcul sont centralisés dans [les rapports](rapports.md).
L'accès à cette vue exige un compte ; une piste reçue sans compte reste une
fiche du carnet, sans rapport accessible avant connexion et import accepté.

## 2. Réutilisation d'une référence traceur sans nouveau schéma SQL

Pour un nouvel exercice à partir d'une piste existante :

1. Créer une nouvelle fiche avec un nouvel identifiant local.
2. Copier uniquement le fichier traceur et ses métadonnées techniques.
3. Conserver coordonnées, dates de mesure, dates d'enregistrement et conditions
   météo d'origine disponibles.
4. Enregistrer la nouvelle trace chien dans cette fiche.

L'ancienne trace chien n'est pas copiée. Chaque fiche possède ses propres
fichiers : supprimer une copie ne casse pas la référence d'une autre piste.
La copie ne représente pas un nouveau passage pour la pollution.
Ce mécanisme utilise les deux rôles existants, sans nouveau champ SQL.
Le choix d'interface entre ce nouvel exercice et l'ajout du rôle manquant dans
une fiche existante reste à définir dans le [TODO local](todo.md#3-enregistrement-et-données-locales).

## 3. Quota chien et validité

### Compte et droits de l'exercice

Les droits Sans compte/Gratuit/Premium/Pro sont définis dans
[les offres](fonctionnalites.md#2-compte-et-offres). Le quota est lié au compte
qui effectue l'enregistrement, commun à ses appareils et indépendant des
réinstallations ou suppressions de pistes. Un Pro qui enregistre pour un
participant ne débite pas le quota de ce participant.

Si Premium ou Pro expire pendant une piste, le maintien des outils Premium
concerne le même enregistrement, y compris sa reprise après interruption.
Cette piste n'est pas rétroactivement décomptée comme un enregistrement Gratuit.
Ce contexte doit être conservé pour la reprise ; les enregistrements suivants
utilisent les droits réels au démarrage. Le maintien ne crée aucun niveau
historique de rapport.

### Durée et validation

Un enregistrement valide exige **au moins cinq secondes effectives et un point
GPS dans le rôle nouvellement enregistré**. Une référence traceur copiée ne
valide pas un enregistrement chien sans point.

La durée cumule les périodes où le service enregistre. Les interruptions sont
exclues ; l'arrière-plan et l'écran éteint comptent tant que le natif continue.
Elle ne se déduit pas simplement de `ended_at - started_at` et doit survivre à
une interruption du processus.

La validation intervient à la fin. Le journal peut être provisoirement présent
pendant l'acquisition. Une trace invalide est nettoyée sans supprimer l'autre
rôle valide déjà présent. Si aucune trace valide ne subsiste dans une nouvelle
fiche, cette fiche n'est pas conservée dans le carnet. Une interruption reste
récupérable ; reprendre le même enregistrement ne crée pas un nouvel exercice.

### Récupération à l'ouverture

La réconciliation native identifie les traces `interrupted` avant que
l'application propose un choix. Aucun GPS ni foreground service n'est relancé
par la seule détection. L'action est effectuée dans l'application active et
reste associée au compte ou au contexte invité et aux droits de l'exercice.

- **Reprendre** : conserver la fiche, le rôle, les points et leur séquence,
  puis continuer dans un nouveau segment. La période d'interruption n'ajoute
  aucune durée effective et ne devient pas une portion GPS artificielle.
- **Terminer et sauvegarder** : finaliser sans nouvelle acquisition. La date de
  finalisation est celle de cette action ; les dates des points existants restent
  inchangées et le temps d'interruption reste exclu de la durée effective.
  Appliquer la validation, le quota et l'autorisation d'envoi ordinaires à cet
  instant. Une nouvelle trace invalide est nettoyée sans effacer l'autre rôle
  valide éventuellement présent.
- **Abandonner et supprimer** : mettre fin à l'enregistrement puis supprimer
  explicitement la fiche et ses fichiers, y compris l'autre rôle s'il est présent
  dans cette piste, après une confirmation qui annonce cette conséquence.
  Les autres pistes du carnet restent indépendantes. Aucun transfert final
  n'est créé pour l'enregistrement abandonné. Un enregistrement
  chien valide est décompté une seule fois avant suppression selon les droits
  de l'exercice ; une utilisation déjà comptée n'est jamais comptée à nouveau.

La validité exige toujours cinq secondes effectives et un point dans le rôle
concerné. Un abandon invalide ne consomme rien. Le maintien Premium d'un exercice
repris reste applicable, même si les droits généraux du compte ont expiré.

### Décompte et calendrier

Le décompte intervient une seule fois à la fin valide d'un enregistrement chien.
Le mois civil est celui de la fin dans le fuseau local, même si le début était
le mois précédent. La date UTC et le fuseau retenus doivent permettre de
retrouver ce mois sans qu'un changement ultérieur de fuseau le réaffecte.

Le compteur par compte est synchronisé avec le serveur. Quand l'état connu
atteint deux consommations, l'app refuse un nouveau démarrage chien Gratuit.
Un décalage entre appareils peut occasionnellement laisser passer une troisième
utilisation : ce dépassement est accepté et les pistes valides sont conservées.
Aucune réservation préalable ni coordination distribuée garantissant un quota
strict n'est prévue. La synchronisation met à jour le compteur pour la suite.

Une reprise ou une nouvelle tentative de finalisation ne compte jamais deux
fois le même enregistrement. La suppression ne restitue rien : le suivi des
consommations est indépendant de la présence des pistes.
Aucune table `account_monthly_usage` n'est prévue pour l'instant ; le stockage
minimal, le cache du compteur et sa synchronisation restent à préciser dans
le [TODO](todo.md#2-abonnements-et-quota). La règle d'utilisation des droits
d'abonnement hors réseau est définie au chapitre 8.

Ne consomment pas de quota chien : enregistrement traceur, partage, réception,
restauration, ajout d'une référence traceur, consultation ou export de rapport.

## 4. Partage de copies indépendantes

À la réception d'une piste partagée :

1. Valider le contenu reçu.
2. Créer une fiche locale indépendante et ses propres fichiers.
3. Conserver les traces, leurs dates d'origine et toutes les métadonnées
   disponibles, quelle que soit l'offre du destinataire.
4. Présenter la piste avec ses droits actuels.

L'identité de provenance peut accompagner la copie, sans créer de lien de
synchronisation. Chaque import volontaire utilise un nouvel identifiant, même
pour un fichier déjà importé. Aucune fusion, détection de doublon ou propagation
des modifications n'est prévue. Un nouveau partage ne doit pas écraser une
copie déjà modifiée chez son destinataire.

Le format d'échange, sa version et son extension restent à choisir. Une archive
avec manifeste, JSONL et métadonnées est une possibilité, pas un format validé.
L'API native `importTrace` importe actuellement un seul rôle dans une fiche
existante ; elle ne constitue pas encore ce parcours de partage complet.

Les reprises automatiques d'un même transfert de session utilisent au contraire
une identité de transfert stable pour ne créer qu'une copie, selon le chapitre 6.

### Suppression volontaire et envoi en attente

Si la piste fait l'objet d'un envoi non confirmé par le serveur, demander une
confirmation indiquant que la suppression arrête les tentatives restantes.
Après confirmation, annuler localement ces envois et supprimer la piste selon
le circuit habituel, sans verrou de suppression ni copie de secours imposée.
Cette règle vaut aussi si un abandon supprime une piste dont une autre trace
avait un envoi antérieur en attente.

Une copie déjà acceptée par le serveur, ou déjà reçue chez un destinataire,
reste indépendante et n'est pas supprimée à distance. La suppression arrête les
tentatives locales ; elle ne garantit pas l'annulation d'une copie déjà transmise.
Le quota validé reste inchangé.

### Export et transitions de compte

Les choix utilisateur, avertissements et suppressions sont définis dans
[les parcours de connexion et sauvegarde](fonctionnalites.md#9-carnet-connexion-et-sauvegarde).
Les conséquences connues sont regroupées dans une confirmation ; une erreur
nouvelle laisse un nouveau choix. Une transition abandonnée après un arrêt ou
un envoi réussi ne défait pas ces opérations.
L'export conserve pistes, JSONL et métadonnées sans réduire le contenu selon
l'offre, sans supprimer le carnet courant et sans transférer droits ou quota.
Une restauration ne doit pas recréditer une consommation.

Un carnet sans compte peut être importé après accord ; un refus entraîne sa
suppression après avertissement. Aucun import n'est proposé entre deux comptes.
Une simple déconnexion conserve le carnet local isolé, rattaché à son compte
d'origine. Une reconnexion au même compte le retrouve. Le passage à un compte
différent entraîne sa suppression après avertissement et possibilité d'export,
même si une déconnexion a précédé. Le contexte propriétaire doit donc rester
identifiable localement après déconnexion, sans exposer son carnet en mode invité.
L'isolation physique ou logique sera définie avec les migrations locales.

### Finalisation avant déconnexion ou changement de compte

L'action explicite dans l'application active constitue l'exception prévue à
l'arrêt par le bouton d'arrêt. Après avertissement, le coordinateur suit cet
ordre, dans le contexte du compte ou de l'invité qui a démarré la piste :

1. Finaliser l'enregistrement, valider puis conserver ou nettoyer sa nouvelle
   trace, et appliquer le quota une seule fois. Le maintien Premium éventuel
   reste applicable.
2. Tenter les envois finaux autorisés et attendre leur prise en charge serveur.
   En cas d'échec, proposer de réessayer ou de poursuivre après confirmation
   explicite en annulant les envois non encore acceptés. Aucune reprise
   automatique de ces envois annulés n'est faite à une connexion ultérieure.
3. Demander la sortie de participation, ou la fermeture de la session pour tous
   si l'utilisateur en est l'organisateur. Sans réseau, proposer le départ local
   confirmé, sans commande différée. Cette action ne transfère jamais la
   participation à l'identité suivante.
4. Appliquer l'export ou le choix d'import du carnet applicable, puis terminer
   la déconnexion ou le changement de compte.

Une erreur de sauvegarde est signalée avec la perte possible de la piste.
L'utilisateur peut réessayer, rester dans son contexte ou confirmer explicitement
la poursuite malgré l'erreur. Dans ce dernier cas, arrêter l'acquisition et
libérer le contexte d'enregistrement avant la transition, sans annoncer une
sauvegarde réussie ni créer d'envoi final pour les données non validées.
La sortie ou fermeture de session et la transition d'identité suivent ensuite
le circuit normal. Les données déjà sauvegardées restent soumises aux règles
du carnet ; une consommation chien déjà validée n'est pas annulée.

L'enregistrement déjà finalisé n'est pas repris et son quota n'est pas décompté
deux fois. Une trace invalide ne déclenche aucun envoi.

Si l'utilisateur confirme le départ malgré l'indisponibilité réseau, les envois
restants sont annulés et l'app quitte son contexte local. Aucune commande de
sortie ou de fermeture n'est conservée pour un nouvel essai automatique.
L'état distant peut subsister jusqu'à une nouvelle action explicite acceptée
par le serveur ou l'expiration de la session, sans date d'effet rétroactive.
La reconnexion affiche l'état réel selon
[le parcours sans réseau](fonctionnalites.md#sortie-ou-fermeture-sans-réseau).
Une copie déjà prise en charge reste livrable par le serveur, indépendamment
de la déconnexion. L'annulation d'envoi ne restitue pas de quota.

## 5. Chemin dessiné temporaire

Le chemin dessiné sert uniquement de parcours à suivre en mode traceur. Il n'est
ni affiché comme guide en mode chien, ni fourni à Track Assist. Sa géométrie et
son partage sont distincts d'une piste GPS. Aucun `tracks`, fichier de trace GPS
ou champ SQL de référence n'est créé. Le chemin ne remplace pas la trace traceur
et ne représente pas un passage dans la pollution.

Le chemin appartient à l'état de l'application, plutôt qu'à celui du widget
carte, pour survivre aux menus et à l'arrière-plan. Son cycle de vie est défini
[dans les fonctionnalités](fonctionnalites.md#6-chemin-dessiné-temporaire) :
remplacement, fin de l'enregistrement traceur concerné ou destruction du processus.
Il n'est jamais restauré depuis un stockage persistant. La perte du dessin
n'empêche pas la reprise du GPS traceur.
Pour un participant Gratuit ou sans compte, la fin de participation retire le
droit de créer un dessin lié à la session, mais ne supprime pas le chemin déjà
affiché pendant un enregistrement traceur en cours : celui-ci reste disponible
jusqu'à la fin de l'enregistrement.

## 6. Sessions : participation et visibilité

Les parcours d'entrée et de sortie sont décrits dans
[les sessions](fonctionnalites.md#5-sessions). Une participation invitée utilise
un pseudo temporaire généré et modifiable, sans faux compte serveur. Son
identifiant et son autorisation réseau restent à définir avec le protocole.
Les conditions de publication sont distinctes du mode GPS local.

### État et durée côté serveur

Une seule session de mantrailing peut être créée ou rejointe à la fois. Le
serveur applique cette règle au compte sur l'ensemble de ses téléphones, ou à
l'identité temporaire pour un invité. Il conserve l'état de la session et fixe
son expiration à six heures après sa création.
Une fermeture acceptée termine la session ; une sortie acceptée termine la
participation concernée. L'expiration termine la session et ses participations.

Une coupure réseau ou une fermeture de processus ne constitue pas une sortie
volontaire ; l'app récupère l'état encore valide auprès du serveur sans prolonger
l'échéance. En revanche, une déconnexion volontaire du compte demande de quitter
la session, ou de la fermer pour tous si l'utilisateur est l'organisateur.
Sans réseau, le départ n'est que local et ne crée aucune commande à rejouer.
La participation serveur, la présence réseau et le départ local sont distincts.

Le serveur attribue les dates d'effet des actions de session lorsqu'il les
accepte. Une sortie ou fermeture hors réseau ne modifie pas l'état distant et
n'est pas rejouée au retour du réseau ; une nouvelle action explicite en ligne
est nécessaire pour l'appliquer. Les dates de mesure des points GPS restent
celles de l'acquisition. L'articulation avec une fin de piste hors réseau est à
préciser dans le protocole.
L'expiration applique les mêmes règles qu'une fermeture pour le live et les
futurs envois, sans arrêter le GPS local ni effacer les liens historiques.

### Live éphémère

Le live exige simultanément une session ouverte, une participation active et
un enregistrement de trace en cours. Le mode de localisation `foreground` ne
publie aucun live. Le démarrage de l'enregistrement démarre le live ; une entrée
en session pendant un enregistrement l'active également.
Une connexion au compte expirée ou révoquée suspend la publication sans arrêter
le GPS local. Après un départ local confirmé hors réseau, le retour du réseau
ne reprend pas silencieusement le live : l'app présente l'état serveur et laisse
l'utilisateur choisir de continuer dans la session ou de la quitter.

Le service peut transmettre l'historique de la trace en cours depuis le journal
local de l'émetteur, notamment lors d'une entrée en cours de piste. Les points
reçus restent en mémoire chez l'organisateur et ne sont jamais archivés par le
service live. Le participant conserve son journal natif local comme source.
La vue de groupe est réservée à l'organisateur ; les carnets et copies reçues
explicitement restent indépendants de cette visibilité.

### Fin, sortie et transfert

| Événement | Live | GPS local | Copie finale chez l'organisateur |
| --- | --- | --- | --- |
| Début ou entrée avec un enregistrement en cours | Actif si participation et session actives. | Continue. | Pas encore de copie. |
| Fin validée et sauvegardée avec participation et session actives | Terminé. | Enregistrement finalisé. | Envoi complet autorisé. |
| Fin invalide | Effacé. | Nouvelle trace rejetée. | Aucune copie. |
| Abandon d'une piste interrompue | Déjà interrompu. | Piste supprimée sur choix explicite. | Aucun envoi final. |
| Sortie avant la fin | Effacé jusqu'à une éventuelle nouvelle entrée. | Continue jusqu'à sa fin locale. | Aucun envoi si la personne reste absente à la fin ; nouvelle entrée active = envoi autorisé à la fin valide. |
| Fermeture ou expiration de la session avant la fin | Effacé. | Continue jusqu'à sa fin locale. | Aucun nouvel envoi à cette session. |
| Départ local confirmé sans réseau avant la fin | Publication locale arrêtée ; état distant non confirmé. | Continue, sauf finalisation liée à une déconnexion volontaire du compte. | Aucun nouvel envoi tant que le départ local est maintenu. |
| Sortie, fermeture ou expiration après une fin valide autorisant l'envoi | Déjà terminé. | Déjà finalisé. | Envoi serveur puis livraison maintenus. |

Une sortie acceptée par le serveur retire aussi la présence de la liste des
participants. Une fermeture acceptée, ou l'expiration, termine les participations
de tous. Un participant Gratuit ou sans compte perd le droit de créer un dessin
lié à cette participation,
mais garde le chemin déjà affiché pour terminer l'enregistrement traceur en cours.
Les pistes déjà reçues et leurs liens historiques restent conservés.

L'autorisation d'envoi dépend de l'état au moment de la fin valide : une sortie
puis une nouvelle entrée pendant le même enregistrement ne crée pas de veto
permanent. Si la session est ouverte et la participation active à la fin, l'envoi
de la piste entière est autorisé.

La copie finale contient toute la piste, y compris les points antérieurs à
l'entrée dans la session. Elle provient exclusivement de la source finalisée,
jamais du flux live. L'ajout au carnet et le lien à la session attendent la
réception complète et sa validation. Des fichiers temporaires de transfert
final ne constituent pas une archive du live.

### Confirmation serveur et livraison à l'organisateur

Le destinataire et le contexte d'un transfert sont fixés à la fin valide.
Une fois l'envoi autorisé, la fermeture ou l'expiration ultérieure de la session
ne l'annule pas. L'utilisateur peut toutefois annuler un envoi non encore pris
en charge, après confirmation lors d'une suppression ou d'une transition de compte.
Les étapes de l'acheminement normal sont distinctes :

1. Le serveur reçoit entièrement la piste finalisée, la valide et conserve
   une copie permettant sa livraison avant de confirmer la prise en charge.
2. Le participant peut terminer sa déconnexion ou son changement de compte dès
   cet accusé serveur, même si l'organisateur est hors ligne.
3. L'organisateur récupère ensuite la copie complète ; son carnet et le lien
   de session sont créés après téléchargement et validation.

La confirmation serveur ne signifie pas que l'organisateur a déjà téléchargé
ou consulté la piste. Des points reçus en live ne valent aucune de ces confirmations.
Le stockage de transit des fichiers finalisés est distinct de l'archive du live,
qui n'existe pas, et de la future sauvegarde cloud du carnet.

La reprise utilise la même piste et la même identité de transfert pour éviter
les doublons côté serveur et dans le carnet de l'organisateur. Un partage
volontaire reste un envoi indépendant. Protocole, reprise après coupure et
conservation du transit restent dans le [TODO](todo.md#4-sessions-invités-et-transferts).

## 7. Sessions Pro et droits d'accès

Les tables et leurs contraintes sont définies dans
[la base locale](database/app.md#6-sessions-pro). Les sessions regroupent les
pistes du carnet de l'organisateur ; elles ne dupliquent pas leurs points GPS.
La présence réseau actuelle et les associations historiques sont distinctes.
Un participant n'a pas besoin des tables Pro pour consulter une copie reçue.

Le maintien Pro est limité à la session déjà créée, selon
[les règles d'offre](fonctionnalites.md#2-compte-et-offres). Elle reste gérable
par son organisateur jusqu'à sa fermeture ou son expiration serveur, même après
redémarrage : suivi du live, réception des pistes et fermeture restent disponibles
dans ce contexte précis.
Créer une nouvelle session exige l'offre Pro ; les rapports individuels et les
autres droits continuent à suivre l'offre actuelle.

La perte de Pro ne détruit pas les pistes ni les liens historiques, qui peuvent
resservir lors d'un retour à Pro. Les maintiens d'outils sont distincts du niveau
actuel des rapports et des périodes réellement facturées par les fournisseurs.
Leur validation côté serveur reste à définir avec les API de sessions.

## 8. Offre actuelle et rapports

### Droits mémorisés hors réseau

Le cache conserve la dernière offre validée par le serveur, son `access_until`
et la date de vérification. Pour un compte connecté, l'app utilise cette offre
jusqu'à cette échéance connue, sans exiger une vérification réseau intermédiaire.
La seule absence de réseau ne constitue pas une déconnexion du compte.

Après l'échéance, le cache ne prolonge pas automatiquement l'offre payante :
les droits généraux deviennent Gratuit en attendant une nouvelle validation.
Sans droit payant validé avec une échéance connue, l'app n'invente pas un accès
Premium ou Pro. Seuls l'enregistrement en cours et la gestion de la session déjà
créée conservent leurs outils selon leurs propres limites. La durée d'ouverture
du processus ne prolonge aucun autre droit.

Au retour du réseau, l'app relit les droits auprès de l'API NoseTrack et actualise
son cache. Le nouvel état validé s'applique, y compris en cas de renouvellement,
de changement d'offre ou de révocation. Le cache ne génère aucune nouvelle
période d'abonnement et ne modifie jamais les données de facturation serveur.

### Connexion au compte expirée ou révoquée

La perte d'une connexion valide suspend les appels réseau qui l'exigent, sans
appeler l'arrêt du service natif ni changer le propriétaire du carnet. Les points
continuent dans le journal et le contexte de droits de l'exercice est conservé.
Une fin locale reste possible ; validation et quota suivent les règles ordinaires.
L'app distingue une sauvegarde locale réussie d'un envoi confirmé par le serveur.

Au retour dans l'app active, demander la reconnexion, selon
[le parcours fonctionnel](fonctionnalites.md#connexion-au-compte-expirée-ou-révoquée).
Ce n'est pas une déconnexion volontaire : ne pas lancer automatiquement la
finalisation, la purge du carnet ou une transition vers le contexte invité.
Les commandes explicites de déconnexion ou de changement de compte conservent
leur parcours habituel.

### Restitution des rapports

Le rapport exige un compte connecté et suit ses droits actuels à chaque
consultation, y compris si l'offre change sur une page déjà ouverte. Le maintien
d'outils pour terminer un exercice ne crée pas de rapport Premium permanent.
Le quota d'enregistrement n'est pas
recalculé quand l'affichage change.

Le module de rapports adapte les résultats éventuellement en mémoire aux droits
courants. Il utilise les mêmes calculs pour l'écran et le PDF, dont le contenu
est sélectionné aux droits de l'exporteur puis figé. Aucun champ `report_tier`
ou objet rapport persistant n'est nécessaire dans `tracks`.

Le contenu, les formules, la conservation de la météo et les limites sont
centralisés dans [les rapports](rapports.md). Modifier l'offre ne nécessite ni
réimport, ni réécriture des points, ni nouvelle génération d'une entité métier.

## 9. Pollution : toutes les traces du carnet, six heures

Les droits et la fenêtre initiale sont définis dans
[les fonctionnalités](fonctionnalites.md#pollution). La source comprend les deux
rôles du carnet, locaux ou reçus. Le filtre temporel utilise les dates réelles
des points, sans les rajeunir à la réception ou lors d'une copie.

Le filtrage spatial examine la géométrie, pas seulement le premier point de la
trace. Centre et rayon restent à préciser. `session_tracks` ajoute le filtre
Pro sur cette même base. Le résultat reste calculé pour l'affichage, sans
nouvelle table SQL ni trace persistante.

Une référence réutilisée ne représente pas un nouveau passage. La gestion des
copies identiques dans un rendu de densité et la période à utiliser pour une
ancienne session restent à définir.

## 10. Track Assist

### Entrées et indépendance de l'affichage

L'assistance compare les nouvelles positions chien à la ligne ordonnée de la
trace GPS traceur associée à la piste. Seul ce rôle enregistré sert de référence ;
un chemin dessiné n'est jamais une entrée de Track Assist. Elle ne modifie pas
les points GPS. Le calcul et les alertes sont indépendants du widget carte et
doivent fonctionner pendant l'enregistrement en arrière-plan
ou écran éteint. L'implémentation sera choisie lors du développement.

La suspension ne change pas le mode GPS, la journalisation ou le live.
Lors d'une reprise, la référence est relue depuis le JSONL traceur de la piste.
Sans trace traceur exploitable, l'assistance est indisponible ; cela n'empêche
ni la journalisation ni la finalisation de l'enregistrement chien.
Les paramètres et leur périmètre initial sont définis dans
[les fonctionnalités Track Assist](fonctionnalites.md#7-track-assist) ; leur
stockage local est proposé dans [les préférences](database/app.md#8-sharedpreferences--réglages-locaux).

### Éloignement et retour

Calculer la distance à la ligne de référence, pas uniquement au point enregistré
le plus proche. Le seuil d'alerte est configurable ; le seuil de retour reste
inférieur et s'adapte à ce choix. La règle d'adaptation reste à valider sur le
terrain. L'écart entre les seuils évite les oscillations d'alerte.

Une sortie durable confirmée déclenche une alerte ; le retour confirmé peut en
déclencher une autre selon les préférences. Les rappels périodiques sont une
évolution distincte. Les valeurs initiales sont regroupées dans
[les réglages de départ](fonctionnalites.md#réglages-de-départ-à-tester-sur-le-terrain).

Des positions absentes, trop anciennes ou imprécises ne confirment pas un
éloignement. Une interruption des positions exploitables remet la confirmation
à zéro ; le seul écoulement du délai ne déclenche rien. Les critères de qualité
et de fraîcheur doivent tenir compte de la référence et de la position courante.

### Progression et figures

La distance seule ne distingue pas un mauvais sens ou une branche proche.
Les aides avancées devront suivre l'ordre des segments et la progression dans
le temps, sans retenir systématiquement le segment le plus proche.

Virages, retours et branches proches auront leurs propres règles. Si plusieurs
interprétations restent plausibles, l'aide indique une incertitude. Des repères
préparés par le traceur ou l'organisateur sont envisagés ; leur modèle reste à
définir. Ces aides viennent après la première version. L'éventuel historique
d'alertes pour les rapports est une décision séparée, sans journal imposé ici.

## 11. Responsabilités

| Module | Responsabilité |
| --- | --- |
| Géolocalisation native | Acquisition et journalisation, transitions dans l'application active. |
| Coordinateur d'application | Enregistrement, validation, finalisation et envoi serveur avant déconnexion/changement de compte. |
| Track Assist | Analyse et alertes indépendantes du widget carte. |
| Carnet | Catalogue et fichiers propres à chaque piste, mêmes données pour toutes les offres. |
| Comptes et offres | Identité, droits actuels, contexte d'exercice et quota par compte. |
| Rapport | Calculs communs, page selon l'offre actuelle et PDF figé. |
| Partage | Copies indépendantes de pistes et géométries temporaires. |
| Sessions Pro | Présence, live éphémère, transferts finaux et liens historiques. |
| Pollution | Filtrage et rendu calculé depuis le carnet. |
