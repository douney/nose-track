# NoseTrack

Application de mantrailing pour téléphones Android et iPhone. Le squelette contient
un écran d’accueil et le thème partagé d’`app-core`, sans fonctionnalité métier.

## Installation

Flutter stable 3.47.6 / Dart 3.13.5, Xcode pour iOS et l’aperçu Mac, SDK Android et
JDK compatibles pour Android.

```sh
git clone --recurse-submodules git@github.com:douney/nose-track.git
cd nose-track
# Dans une copie existante :
git submodule update --init --recursive
flutter pub get
```

Le dépôt commun s’appelle `app-core` et se trouve dans `submodules/app-core`.
Seul `app_ui` est utilisé pour le moment ; aucun plugin natif n’est ajouté.

## Développement

```sh
# Aperçu téléphone sur Mac, sans émulateur ni option supplémentaire :
flutter run -d macos

# Téléphone Android ou iPhone connecté :
flutter devices
flutter run -d <device-id>
```

Dans VS Code, installer l’extension Flutter recommandée, puis ouvrir
**Exécuter et déboguer** et lancer avec **F5** :

- **Mac — Aperçu téléphone** lance directement l’aperçu sur macOS.
- **Téléphone — Android / iOS** utilise l’appareil choisi dans la barre d’état
  Flutter de VS Code ; sélectionner le téléphone connecté avant de lancer.

macOS sert uniquement de lanceur de développement, pas de cible de distribution.
Il affiche la vraie application dans un écran de téléphone avec les dix formats
iPhone/Android de MinifyGo, leurs marges de sécurité et un mode taille libre.
Le format choisi garde sa résolution logique et se réduit pour tenir dans la
fenêtre. Changer de format conserve l’état de l’application et ses routes.

Le thème suit le profil iOS/Android, tandis que les plugins restent exécutés sur
macOS. Le GPS, les permissions, le clavier et les services natifs devront être
validés sur téléphone lorsqu’ils seront ajoutés.

## Vérification et builds mobiles

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
flutter build macos --debug
```

iOS cible uniquement l’iPhone. Les identifiants Android/iOS générés sont
respectivement `com.nosetrack.nose_track` et `com.nosetrack.noseTrack`.
La signature de distribution sera configurée avant une première publication.
