# Rapports : première version

Le rapport est la page de consultation d'une piste du carnet, avec des
informations et des indicateurs calculés à partir de ses données. Il existe deux
niveaux de rapport individuel : Gratuit et Premium. Pro donne accès au même
rapport individuel que Premium. Ce document définit le produit cible ; il ne
décrit pas une interface déjà implémentée.

- [Fonctionnalités et offres](fonctionnalites.md).
- [Données, droits et quota](technique.md).

## 1. Une piste, une page de rapport

Une piste correspond à une entrée SQL et contient :

- Une trace traceur seule.
- Une trace chien seule.
- Les deux traces ensemble.

L'ouverture d'un rapport dans l'application exige un compte connecté : Gratuit,
Premium ou Pro. Sans compte, les pistes peuvent être enregistrées en traceur,
reçues, partagées et conservées, mais aucun rapport ni export PDF de rapport
n'est accessible. Le carnet propose cependant une fiche textuelle minimale
avec nom du chien, durée enregistrée et distance estimée si disponibles. Cette
fiche ne constitue pas un troisième niveau de rapport. Après connexion et
import accepté du carnet invité, les rapports suivent l'offre actuelle du compte.

Le rapport présente les informations disponibles dans cette piste. La présence
des deux traces permet la superposition et la comparaison ; elle n'est pas une
condition pour ouvrir la page de rapport.

L'ajout d'une seconde trace complète la piste existante. Aucun nouveau rapport
indépendant n'est à créer. Les indicateurs sont calculés pour la consultation ;
les données renseignées, comme les observations ou la météo recueillie, restent
rattachées à la piste.

