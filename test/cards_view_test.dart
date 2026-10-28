import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tp33/screens/Cards.view.dart';
import 'package:tp33/services/location_service.dart';
import 'package:tp33/services/osrm_service.dart';

import 'support/fakes.dart';

void main() {
  late FakeGeolocator platform;
  late MockClient client;
  late OsrmService osrm;
  late LocationService location;
  late OfflineTileProvider tiles;
  int requests = 0;

  setUp(() {
    platform = FakeGeolocator();
    location = LocationService(platform: platform);
    tiles = OfflineTileProvider();
    requests = 0;
    client = MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(validOsrmResponse()), 200);
    });
    osrm = OsrmService(client: client);
  });
  tearDown(() async {
    await platform.positions.close();
    client.close();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool active = true,
    Size? size,
  }) async {
    tester.view.physicalSize = size ?? const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardsView(
            osrmService: osrm,
            locationService: location,
            tileProvider: tiles,
            isActive: active,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(
    WidgetTester tester,
    String label, {
    bool settle = true,
  }) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> selectPoints(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(center - const Offset(25, 10));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tapAt(center + const Offset(25, 10));
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'Sélection, tracé OSRM, mesures, modification et réinitialisation',
    (tester) async {
      await mount(tester);
      expect(platform.permissionRequests, 0);
      expect(find.text('© Contributeurs OpenStreetMap'), findsOneWidget);
      await selectPoints(tester);
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.length, 2);
      await press(tester, 'Calculer l’itinéraire');
      final polyline = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single;
      expect(polyline.points.length, 3);
      expect(polyline.points[1].latitude, 33.5750);
      expect(find.text('Distance totale : 2,45 km'), findsOneWidget);
      expect(find.text('Durée estimée : 7 min'), findsOneWidget);
      expect(requests, 1);
      final camera = tester
          .state<CardsViewState>(find.byType(CardsView))
          .mapController
          .camera;
      for (final point in polyline.points) {
        expect(camera.visibleBounds.contains(point), isTrue);
      }
      await press(tester, 'Choisir le départ');
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(PolylineLayer), findsNothing);
      await press(tester, 'Calculer l’itinéraire');
      expect(requests, 2);
      await press(tester, 'Réinitialiser');
      expect(find.byType(PolylineLayer), findsNothing);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      expect(find.text('Départ : non sélectionné'), findsOneWidget);
      expect(find.text('Arrivée : non sélectionné'), findsOneWidget);
    },
  );

  testWidgets('Indique séparément le départ et l’arrivée manquants', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'Calculer l’itinéraire');
    expect(find.textContaining('Aucun départ sélectionné.'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 350));
    await press(tester, 'Calculer l’itinéraire');
    expect(find.textContaining('Aucune arrivée sélectionnée.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('Ignore une réponse tardive après réinitialisation', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    client.close();
    client = MockClient((_) => response.future);
    osrm = OsrmService(client: client);
    await mount(tester);
    await selectPoints(tester);
    await press(tester, 'Calculer l’itinéraire', settle: false);
    expect(find.text('Calcul en cours…'), findsOneWidget);
    await press(tester, 'Réinitialiser');
    response.complete(http.Response(jsonEncode(validOsrmResponse()), 200));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.text('Distance totale : 2,45 km'), findsNothing);
  });

  testWidgets('Affiche une erreur OSRM sans tracer de fausse route', (
    tester,
  ) async {
    client.close();
    client = MockClient((_) async => http.Response('{"code":"NoRoute"}', 200));
    osrm = OsrmService(client: client);
    await mount(tester);
    await selectPoints(tester);
    await press(tester, 'Calculer l’itinéraire');
    expect(find.textContaining('Aucun itinéraire trouvé.'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('Ma position et utilisation comme départ', (tester) async {
    await mount(tester);
    await press(tester, 'Ma position');
    expect(platform.positionRequests, 1);
    expect(find.byKey(const Key('user-position-marker')), findsOneWidget);
    await press(tester, 'Utiliser ma position comme départ');
    expect(
      find.text('Départ : latitude 33.57310, longitude -7.58980'),
      findsOneWidget,
    );
  });

  testWidgets('Suivi, déplacement sans recentrage ni OSRM, puis arrêt', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'Suivi GPS');
    expect(platform.streamStarts, 1);
    final controller = tester
        .state<CardsViewState>(find.byType(CardsView))
        .mapController;
    final center = controller.camera.center;
    platform.positions.add(testPosition(latitude: 33.574));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-position-marker')), findsOneWidget);
    expect(controller.camera.center, center);
    expect(requests, 0);
    // Une localisation ponctuelle ne doit pas désactiver le flux existant.
    await press(tester, 'Ma position');
    platform.positions.add(testPosition(latitude: 33.575));
    await tester.pumpAndSettle();
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .single;
    expect(marker.point.latitude, 33.575);
    await press(tester, 'Arrêter le suivi GPS');
    expect(platform.streamStops, 1);
    platform.positions.add(testPosition(latitude: 33.576));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .single
          .point
          .latitude,
      33.575,
    );
  });

  testWidgets(
    'Un GPS tardif ne restaure pas le départ après réinitialisation',
    (tester) async {
      platform.pendingPosition = Completer<Position>();
      await mount(tester);
      await press(tester, 'Utiliser ma position comme départ', settle: false);
      await press(tester, 'Réinitialiser', settle: false);
      platform.pendingPosition!.complete(testPosition());
      await tester.pumpAndSettle();
      expect(find.text('Départ : non sélectionné'), findsOneWidget);
      final camera = tester
          .state<CardsViewState>(find.byType(CardsView))
          .mapController
          .camera;
      expect(camera.zoom, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Annule le suivi en quittant la page et dans dispose', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'Suivi GPS');
    await mount(tester, active: false);
    expect(platform.streamStops, 1);
    await mount(tester);
    await press(tester, 'Suivi GPS');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(platform.streamStops, 2);
  });

  testWidgets('Annule le suivi lorsque l’application passe en arrière-plan', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'Suivi GPS');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.streamStops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(platform.streamStarts, 1);
  });

  testWidgets('Affiche le refus GPS sans démarrer de suivi', (tester) async {
    platform.permission = LocationPermission.deniedForever;
    await mount(tester);
    await press(tester, 'Suivi GPS');
    expect(find.textContaining('refusée définitivement'), findsOneWidget);
    expect(platform.streamStarts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une erreur du flux GPS arrête la souscription', (tester) async {
    await mount(tester);
    await press(tester, 'Suivi GPS');
    platform.positions.addError(StateError('Signal perdu'));
    await tester.pumpAndSettle();
    expect(platform.streamStops, 1);
    expect(find.textContaining('Position GPS indisponible.'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(900, 400),
    const Size(640, 240),
    const Size(320, 320),
  ]) {
    testWidgets('Pas de débordement de la carte en $size', (tester) async {
      await mount(tester, size: size);
      await press(tester, 'Réinitialiser');
      expect(find.text('© Contributeurs OpenStreetMap'), findsOneWidget);
      final mapRect = tester.getRect(find.byType(FlutterMap));
      final recenterRect = tester.getRect(
        find.byTooltip('Recentrer sur Casablanca'),
      );
      expect(mapRect.contains(recenterRect.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
