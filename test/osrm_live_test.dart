import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tp33/services/osrm_service.dart';

void main() {
  test('Requête réelle au serveur OSRM public à Casablanca', () async {
    final service = OsrmService();
    addTearDown(service.dispose);
    final route = await service.calculateRoute(
      const LatLng(33.5731, -7.5898),
      const LatLng(33.5800, -7.5800),
    );
    expect(route.points.length, greaterThan(2));
    expect(route.distanceMeters, greaterThan(0));
    expect(route.durationSeconds, greaterThan(0));
    // ignore: avoid_print
    print(
      'OSRM réel : ${route.points.length} points, '
      '${route.formattedDistance}, ${route.formattedDuration}.',
    );
  }, skip: !const bool.fromEnvironment('OSRM_LIVE'));
}