Une piste partagée peut être ajoutée au carnet d'un compte Gratuit, Premium ou
Pro, ou dans un carnet sans compte. Toutes les données sont conservées. Pour un
lecteur connecté, le niveau du rapport suit toujours son offre actuelle, jamais
celle de l'expéditeur : passer à Premium
enrichit aussi les rapports des anciennes pistes ; revenir à Gratuit les
simplifie. Les données restent conservées dans les deux cas. Voir
[les règles d'offre](fonctionnalites.md#2-compte-et-offres).

## 2. Rapport Gratuit

1. **Identification**

   - Nom de la piste, chien, lieu et date, selon les informations renseignées.
   - Organisateur et contexte de session lorsqu'ils sont fournis avec la piste.

2. **Carte récapitulative**

   - Affichage de la ou des traces présentes.
   - Superposition et couleurs distinctes lorsqu'il y a les deux traces.
   - Repères de départ et d'arrivée, zoom et déplacement de la carte.

3. **Trois indicateurs de base**

   - **Durée enregistrée** de chaque trace présente, hors périodes
     d'interruption de l'enregistrement.
   - **Distance parcourue estimée** de chaque trace présente, calculée à partir
     des positions GPS exploitables.
   - **Délai entre la pose de la piste et le départ du chien** : temps écoulé
     entre le passage du traceur au départ de référence et le départ du chien.
     Il est présenté seulement si ces horaires sont connus.

4. **Bilan simple**

   - Résultat de la recherche et commentaire général, renseignés manuellement.
   - La présence d'une arrivée GPS ne suffit pas à déclarer automatiquement que
     la bonne personne a été retrouvée et désignée.

## 3. Rapport Premium et Pro

Toutes les informations du rapport Gratuit, complétées par :

1. **Analyse interactive**

   - Affichage et masquage des différentes traces.
   - Relecture de la trace chien avec un curseur temporel, sur une référence
     traceur fixe lorsqu'elle existe.
   - Consultation des observations localisées sur la carte.

2. **Conditions de l'exercice**

   - Conditions météo au départ de la pose et au départ du chien, présentées
     séparément lorsqu'elles sont disponibles.
   - Température de l'air, en °C.
   - Humidité relative de l'air, en %.
   - Vitesse du vent, en km/h.
   - Direction d'origine du vent, en point cardinal et/ou degrés : par exemple
     « NO / 315° » pour un vent venant du nord-ouest.
   - Date, heure, localisation de référence et source des conditions présentées.

   Les données météo recueillies sont conservées avec la piste. Une consultation
   ultérieure ou un export PDF réutilise ces conditions associées à l'exercice.
   Une valeur absente est indiquée comme indisponible ; une direction de vent
   inconnue n'est pas remplacée par 0°, qui correspondrait au nord.

3. **Deux indicateurs supplémentaires, descriptifs**

   - **Comparaison des distances estimées traceur/chien**, avec la différence en
     mètres et en pourcentage. Exemple : 800 m traceur, 1 000 m chien, soit
     +200 m et +25 %. Cette comparaison exige deux traces complètes portant sur
     le même exercice et le même parcours de référence.
   - **Vitesse moyenne estimée de la trace chien** : distance estimée divisée
     par la durée enregistrée, pauses sur place incluses tant que
     l'enregistrement fonctionne. Ce n'est pas une vitesse en mouvement seul.

4. **Débrief et annotations**

   - Observations saisies manuellement et associées à des endroits de la piste.
   - Commentaires sur les difficultés, les aides apportées et la désignation.
   - Points positifs, points à retravailler et pistes pour l'entraînement suivant.

Une trace ou une donnée manquante n'est pas remplacée par une valeur nulle
interprétée comme un résultat. Une comparaison indisponible ou non pertinente
n'est pas calculée ; le rapport en indique la raison.

## 4. Synthèse de la première version

| Contenu | Gratuit | Premium |
| --- | --- | --- |
| Identification et carte de la piste | Oui | Oui |
| Superposition lorsqu'il y a deux traces | Oui | Oui |
| Départ, arrivée, zoom et déplacement | Oui | Oui |
| Durée enregistrée par trace | Oui | Oui |
| Distance GPS estimée par trace | Oui | Oui |
| Délai entre la pose et le départ du chien | Oui, si connu | Oui, si connu |
| Résultat et commentaire général | Oui, si renseignés | Oui, si renseignés |
| Affichage/masquage des traces et relecture | Non | Oui |
| Comparaison des distances en mètres et en % | Non | Oui, si les traces sont complètes et comparables |
| Vitesse moyenne estimée de la trace chien | Non | Oui, si calculable |
| Météo : température, humidité, vitesse et direction du vent | Non | Oui, à la pose et au départ du chien, si disponibles |
| Annotations localisées et débrief détaillé | Non | Oui, si renseignés |
| Export PDF | Rapport Gratuit | Rapport Premium |

Les règles de calcul et de qualité du chapitre 9 sont communes à toutes les
offres et aux PDF. Le quota d'enregistrement est défini séparément dans
[les règles techniques](technique.md#3-quota-chien-et-validité).

## 5. Quand peut-on consulter le rapport ?

Avec un compte connecté, la page devient disponible dans les cas suivants :

- **Après un enregistrement** : la piste est dans le carnet et sa page de rapport
  exploite la trace enregistrée.
- **Après ajout d'une seconde trace** : la même page propose les informations
  supplémentaires rendues possibles par cette seconde trace.
- **Après récupération d'une interruption** : « Terminer et sauvegarder » rend
  le rapport disponible si la trace est valide. « Abandonner et supprimer »
  retire la piste du carnet ; aucun rapport n'est conservé pour cette fiche.
- **Après réception** : l'import de la piste dans le carnet donne accès à sa page
  de rapport, même si elle ne contient qu'une trace.
- **À la réouverture** : les indicateurs sont calculés à partir des données de la
  piste, avec le niveau de restitution de l'offre actuelle du lecteur.
- **Après un changement d'offre** : les rapports des pistes déjà présentes
  s'adaptent également, sans nouvelle réception ni création d'une autre piste.

Un enregistrement de moins de cinq secondes effectives ou sans aucun point GPS
n'est pas conservé. Si une autre trace valide était déjà présente dans la piste,
son rapport reste disponible avec cette seule trace.

Chez l'organisateur, le live n'est pas une piste du carnet : il sert uniquement
à l'affichage et n'est jamais enregistré. Le rapport devient disponible après
téléchargement complet et validation de la copie finale envoyée par le
participant. La confirmation de prise en charge par le serveur peut intervenir
avant, sans rendre immédiatement la copie disponible dans son carnet. Une trace
invalide, ou une fin d'enregistrement sans participation et session actives,
ne laisse donc aucun rapport partiel chez l'organisateur. Une sortie suivie
d'une nouvelle entrée avant la fin applique les règles ordinaires de réception
de la copie finale complète.

Aucune action obligatoire de génération ou d'import d'un objet « rapport »
séparé ne conditionne la consultation d'une piste existante.

## 6. Partager une piste

Tout utilisateur peut partager sa piste au format de l'application, avec une
ou deux traces et les données complémentaires disponibles. Le destinataire
l'ajoute à son carnet comme une copie indépendante. Avec un compte, il consulte
le rapport selon ses droits ; sans compte, la piste est conservée sans rapport.
Le partage n'a aucune restriction d'offre.

Les règles d'import, d'indépendance des copies et de réutilisation d'une
référence sont définies dans [les fonctionnalités](fonctionnalites.md#4-partager-une-copie-de-piste).

Exemples :

| Situation | Chez le destinataire |
| --- | --- |
| Pro partage une piste à une personne sans compte | Copie conservée ; fiche textuelle avec chien, durée et distance. Le rapport et son PDF nécessitent une connexion et l'import accepté du carnet. |
| Premium partage une piste traceur à Gratuit | Piste ajoutée, rapport Gratuit portant sur la trace traceur. |
| Pro partage une piste traceur + chien à Gratuit | Deux traces conservées, rapport Gratuit, quota chien inchangé. |
| Premium partage une piste à Premium | Données conservées, rapport Premium. |
| Gratuit partage une piste à Premium | Copie indépendante, données conservées, rapport Premium chez le destinataire. |
| Une piste est reçue par un compte Pro | Données conservées, rapport Premium ; lien à une session seulement si utilisé par ses outils Pro. |
| Gratuit passe à Premium après avoir reçu une piste | La même piste affiche désormais le rapport Premium. |
| Premium repasse à Gratuit | Les mêmes pistes affichent le rapport Gratuit ; leurs données détaillées restent conservées. |

Recevoir une piste ne donne pas le droit de créer des sessions et ne modifie pas
l'offre du compte.

L'[export du carnet](fonctionnalites.md#export-du-carnet) sauvegarde les données
sans transférer de droits. Après restauration, les rapports suivent l'offre du
compte qui les consulte.

## 7. Rapport d'ensemble de session Pro

Une session est un regroupement de pistes du carnet. Sa page de synthèse peut
exploiter ces liens pour présenter les participants, les exercices et des
indicateurs d'ensemble, sans recopier les traces dans une autre base.

Ce rapport d'ensemble ne crée pas un troisième niveau de rapport individuel :
les rapports de piste restent Gratuit ou Premium. Le contenu précis et le partage
éventuel de cette synthèse de session restent à définir.

## 8. Export PDF du rapport

Le rapport individuel peut être exporté en PDF depuis sa page de consultation,
avec un compte connecté, quelle que soit son offre. Son contenu correspond aux
droits de la personne qui l'exporte au moment de la génération : Gratuit pour
un compte Gratuit, Premium pour un compte Premium ou Pro. Sans compte,
l'application ne propose pas de rapport à exporter.

Le PDF est conçu pour être lu, partagé et imprimé, avec une mise en page adaptée
au format A4. Il reprend les informations disponibles et autorisées :

- Identification de la piste, chien, lieu et date de l'exercice.
- Carte statique de la ou des traces, avec couleurs distinctes, légende,
  repères de départ et d'arrivée, échelle et attributions du fond de carte.
- Chiffres principaux, résultat et commentaire général.
- Pour le niveau Premium : comparaison des distances, vitesse moyenne estimée,
  météo de la pose et du départ du chien (température, humidité, vitesse et
  direction du vent), annotations localisées et débrief détaillé, selon les
  données disponibles.
- Date de génération et niveau de rapport exporté, distincts de la date de
  l'exercice.

Le PDF présente les cartes, chiffres et annotations de manière statique.
La disposition exacte et la pagination seront définies avec l'interface des
rapports.

### Un document figé au moment de l'export

Le PDF conserve le contenu généré, même après modification de la piste ou
changement d'offre. Il est lisible dans un lecteur PDF sans compte dans
l'application. Un PDF Premium partagé par un Pro est donc intégralement lisible
par un destinataire Gratuit ; ses droits ne filtrent pas le document déjà créé.

La règle d'adaptation à l'offre actuelle continue de s'appliquer au rapport
consulté dans l'application et aux nouveaux exports. Le partage au format de
l'application reste une copie de piste dont le rapport dépend des droits du
destinataire.

Le PDF est une restitution du rapport. Le partage de piste et l'export du carnet
conservent leur rôle pour transférer ou sauvegarder les traces et leurs données.

## 9. Fiabilité, interprétation et évolutions

### Calcul des indicateurs

Les définitions suivantes s'appliquent au rapport dans l'application et au PDF :

- **Durée enregistrée**, pour chaque trace : durée effective cumulée sur les
  périodes d'enregistrement, selon les
  [règles de durée](technique.md#durée-et-validation). Les pauses
  sur place restent incluses tant que le service enregistre ; les interruptions
  d'enregistrement sont exclues.
- **Distance GPS estimée**, pour chaque trace : distance calculée entre les
  positions exploitables à l'intérieur des segments continus. Les interruptions
  et lacunes identifiées ne doivent pas être raccordées artificiellement pour
  inventer une portion de parcours. Les critères de filtrage restent à valider
  sur le terrain ; les points sources restent immuables.
- **Délai entre la pose et le départ du chien** : différence entre le départ du
  chien et le passage du traceur au départ de référence, si ces événements sont
  connus. Utiliser les dates réelles d'origine, pas la date de réception, de
  copie ou de création de la fiche. Un début de fichier qui ne représente pas
  le départ réel ne suffit pas à calculer ce délai.
  Si les horaires placent le départ du chien avant la pose de sa référence,
  indiquer le délai comme indisponible plutôt que présenter un délai négatif.
- **Comparaison des distances**, en Premium : présenter les deux distances,
  leur différence signée et cette différence divisée par la distance traceur,
  en pourcentage. La référence doit avoir une distance exploitable strictement
  positive ; les deux traces doivent être complètes et comparables sur le même
  exercice. La qualification de ces conditions reste à définir lors du
  développement.
- **Vitesse moyenne estimée de la trace chien**, en Premium : distance estimée
  divisée par la durée enregistrée strictement positive, convertie en km/h.
  L'indicateur inclut les pauses sur place et dépend de la qualité du calcul de
  distance ; il n'est pas une moyenne des seuls instants de déplacement.

La validité d'un enregistrement ne garantit pas que tous les indicateurs soient
calculables. Un unique point peut suffire à conserver une trace valide, mais ne
permet pas d'estimer une distance parcourue. Une trace partielle est signalée ;
une comparaison non pertinente ou un indicateur inexploitable reste indisponible
avec une raison explicite, plutôt que de devenir zéro. Une vitesse calculée
avec une distance partielle n'est pas présentée comme une moyenne complète.

### Conservation des conditions météo

La collecte et la conservation des conditions disponibles suivent la même règle
pour toutes les offres ; leur restitution est réservée à Premium et Pro.
Chaque relevé reste lié au lieu et à la date réelle du départ concerné, avec sa
source. La météo actuelle ne remplace jamais celle de l'exercice.

Les conditions disponibles accompagnent les copies et sauvegardes. Réutiliser
une référence traceur conserve ses conditions d'origine ; la nouvelle trace
chien reçoit ses propres conditions. Leur stockage est décrit parmi
[les métadonnées à définir](database/app.md#7-données-prévues-dont-le-stockage-reste-à-préciser).
Le fournisseur et les modalités de récupération restent à choisir.

### Mesures et bilan humain

Les durées décrivent l'enregistrement effectif. Elles ne représentent le temps
complet de recherche que si les départs, fins et interruptions d'enregistrement
correspondent à ceux de l'exercice.

Les distances et vitesses sont des estimations GPS, présentées comme telles.
Une donnée absente ou de qualité insuffisante apparaît comme indisponible ; une
trace partielle est signalée. Si le téléphone est porté par l'humain, ces chiffres
décrivent son déplacement, pas les allées et venues exactes du chien.

La vitesse et la différence de distance ne constituent pas une note de qualité.
Le résultat de la recherche, la désignation et les observations sur le travail
du binôme relèvent du bilan humain.

À titre de repère, le règlement FCI/IRO 2025 autorise certains écarts au parcours
si le chien poursuit correctement sa recherche, y compris par une voie parallèle.
Il n'utilise pas la vitesse comme critère déterminant de réussite. Les chiffres
de l'application restent donc descriptifs et ne constituent pas une notation
officielle. Voir le
[règlement FCI/IRO 2025, chapitre 8, pages 69–70](https://www.centrale-canine.fr/sites/default/files/inline-files/Reglement%20SAR%2001-09-2025%20FR%20SCC%20V6.pdf#page=69).

### Analyses reportées après la première version

- Écarts moyens ou maximaux à la référence et temps passé dans un couloir de
  distance configurable.
- Courbes détaillées de vitesse et détection automatique des arrêts.
- Détection automatique des erreurs, virages manqués ou mauvaises branches pour
  l'analyse du rapport.
- Historique des alertes Track Assist, dont la conservation reste à décider.

Ces analyses demandent des règles précises et une validation sur le terrain.
L'historique des alertes dans le rapport est distinct de l'assistance utilisée
pendant l'enregistrement.
