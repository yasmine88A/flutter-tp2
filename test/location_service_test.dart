import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tp33/services/location_service.dart';

import 'support/fakes.dart';

void main() {
  late FakeGeolocator platform;
  late LocationService service;
  setUp(() {
    platform = FakeGeolocator();
    service = LocationService(platform: platform);
  });
  tearDown(() => platform.positions.close());

  Matcher failure(LocationFailure kind) => isA<LocationException>().having(
    (error) => error.failure,
    'type d’erreur',
    kind,
  );

  test('Ne demande rien au GPS à la création du service', () {
    expect(platform.permissionRequests, 0);
    expect(platform.positionRequests, 0);
    expect(platform.streamStarts, 0);
  });

  test('Position réelle du fournisseur avec permission existante', () async {
    expect(await service.getCurrentPosition(), same(platform.position));
    expect(platform.permissionRequests, 0);
    expect(platform.lastSettings!.accuracy, LocationAccuracy.high);
    expect(platform.lastSettings!.timeLimit, const Duration(seconds: 25));
  });

  test('Demande une permission refusée puis nouvellement accordée', () async {
    platform.permission = LocationPermission.denied;
    await service.getCurrentPosition();
    expect(platform.permissionRequests, 1);
    expect(platform.positionRequests, 1);
  });

  test('Permission refusée sans récupérer de position', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;
    await expectLater(
      service.getCurrentPosition(),
      throwsA(failure(LocationFailure.denied)),
    );
    expect(platform.positionRequests, 0);
  });

  test('Permission définitivement refusée sans nouvelle demande', () async {
    platform.permission = LocationPermission.deniedForever;
    await expectLater(
      service.ensureAccess(),
      throwsA(failure(LocationFailure.deniedForever)),
    );
    expect(platform.permissionRequests, 0);
  });

  test('Refus définitif reçu après une demande', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.deniedForever;
    await expectLater(
      service.ensureAccess(),
      throwsA(failure(LocationFailure.deniedForever)),
    );
  });

  test('Service de localisation désactivé', () async {
    platform.enabled = false;
    await expectLater(
      service.getCurrentPosition(),
      throwsA(failure(LocationFailure.disabled)),
    );
    expect(platform.positionRequests, 0);
  });

  test('Position indisponible et délai GPS dépassé', () async {
    platform.positionError = TimeoutException('Pas de signal');
    await expectLater(
      service.getCurrentPosition(),
      throwsA(failure(LocationFailure.unavailable)),
    );
  });

  test('Le flux transmet les déplacements et peut être annulé', () async {
    await service.ensureAccess();
    final received = <Position>[];
    final subscription = service.getPositionStream().listen(received.add);
    final moved = testPosition(latitude: 33.574);
    platform.positions.add(platform.position);
    platform.positions.add(moved);
    await Future<void>.delayed(Duration.zero);
    expect(received, [platform.position, moved]);
    expect(platform.lastSettings!.distanceFilter, 5);
    await subscription.cancel();
    expect(platform.streamStops, 1);
    platform.positions.add(testPosition(latitude: 33.575));
    await Future<void>.delayed(Duration.zero);
    expect(received.length, 2);
  });
}
