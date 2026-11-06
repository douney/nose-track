# Localisation et stockage des parcours

Le module appartient à NoseTrack. Il ne dépend d'aucun nouveau package et ne
modifie pas `app-core`. Les permissions restent centralisées dans `app_permissions`.

## Organisation

```text
lib/domain/location/           Fix GPS, sans dépendance Flutter ou SQL
lib/domain/tracks/             Rôles, cible d'enregistrement et points
lib/modules/geolocation/      API du service et états de localisation
lib/data/tracks/               Catalogue, modèles SQL et TrackRepository
lib/platform/                 Transport MethodChannel / EventChannel commun
assets/sql/tracks_v1.sql       Schéma SQLite unique pour Android et Apple
android/.../tracking/
  domain/                     Contrat d’enregistreur et erreurs partagées
  geolocation/                LocationManager, capteurs et foreground service
  storage/                    SQLite et journal JSONL
  TrackingRuntime.kt          Coordination et file de travail native
native/apple/
  Domain/                     Contrat d’enregistreur et erreurs partagées
  Geolocation/                Core Location / Core Motion ; aperçu Mac sans GPS
  Storage/                    SQLite et JSONL, communs iOS/macOS
  TrackingBridge.swift        Coordination et pont Flutter
```

L'interface actuelle reste une carte : ce changement fournit les API natives,
sans ajouter de boutons d'enregistrement ni demander de permission au lancement.
Les constructeurs par défaut du service et du repository partagent le même
transport et le même runtime natif. `initialize()` est aussi appelé à la première
opération du repository. Initialiser ne démarre aucune acquisition.

## Utilisation

```dart
final location = GeolocationService();
final tracks = TrackRepository();
await location.initialize();

// Vérifier/demander les permissions avec AppPermissions depuis l'interface.
final track = await tracks.createTrack(name: 'Bois communal', dogName: 'Nala');
await location.setMode(
  GeolocationMode.tracking,
  target: RecordingTarget(trackId: track.id, role: TrackRole.tracer),
);

// Depuis le bouton d'arrêt, application active :
await location.setMode(GeolocationMode.foreground);

// Ultérieurement, enregistrer le chien sur ce même parcours :
await location.setMode(
  GeolocationMode.tracking,
  target: RecordingTarget(trackId: track.id, role: TrackRole.dog),
);
```

`off` arrête l'acquisition. `foreground` acquiert uniquement pendant que l'app
est active. `tracking` enregistre aussi lorsque l'app est en arrière-plan ou
l'écran éteint. Le mode demandé ne change pas automatiquement avec la navigation
ou le cycle de vie de Flutter. Un contrôleur d'application doit conserver
`tracking` lorsqu'on quitte la carte.

L'entrée et la sortie de `tracking` exigent une app active. La couche native
vérifie cette condition ; l'interface réserve ces commandes à ses boutons.
Le même mode avec la même cible est idempotent. Un seul enregistrement est actif
par appareil. Changer de cible exige de terminer la session courante.

Sur Android, le service de type `location` est démarré dès l'entrée dans
`tracking`, avec sa notification ouvrant l'app. Il ne propose pas d'action
d'arrêt. Il est arrêté à la sortie de `tracking`. Aucune permission de
localisation permanente, exemption batterie ou relance au démarrage du téléphone
n'est demandée. La notification FGS reste requise même si l'utilisateur a refusé
la permission d'afficher les notifications dans le tiroir Android.

Sur iOS, les mises à jour standard Core Location utilisent le mode background
`location`, sans pause automatique. Le cap vient de Core Motion avec référence
nord vrai lorsqu'elle est disponible, avec Core Location pour la précision et
le repli. Android utilise le rotation vector natif et la déclinaison magnétique.
Les orientations tiennent compte de la rotation de l'écran. Un cap invalide est
émis à `null` ; `0` est le nord. Les capteurs d'orientation sont suspendus lorsque
l'app n'est plus active.

## Propriétés du service

- `state` : `Stream<GeolocationState>`, état courant puis changements ; mode,
  acquisition (`stopped`, `waitingForFix`, `receiving`, `unavailable`), session,
  éventuel problème (`code`, `message`).
- `positions` : `Stream<LocationFix>`, nouveaux fixes uniquement.
- `lastPosition` : `LocationFix?`, instantané daté, sans acquisition implicite.
- `headings` : `Stream<HeadingSample>`, orientation et précision angulaire.

Écouter ou annuler un flux ne démarre et n'arrête aucun service. Le transport
Flutter se resynchronise au retour au premier plan. Les événements ne remplacent
pas le journal pour reconstituer les points manqués.

Les fixes sont limités à un point retenu par seconde sur leur date de mesure.
Aucun point artificiel n'est créé lorsque le système ne fournit pas de fix.
Le premier fix doit dater du démarrage de l'acquisition ou après celui-ci.
Les coordonnées sont WGS84 en degrés, la précision horizontale en mètres,
l'altitude facultative au-dessus de l'ellipsoïde WGS84, la vitesse en m/s et le
course GPS en degrés. Le course n'est pas la boussole du téléphone.

## TrackRepository

| Méthode | Contrat |
| --- | --- |
| `createTrack(name, description?, dogName?)` | Crée un parcours, sans fichier GPS. |
| `listTracks(filter?)` | Métadonnées par date de création décroissante. |
| `getTrack(trackId)` | Métadonnées, ou `null` si absent. |
| `updateTrack(trackId, changes)` | Édite `name`, `description`, `dogName`. |
| `readTrack(trackId, role, afterSequence: 0, follow: false)` | Flux de points du rôle choisi. |
| `importTrace(trackId, role, source)` | Importe un JSONL NoseTrack v1 finalisé depuis un chemin accessible. |
| `deleteTrack(trackId)` | Supprime la ligne et les deux fichiers éventuels. |

