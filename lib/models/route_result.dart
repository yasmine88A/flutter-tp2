import 'package:latlong2/latlong.dart';

/// Les mesures OSRM restent en unités SI ; l'interface utilise les conversions.
class RouteResult {
  RouteResult({
    required List<LatLng> points,
    required this.distanceMeters,
    required this.durationSeconds,
  }) : points = List.unmodifiable(points);

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  double get distanceKilometers => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;

  String get formattedDistance =>
      '${distanceKilometers.toStringAsFixed(2).replaceAll('.', ',')} km';

  String get formattedDuration {
    final minutes = durationMinutes.ceil();
    if (minutes == 0) return 'Moins d’une minute';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours h' : '$hours h $remainder min';
  }

  factory RouteResult.fromOsrmRoute(Map<String, dynamic> route) {
    final distance = route['distance'];
    final duration = route['duration'];
    final geometry = route['geometry'];
    if (distance is! num ||
        !distance.isFinite ||
        distance < 0 ||
        duration is! num ||
        !duration.isFinite ||
        duration < 0 ||
        geometry is! Map<String, dynamic> ||
        geometry['type'] != 'LineString') {
      throw const FormatException('Mesures ou géométrie OSRM invalides.');
    }
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      throw const FormatException('Le tracé OSRM est vide ou incomplet.');
    }
    final points = coordinates.map((coordinate) {
      if (coordinate is! List || coordinate.length < 2) {
        throw const FormatException('Coordonnées OSRM invalides.');
      }
      final longitude = coordinate[0];
      final latitude = coordinate[1];
      if (longitude is! num ||
          latitude is! num ||
          !longitude.isFinite ||
          !latitude.isFinite ||
          longitude.abs() > 180 ||
          latitude.abs() > 90) {
        throw const FormatException('Coordonnées OSRM hors limites.');
      }
      // GeoJSON emploie [longitude, latitude], contrairement à LatLng.
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }).toList();
    return RouteResult(
      points: points,
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }
}
