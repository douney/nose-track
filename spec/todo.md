# Points restant à spécifier

Cette liste regroupe les décisions encore ouvertes. Les règles déjà validées
restent dans les documents de référence de l'[index](README.md).
Il s'agit de préciser le produit et ses modèles, pas de lister tout le code
restant à développer. Une décision résolue est intégrée dans sa spécification
puis retirée de cette liste.

Les choix qui changent le comportement utilisateur sont à arbitrer ensemble.
Les détails d'implémentation peuvent être fixés au développement selon le
principe KISS, sans ajouter de contrôle ou de parcours utilisateur. Les seuils
GPS et Track Assist demandent surtout une validation sur le terrain.

## 1. Comptes, connexion et droits

Référence : [comptes et authentification](database/server.md#2-connexion).

- [ ] Définir la récupération et la modification du mot de passe, y compris
  l'ajout d'un mot de passe à un compte créé avec Google ou Apple.
- [ ] Définir le parcours de suppression du compte et le devenir de ses données
  locales, serveur et de son abonnement.
- [ ] Finaliser les parcours de liaison/déliaison et de vérification initiale
  de l'e-mail, notamment les adresses déjà utilisées mais non vérifiées.
- [ ] Fixer la normalisation des e-mails et sa contrainte SQL d'unicité.
- [ ] Définir la durée des connexions, la rotation des jetons, la durée des
  jetons d'action et les effets des changements de connexion sur les sessions
  déjà ouvertes.
- [ ] Préciser l'accès local au carnet et aux rapports si la connexion au compte
  a expiré ou a été révoquée. La conservation du GPS et du contexte propriétaire
  est fixée ; la nécessité de se reconnecter pour consulter ces données reste
  à trancher, distinctement d'une simple coupure Internet.
- [ ] Choisir l'interface de gestion des connexions : déconnexion locale,
  déconnexion des autres appareils ou liste avec révocation individuelle.
- [ ] Décrire la validation serveur des maintiens temporaires d'outils Premium
  ou Pro déjà définis, sans modifier les périodes réellement facturées.

## 2. Abonnements et quota

Références : [abonnements](database/server.md#3-abonnements-annuels) et
[quota chien](technique.md#3-quota-chien-et-validité).

- [ ] Choisir le prestataire de paiement web et les références des produits
  annuels Premium/Pro sur les trois canaux.
- [ ] Finaliser la correspondance des états et références Apple, Google et web,
  y compris grâce, expiration, remboursement et changement de produit.
- [ ] Définir les changements Premium/Pro, la restauration des achats et la
  prévention des doubles abonnements entre canaux.
- [ ] Préciser le calcul de l'offre effective et l'abonnement présenté dans
  l'app lorsque plusieurs achats existent.
- [ ] Définir le stockage minimal du quota par compte et mois, sa synchronisation
  et son cache local. Le dépassement occasionnel est accepté ; aucune réservation
  distribuée ni garantie stricte entre appareils n'est à concevoir. Préciser le
  démarrage chien si aucun compteur du mois n'est disponible et que le serveur
  est injoignable, notamment après un changement de mois hors réseau.

## 3. Enregistrement et données locales

Références : [validité des traces](technique.md#durée-et-validation) et
[base de l'app](database/app.md).

- [ ] Choisir l'isolation physique ou logique des carnets et les migrations
  depuis `tracks` v1. Une simple déconnexion conserve le carnet isolé sur le
  téléphone ; une reconnexion au même compte le retrouve.
- [ ] Définir le stockage de la durée effective par rôle et du contexte de droits
  nécessaire à la reprise d'un exercice.
- [ ] Définir avec l'interface le parcours « Enregistrer le chien » depuis une
  piste traceur seule : compléter cette fiche ou créer une copie de sa référence.
  Les deux mécanismes de données existent ; leur choix dans l'interface n'est
  pas encore fixé. Une trace finalisée n'est jamais remplacée.
- [ ] Préciser le lien éventuel entre la piste et le profil chien, le renommage
  d'un chien et le nom conservé sur les anciennes pistes.
- [ ] Définir les métadonnées de lieu, résultat, bilan, annotations, météo et
  contexte de session partagé, y compris le pseudo d'un participant invité.
- [ ] Définir le nettoyage des liens et métadonnées lors de la suppression d'une
  piste ou de la purge d'un carnet au changement de compte : devenir de
  `session_tracks`, annotations et météo, sans supprimer les autres pistes.
- [ ] Fixer les valeurs initiales et la portée des préférences encore proposées.

## 4. Sessions, invités et transferts

Référence : [sessions et transferts](technique.md#6-sessions--participation-et-visibilité).

- [ ] Définir le schéma serveur des sessions et participations, leurs identifiants
  et leur correspondance avec les tables locales Pro.
- [ ] Décrire l'identité et l'autorisation d'un invité et sa récupération après
  redémarrage. Une transition d'identité suit le départ en ligne ou local déjà
  défini ; aucune participation n'est transférée ou fusionnée entre comptes.
- [ ] Définir l'identification des enregistrements live provenant de plusieurs
  téléphones d'un même compte, sans exclusion automatique d'appareil. L'unique
  session active reste commune au compte.
- [ ] Préciser les états de présence et la reconnexion après coupure, en conservant
  la session et la participation jusqu'à sortie, fermeture ou expiration.
- [ ] Définir les codes, le rayon de recherche par proximité et la présentation
  des sessions disponibles.
- [ ] Définir le protocole d'envoi final : reprise, intégrité, identité stable
  de transfert, acceptation serveur et absence de doublon lors des retries.
  Distinguer un retry de l'envoi d'une seconde trace ajoutée à la même piste,
  en conservant la règle des copies indépendantes.
- [ ] Décrire le stockage de transit des pistes finalisées, la livraison à
  l'organisateur hors ligne et la durée de conservation après livraison.
  Préciser sur quels téléphones de l'organisateur la copie est proposée et si
  sa réception sur l'un empêche ou non sa récupération sur les autres.
  Les carnets restent locaux et les points du live éphémères.
- [ ] Préciser les états d'envoi affichés. La confirmation du serveur et la
  réception effective dans le carnet de l'organisateur sont deux étapes distinctes.
- [ ] Décrire le traitement d'une fin d'enregistrement hors réseau ou avec une
  connexion au compte suspendue vis-à-vis de l'expiration serveur, et la livraison
  sur les appareils de l'organisateur. Préciser l'autorisation d'un premier
  envoi demandé après fermeture, lorsque la fin locale précède cette fermeture.
  Le départ volontaire local sans réseau est déjà défini et ne crée aucune
  commande de sortie différée.

## 5. Rapports, partage et outils de carte

Références : [rapports](rapports.md) et [fonctionnalités](fonctionnalites.md).

- [ ] Définir le filtrage et la qualité GPS, ainsi que les critères permettant
  de qualifier deux traces de complètes et comparables.
- [ ] Définir la présentation de la relecture, des annotations et la mise en
  page/pagination du PDF A4. Le contenu initial Gratuit/Premium est déjà fixé.
- [ ] Choisir le fournisseur météo et préciser la récupération des conditions
  aux dates et lieux réels de la pose et du départ du chien.
- [ ] Définir le contenu de la synthèse de session Pro et son partage éventuel.
- [ ] Choisir le format, la version et l'extension des fichiers de piste partagés.
- [ ] Définir l'export/restauration du carnet et l'inclusion éventuelle des
  sessions Pro et de leurs associations.
- [ ] Valider sur le terrain les seuils Track Assist, l'adaptation du retour à
  la distance d'alerte et les critères de qualité/fraîcheur des positions.
- [ ] Définir le centre, le rayon et le rendu de pollution, sa période lors de
  la consultation d'une ancienne session et le traitement des copies dans un
  rendu de densité. La fenêtre initiale des six dernières heures reste fixée.

## 6. Choix techniques et évolutions futures

- [ ] Choisir le moteur SQL serveur et l'outil d'authentification ; adapter les
  types physiques et les migrations aux modèles logiques décrits.
- [ ] Définir les éventuels rappels périodiques Track Assist et leurs réglages.
- [ ] Définir les aides de figures, leurs niveaux et les repères préparés par le
  traceur ou l'organisateur, après validation de l'assistance initiale.
- [ ] Définir les analyses avancées des rapports : écarts, couloirs, courbes de
  vitesse, arrêts/difficultés et conservation éventuelle des alertes Track Assist.
- [ ] Définir les futurs modèles de sauvegarde/synchronisation cloud des pistes
  et des profils chiens. Le stockage de transit des envois de session est distinct.
