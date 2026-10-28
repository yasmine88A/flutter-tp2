# TP Flutter — itinéraire OSRM et GPS

L'application conserve ses pages Home, Login, Cards et Profile et sa navigation
du bas. Ouvrir **Cards** pour utiliser la carte. Le centre initial est Casablanca.

## Démarrer

Le projet utilise Dart `^3.13.5` et a été vérifié avec Flutter 3.47.6.

```sh
flutter pub get
flutter run
```

Pour Android, connecter un téléphone avec le débogage USB activé, puis choisir
son identifiant dans `flutter devices` et lancer `flutter run -d <identifiant>`.
Le SDK Android et un JDK compatible avec la configuration Gradle du projet sont
nécessaires. `compileSdk` suit celui du SDK Flutter (36 dans l'environnement de
développement), compatible avec la dépendance `geolocator` installée.

Les permissions Internet, localisation approximative et précise sont déclarées
dans `android/app/src/main/AndroidManifest.xml`, y compris pour les builds release.
L'autorisation GPS est demandée uniquement après une action sur un bouton GPS.
Aucune permission de localisation en arrière-plan n'est demandée et aucun
service de localisation en arrière-plan n'est lancé. Le dépôt ne contient pas
de plateforme iOS ; aucun fichier iOS fictif n'a été ajouté.

Pour le Web :

```sh
flutter run -d chrome --web-hostname localhost
```

La localisation fonctionne sur **localhost ou HTTPS**, avec l'autorisation du
navigateur et la localisation du système activées. Une adresse de réseau local
en HTTP, par exemple `http://192.168.x.x`, ne suffit généralement pas.
Si l'accès est bloqué, modifier l'autorisation de localisation du site dans le
navigateur, puis réessayer. La localisation Web peut provenir du Wi-Fi ou du
réseau de l'ordinateur et sa précision peut être inférieure à celle d'un téléphone.

## Utilisation et démonstration à l'enseignante

1. Ouvrir Cards. Montrer la carte de Casablanca, le zoom, le bouton de recentrage
   et l'attribution OpenStreetMap visible et cliquable en bas de la carte.
2. Toucher une rue pour choisir le départ (marqueur vert). La sélection passe
   automatiquement à l'arrivée ; toucher une autre rue (marqueur rouge).
   Les deux coordonnées sont affichées sous la carte.
3. Appuyer sur **Calculer l'itinéraire**. Montrer le chargement, puis le tracé bleu
   qui suit les rues, le cadrage complet, la distance et la durée estimée.
4. Appuyer sur **Choisir le départ** ou **Choisir l'arrivée**, puis toucher une
   autre position. L'ancien tracé et ses mesures disparaissent immédiatement.
   Relancer le calcul pour obtenir le nouveau parcours.
