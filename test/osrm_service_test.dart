import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:tp33/models/route_result.dart';
import 'package:tp33/services/osrm_service.dart';

import 'support/fakes.dart';

void main() {
  const departure = LatLng(33.5731, -7.5898);
  const arrival = LatLng(33.5800, -7.5800);

  Matcher failureContaining(String text) => isA<OsrmException>().having(
    (error) => error.message,
    'message français',
    contains(text),
  );

  test(
    'GET réel construit en longitude,latitude et décodage GeoJSON',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'router.project-osrm.org');
        expect(
          request.url.path,
          '/route/v1/driving/-7.5898,33.5731;-7.58,33.58',
        );
        expect(request.url.queryParameters, {
          'overview': 'full',
          'geometries': 'geojson',
        });
        return http.Response(jsonEncode(validOsrmResponse()), 200);
      });
      addTearDown(client.close);
      final route = await OsrmService(client: client)
          .calculateRoute(departure, arrival);
      expect(route.points, [
        departure,
        const LatLng(33.5750, -7.5880),
        arrival,
      ]);
      expect(route.distanceMeters, 2450.5);
      expect(route.distanceKilometers, closeTo(2.4505, 0.000001));
      expect(route.durationSeconds, 391.2);
      expect(route.durationMinutes, closeTo(6.52, 0.000001));
      expect(route.formattedDistance, '2,45 km');
      expect(route.formattedDuration, '7 min');
      expect(() => route.points.clear(), throwsUnsupportedError);
    },
  );

  final invalidResponses = <String, (String, int, String)>{
    'NoRoute': ('{"code":"NoRoute","routes":[]}', 200, 'Aucun itinéraire'),
    'NoRoute HTTP 400': ('{"code":"NoRoute"}', 400, 'Aucun itinéraire'),
    'NoSegment': ('{"code":"NoSegment"}', 400, 'Aucun itinéraire'),
    'liste vide': ('{"code":"Ok","routes":[]}', 200, 'Aucun itinéraire'),
    'corps vide': ('', 200, 'invalide'),
    'JSON incorrect': ('<html>Indisponible</html>', 200, 'invalide'),
    'objet absent': ('[]', 200, 'invalide'),
    'statut incorrect': ('{"code":"InvalidQuery"}', 200, 'ne peut pas'),
    'API indisponible': ('maintenance', 503, 'temporairement indisponible'),
    'requêtes limitées': ('', 429, 'temporairement indisponible'),
    'route malformée': ('{"code":"Ok","routes":[null]}', 200, 'invalide'),
  };
  for (final entry in invalidResponses.entries) {
    test('Gère ${entry.key}', () async {
      final (body, status, message) = entry.value;
      final client = MockClient((_) async => http.Response(body, status));
      addTearDown(client.close);
      await expectLater(
        OsrmService(client: client).calculateRoute(departure, arrival),
        throwsA(failureContaining(message)),
      );
    });
  }

  test('Gère les erreurs réseau', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      OsrmService(client: client).calculateRoute(departure, arrival),
      throwsA(failureContaining('connexion Internet')),
    );
  });

  test('Interrompt l’attente après le délai configuré', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    addTearDown(client.close);
    await expectLater(
      OsrmService(
        client: client,
        timeout: const Duration(milliseconds: 5),
      ).calculateRoute(departure, arrival),
      throwsA(failureContaining('trop de temps')),
    );
  });

  test('Refuse des coordonnées de départ invalides avant le réseau', () async {
    final client = MockClient((_) => throw StateError('Aucun appel attendu'));
    addTearDown(client.close);
    await expectLater(
      OsrmService(client: client)
          .calculateRoute(LatLng(double.nan, 0), arrival),
      throwsA(failureContaining('coordonnées')),
    );
  });

  test('Refuse mesures et géométries incomplètes', () {
    final base =
        (validOsrmResponse()['routes'] as List).first as Map<String, dynamic>;
    for (final invalid in [
      {...base, 'distance': -1},
      {...base, 'duration': double.infinity},
      {...base, 'distance': '2450'},
      {
        ...base,
        'geometry': {
          'type': 'Point',
          'coordinates': [0, 0],
        },
      },
      {
        ...base,
        'geometry': {'type': 'LineString', 'coordinates': []},
      },
      {
        ...base,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-7, 33],
          ],
        },
      },
      {
        ...base,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-7, 33],
            [181, 33],
          ],
        },
      },
      {
        ...base,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-7, 33],
            ['x', 33],
          ],
        },
      },
    ]) {
      expect(() => RouteResult.fromOsrmRoute(invalid), throwsFormatException);
    }
  });

  test('Formate les heures et minutes sans tronquer la durée', () {
    RouteResult result(double seconds) => RouteResult(
      points: [departure, arrival],
      distanceMeters: 0,
      durationSeconds: seconds,
    );
    expect(result(0).formattedDuration, 'Moins d’une minute');
    expect(result(3600).formattedDuration, '1 h');
    expect(result(3661).formattedDuration, '1 h 2 min');
  });
}
