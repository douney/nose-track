# Maquette de l’accueil

[Ouvrir la maquette](index.html) dans un navigateur. Elle fonctionne directement
depuis le fichier, sans installation, dépendance ou connexion réseau.

L’accueil est une carte plein écran. Le vert reprend l’accent actuel de
l’application Flutter. Les commandes principales sont le centrage sur soi,
le retour au cap nord, le choix des fonds et le démarrage d’un enregistrement.
Le carnet et la participation à une session sont accessibles en bas de l’écran.

## Interactions

- Déplacer la carte par glissement et zoomer avec la molette ou un pincement.
- Pivoter avec Maj + glisser sur ordinateur, ou avec deux doigts sur mobile.
  Les noms des lieux restent horizontaux.
- Choisir un fond Classique, Satellite ou Relief 2D. Les trois fonds sont
  **illustrés**, y compris le satellite ; aucune imagerie réelle n’est chargée.
- Afficher ou cacher le cercle de précision. En mode chien, afficher ou cacher
  la référence traceur fictive.
- Lancer un enregistrement traceur ou chien depuis le bouton principal.
  En chien, la référence est préchargée pour montrer la superposition.
- Terminer l’enregistrement par le bouton dédié. La liste fictive du carnet est
  complétée à partir de cinq secondes ; une trace plus courte est écartée.
- Rejoindre explicitement une session à proximité ou par un code alphanumérique
  de quatre à huit caractères. Tout code valide ouvre la même session fictive.
  Le live est affiché uniquement si une session et un enregistrement sont actifs.
- Quitter la session coupe le live fictif et conserve l’enregistrement en cours.
  Terminer une trace valide simule à la fois la prise en charge par le serveur
  et la réception par l'organisateur, sans attente réseau réelle.
- Sur ordinateur, utiliser les commandes extérieures au téléphone pour changer
  son format ou afficher directement un état de démonstration. Ces commandes
  ne font pas partie de l’interface de l’application.

La carte se déplace aussi au clavier : flèches, `+` / `-`, `N` pour le nord et
`Home` pour recentrer. Les panneaux se ferment avec Échap ou leur bouton Fermer.

## Portée

Cette maquette propose une disposition d’écran ; les règles produit restent
décrites dans [les fonctionnalités](../fonctionnalites.md). Le profil Premium,
le chien Nala, les pistes et la session sont fictifs. Les valeurs GPS, le tracé,
les durées et les confirmations servent uniquement à explorer l’interface.
La longueur du code et les sessions proposées sont des choix de démonstration,
sans fixer le futur protocole d'entrée par code ou proximité. Le seuil de cinq
secondes repose ici sur le compteur simulé ; la validation produit exige aussi
un point GPS et une durée d'enregistrement effectif.

Le compteur repose sur l’heure du navigateur et le parcours simulé atteint sa
limite après dix minutes. Aucun service GPS, enregistrement natif, transfert,
compte ou stockage persistant n’est utilisé. Recharger la page réinitialise
l’état. L’affichage « écran éteint » présente le comportement prévu du produit,
pas une garantie de fonctionnement de cette page en arrière-plan.

Le prototype reste distinct de l’application Flutter. Les autres écrans, les
rapports, la création de session Pro et Track Assist ne sont pas maquettés ici.
