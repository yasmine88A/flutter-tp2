import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';

class OsrmException implements Exception {
  const OsrmException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OsrmService {
  OsrmService({http.Client? client, this.timeout = const Duration(seconds: 15)})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<RouteResult> calculateRoute(LatLng departure, LatLng arrival) async {
    for (final point in [departure, arrival]) {
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        throw const OsrmException(
          'Les coordonnées sélectionnées sont invalides.',
        );
      }
    }
    final coordinates =
        '${departure.longitude},${departure.latitude};'
        '${arrival.longitude},${arrival.latitude}';
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      {'overview': 'full', 'geometries': 'geojson'},
    );
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      // Les erreurs OSRM comme NoRoute peuvent aussi utiliser HTTP 400.
      if (response.statusCode != 200 && response.statusCode != 400) {
        throw const OsrmException(
          'L’API OSRM est temporairement indisponible. Réessayez plus tard.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse OSRM invalide.');
      }
      final code = decoded['code'];
      if (code == 'NoRoute' || code == 'NoSegment') {
        throw const OsrmException(
          'Aucun itinéraire trouvé. Choisissez des points proches des routes.',
        );
      }
      if (response.statusCode != 200 || code != 'Ok') {
        throw const OsrmException(
          'L’API OSRM ne peut pas calculer ce trajet. Réessayez plus tard.',
        );
      }
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        throw const OsrmException('Aucun itinéraire trouvé entre ces points.');
      }
      if (routes.first is! Map<String, dynamic>) {
        throw const FormatException('Itinéraire OSRM invalide.');
      }
      return RouteResult.fromOsrmRoute(routes.first as Map<String, dynamic>);
    } on TimeoutException {
      throw const OsrmException(
        'Le serveur OSRM met trop de temps à répondre. Réessayez.',
      );
    } on http.ClientException {
      throw const OsrmException(
        'Échec de connexion Internet. Vérifiez votre connexion puis réessayez.',
      );
    } on FormatException {
      throw const OsrmException(
        'La réponse de l’API OSRM est invalide ou incomplète. Réessayez.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