5. Appuyer sur **Ma position**, autoriser la localisation et montrer le point bleu.
   **Utiliser ma position comme départ** prend la dernière position GPS affichée
   (ou en récupère une si aucune n'est connue). Appuyer sur Ma position pour
   rafraîchir une ancienne position avant de l'utiliser.
6. Appuyer sur **Suivi GPS** et se déplacer avec un vrai téléphone. Le point bleu
   se met à jour sans toucher un bouton. Déplacer la carte manuellement : les
   nouvelles positions ne forcent pas le recentrage. Le départ reste celui choisi,
   et aucune requête OSRM n'est envoyée à chaque mise à jour.
7. Appuyer sur **Arrêter le suivi GPS**. Le dernier point bleu reste affiché.
   Le suivi s'arrête aussi en quittant Cards ou en mettant l'application en
   arrière-plan ; il faut le relancer explicitement au retour.
8. Appuyer sur **Réinitialiser** : départ, arrivée, tracé et mesures sont effacés,
   et la carte revient à Casablanca. La localisation est indépendante : son
   dernier point reste visible et le bouton de suivi permet de l'arrêter.
9. Montrer les cas d'erreur : calcul sans départ, calcul avec seulement un départ,
   Internet coupé, localisation désactivée ou permission refusée. Un message en
   français apparaît ; les boutons permettent de réessayer. Le refus définitif
   propose l'ouverture des réglages sur Android.
10. Revenir aux autres onglets pour montrer que la navigation et les autres pages
    fonctionnent toujours. Sur un petit écran, faire défiler le panneau sous la carte.

Pour montrer l'appel REST, les outils réseau du navigateur affichent une requête
GET vers `router.project-osrm.org/route/v1/driving/…`, avec
`overview=full&geometries=geojson`. Aucune clé API n'est nécessaire.

## Comment le code fonctionne

Fichiers ajoutés :

```text
lib/models/route_result.dart
lib/services/osrm_service.dart
lib/services/location_service.dart
test/osrm_service_test.dart
test/location_service_test.dart
test/cards_view_test.dart
test/osrm_live_test.dart
test/support/fakes.dart
```

Fichiers modifiés :

```text
lib/screens/Cards.view.dart
lib/home.page.dart
pubspec.yaml
pubspec.lock
android/app/src/main/AndroidManifest.xml
README.md
```

- `lib/screens/Cards.view.dart` gère la sélection et les états de chargement,
  résultat et erreur. Deux marqueurs représentent les points choisis, un troisième
  représente la position de l'appareil. Le panneau est défilant et passe à droite
  de la carte sur grand écran. Les identifiants des opérations permettent d'ignorer
  les réponses reçues après un changement de points, une remise à zéro ou la
  destruction de l'écran.
- `lib/services/osrm_service.dart` construit l'URL en **longitude,latitude** et
  envoie un vrai GET HTTPS via `http.Client`. Il vérifie le statut HTTP et le code
  OSRM, puis utilise `jsonDecode(utf8.decode(response.bodyBytes))`. Il contrôle la
  présence d'une route et gère `NoRoute`, `NoSegment`, les erreurs réseau, les
  réponses invalides et un délai maximal de 15 secondes. Aucun résultat statique
  n'est utilisé dans l'application.
- `lib/models/route_result.dart` décode `routes[0]`, valide les mesures et la
  géométrie `LineString`, puis convertit chaque paire GeoJSON `[longitude, latitude]`
  en `LatLng(latitude, longitude)`. Les kilomètres sont `distance / 1000` et les
  minutes sont `duration / 60`. L'affichage arrondit la durée à la minute supérieure
  et utilise les heures/minutes si nécessaire. Ces mesures viennent du moteur
  routier OSRM ; elles ne sont pas calculées à partir d'une ligne droite.
- `PolylineLayer` dessine tous les points de la géométrie OSRM avec une ligne bleue
  bordée de blanc. `MapController.fitCamera(CameraFit.coordinates(...))` cadre
  le parcours et les deux marqueurs avec une marge.
- `lib/services/location_service.dart` vérifie le service de localisation et les
  permissions via le fournisseur `GeolocatorPlatform` utilisé par `Geolocator`.
  La position ponctuelle a un délai maximal de 25 secondes. Le suivi utilise
  `getPositionStream()` avec une précision élevée et un filtre de déplacement de
  5 mètres ; la fréquence réelle dépend de l'appareil et de la plateforme.
  Chaque événement met à jour le point bleu. L'écran annule la souscription à
  l'arrêt, à la sortie de l'onglet, au passage en arrière-plan et dans `dispose()`.
- `lib/home.page.dart` transmet uniquement l'activité de l'onglet Cards, car
  l'`IndexedStack` conserve les pages en mémoire. Cela permet d'arrêter le GPS
  lorsqu'on change d'onglet tout en conservant les autres pages.

La durée est une **estimation en voiture hors trafic en temps réel**. Le service
OSRM peut rattacher les points sélectionnés à des routes proches. Un trajet peut
être impossible entre deux zones non reliées par le réseau routier.

## Tests

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

Les tests utilisent des réponses JSON uniquement dans `test/` et un faux fournisseur
GPS uniquement pour les vérifications automatisées. Ils couvrent le format du GET,
la conversion longitude/latitude, les mesures et leur affichage, les erreurs et le
délai OSRM, la sélection/modification, le cadrage, la réinitialisation, les réponses
tardives, les permissions, les positions et l'annulation du suivi. Les tests de
carte injectent des images locales pour éviter tout téléchargement de tuiles.

Un test réseau optionnel réalise **une seule requête réelle** à Casablanca :

```sh
flutter test --dart-define=OSRM_LIVE=true test/osrm_live_test.dart
```

Il est ignoré par défaut pour que la suite habituelle ne dépende pas d'Internet
ni du serveur public. La précision GPS réelle et les dialogues du système doivent
être vérifiés sur un vrai appareil ; les tests automatisés ne les remplacent pas.

Vérifications réalisées le 28 octobre 2026 : `flutter pub get` et la compilation
Web réussissent ; les 41 tests habituels passent. Le test réseau optionnel réussit
aussi (61 points OSRM, 1,84 km, durée affichée 4 min pour les coordonnées du test).
Un calcul depuis l'interface Web a également été vérifié : sélection des deux
points sur la carte, requête au serveur public, tracé routier bleu et cadrage
automatique, avec 5,53 km et 8 min pour les points choisis lors de cette vérification.
L'analyse complète retrouve uniquement deux signalements préexistants : le
constructeur non `const` de `HomePage` et les contrôleurs non `final` de
`Loginview`. Aucun problème n'est signalé dans le nouveau code ou les tests.
Ces pages n'ont pas été remaniées pour faire disparaître ces anciens signalements.

`flutter doctor -v` signale des Android SDK Command-line Tools manquants et un état
des licences Android non vérifiable. Si nécessaire, installer ces outils depuis
le SDK Manager d'Android Studio, puis examiner et accepter les licences avec
`flutter doctor --android-licenses`. Aucun téléphone Android n'était connecté
pendant les vérifications ; le suivi en déplacement reste à démontrer sur appareil.

## Services publics et références

Le serveur OSRM de démonstration est destiné à ce TP : calcul uniquement sur
demande, sans recalcul à chaque position GPS et sans tentatives automatiques en
boucle. La disponibilité de ce service public n'est pas garantie.

Les tuiles utilisent `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, avec
`userAgentPackageName: 'com.example.tp33'`, identique à l'identifiant Android.
L'attribution reste visible et ouvre la page des droits OSM. Le cache normal de
`flutter_map` est conservé ; aucun téléchargement massif, mode hors ligne ou
contournement du cache n'est ajouté. Sur le Web, le navigateur gère l'identification
HTTP et le référent ; ne pas configurer d'hébergement supprimant ce référent.

- [API OSRM officielle](https://project-osrm.org/docs/v26.5.0/http)
- [Documentation geolocator](https://pub.dev/packages/geolocator)
- [Positionnement flutter_map](https://docs.fleaflet.dev/usage/options)
- [Politique des tuiles OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/)