Les modèles retournés par le catalogue exposent `tracer` et `dog`, chacun nul si
absent. Chaque trace contient sa référence de fichier, ses dates, son statut
(`recording`, `interrupted`, `finished`), son compteur et son premier point.

```dart
final changes = TrackChanges()
  ..dogName = 'Nala'
  ..description = null; // Effacement explicite ; name reste inchangé.
await tracks.updateTrack(track.id, changes);

final subscription = tracks.readTrack(
  track.id, TrackRole.dog, afterSequence: 125, follow: true,
).listen((point) { /* mise à jour de la ligne sur la carte */ });
```

La séquence commence à 1 et est indépendante pour chaque rôle. `afterSequence`
est exclusif. `follow: false` termine après les points disponibles ; `true` lit
l'historique puis suit les ajouts jusqu'à l'arrêt de l'enregistrement. Le lecteur
s'abonne avant sa première lecture, conserve son offset, respecte pause et
annulation, et ne lit que des lignes complètes. Les lectures sont limitées à des
blocs de 256 enregistrements.

Le filtre propose `search` (nom, description, nom du chien), `createdFrom`
inclusif, `createdBefore` exclusif, `hasTracer` et `hasDog`. La recherche SQL
standard ne garantit pas un repli Unicode complet de la casse.

L'import valide la copie temporaire avant de l'installer, conserve l'original et
réécrit uniquement l'identité du header pour rattacher la copie au parcours et au
rôle. Les points sont conservés. Un rôle déjà présent ne peut pas être remplacé.
Les métadonnées techniques sont calculées par le module, jamais éditées via
`updateTrack`. Supprimer le parcours en cours d'enregistrement est refusé.

Les erreurs natives sont des `PlatformException` avec un code stable, notamment
`invalidArgument`, `trackNotFound`, `traceNotFound`, `traceAlreadyExists`,
`invalidTrace`, `recordingInProgress`, `foregroundRequired`, `permissionDenied`,
`locationServicesDisabled`, `serviceStartFailed`, `unsupportedPlatform` ou
`storageError`. Les arguments de mode incompatibles sont rejetés en Dart par
`ArgumentError`.

## Fichiers et SQL

Android utilise `filesDir/NoseTrack`, iOS et l'aperçu Mac utilisent
`Application Support/NoseTrack`, dans leur conteneur d'application :

```text
NoseTrack/
  tracks.sqlite
  tracks.sqlite-wal           # géré par SQLite
  tracks.sqlite-shm           # géré par SQLite
  tracks/<UUID>/tracer.jsonl
  tracks/<UUID>/dog.jsonl
```

Les références SQL sont relatives à cette racine. Le schéma complet est dans
[`tracks_v1.sql`](../assets/sql/tracks_v1.sql), chargé par les deux plateformes.
Il contient une ligne par parcours, `dog_name` inclus, et les mêmes sept colonnes
pour chacun des deux rôles. Dates : entiers UTC en millisecondes ; coordonnées :
`REAL` ; nom obligatoire ; autres textes utilisateur facultatifs.

`deleted_at` masque une suppression en cours. Le module marque la ligne, supprime
le dossier puis supprime la ligne. Le nettoyage est repris après une interruption.
Le catalogue est en WAL ; il ne contient aucun point GPS et n'est pas un protocole
de synchronisation cloud.

## Format et récupération

JSONL UTF-8, une ligne terminée par `\n` par enregistrement :

```json
{"type":"header","version":1,"trackId":"UUID","role":"tracer","startedAt":1000}
{"type":"point","sequence":1,"segmentId":1,"timestamp":2000,"latitude":48.1,"longitude":2.3,"accuracyMeters":3.0,"altitudeMeters":null,"speedMetersPerSecond":1.2,"courseDegrees":null}
{"type":"end","endedAt":3000}
```

Le natif est l'unique écrivain. Chaque ligne retenue est écrite et synchronisée
sur le fichier avant sa publication à Flutter. Le compteur SQL et le premier
point sont des caches reconstruisibles depuis le journal. Une trace finalisée
reste immuable. Une coupure de mesures de plus de dix secondes ouvre un nouveau
segment, afin de pouvoir conserver les discontinuités.

Après destruction du processus, aucune acquisition ni aucun foreground service
n'est automatiquement relancé. Les sessions SQL restées en `recording` sont
réconciliées avec le fichier : footer présent = `finished`, sinon `interrupted`.
La fin de ligne incomplète est tronquée. Un header initial incomplet sans point
est nettoyé. Un fichier installé juste avant une interruption de la mise à jour
SQL est rattaché au rôle correspondant.

Une action explicite `setMode(tracking, target: ...)` peut reprendre une trace
`interrupted`, en conservant ses points et sa séquence, dans un nouveau segment.
Une trace `finished` ne peut jamais être reprise ou remplacée.

## Vérification

```sh
flutter analyze
flutter test
swiftc -module-cache-path /tmp/nosetrack-swift-cache native/apple/Domain/*.swift native/apple/Storage/*.swift tool/tracking_storage_check.swift -o /tmp/nose-track-storage-check
/tmp/nose-track-storage-check assets/sql/tracks_v1.sql
flutter drive -d macos --driver test_driver/integration_test.dart --target integration_test/tracking_storage_test.dart
flutter build apk --debug
flutter build ios --debug --no-codesign
```

L'aperçu Mac exerce le vrai catalogue et les imports, sans simuler un GPS de
téléphone. La tenue en arrière-plan, écran verrouillé pendant plus de dix minutes,
et le cap nécessitent une validation sur Android et iPhone réels. Aucun serveur,
protocole de partage live ou upload n'est configuré dans cette version.
