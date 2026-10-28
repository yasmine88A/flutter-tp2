import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

// Ces données sont exclusivement réservées aux tests, jamais à l'application.
Map<String, dynamic> validOsrmResponse() => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 2450.5,
      'duration': 391.2,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-7.5898, 33.5731],
          [-7.5880, 33.5750],
          [-7.5800, 33.5800],
        ],
      },
    },
  ],
};

Position testPosition({
  double latitude = 33.5731,
  double longitude = -7.5898,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.utc(2026, 10, 28),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeGeolocator extends GeolocatorPlatform {
  FakeGeolocator() {
    positions = StreamController<Position>.broadcast(
      onListen: () => streamStarts++,
      onCancel: () => streamStops++,
    );
  }

  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionRequests = 0;
  int streamStarts = 0;
  int streamStops = 0;
  Object? positionError;
  Completer<Position>? pendingPosition;
  Position position = testPosition();
  LocationSettings? lastSettings;
  late final StreamController<Position> positions;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionRequests++;
    lastSettings = locationSettings;
    if (positionError != null) throw positionError!;
    if (pendingPosition != null) return pendingPosition!.future;
    return position;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    lastSettings = locationSettings;
    return positions.stream;
  }
}

class OfflineTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('images/profil.jpg');
}
