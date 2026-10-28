import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationFailure { denied, deniedForever, disabled, unavailable }

class LocationException implements Exception {
  const LocationException(this.failure, this.message);

  final LocationFailure failure;
  final String message;

  factory LocationException.from(Object error) {
    if (error is LocationException) return error;
    if (error is LocationServiceDisabledException) {
      return const LocationException(
        LocationFailure.disabled,
        'Le service de localisation est désactivé. Activez-le puis réessayez.',
      );
    }
    if (error is PermissionDeniedException) {
      return const LocationException(
        LocationFailure.denied,
        'La permission GPS a été refusée. Autorisez la localisation puis réessayez.',
      );
    }
    return const LocationException(
      LocationFailure.unavailable,
      'Position GPS indisponible. Vérifiez le signal et réessayez à l’extérieur. '
      'Sur le Web, utilisez localhost ou HTTPS et autorisez la localisation.',
    );
  }

  @override
  String toString() => message;
}

/// Accès au GPS réel. La souscription appartient à l'écran qui l'annule.
class LocationService {
  LocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  Future<void> ensureAccess() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        throw const LocationException(
          LocationFailure.disabled,
          'Le service de localisation est désactivé. Activez-le puis réessayez.',
        );
      }
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          LocationFailure.deniedForever,
          'La permission GPS est refusée définitivement. Autorisez-la dans les '
          'réglages de l’application ou du navigateur.',
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const LocationException(
          LocationFailure.denied,
          'La permission GPS a été refusée. Autorisez la localisation puis réessayez.',
        );
      }
    } catch (error) {
      throw LocationException.from(error);
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensureAccess();
    try {
      return await _platform
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 25),
            ),
          )
          .timeout(const Duration(seconds: 25));
    } catch (error) {
      throw LocationException.from(error);
    }
  }

  /// Appeler ensureAccess avant de souscrire. Aucune notification de fond.
  Stream<Position> getPositionStream() => _platform.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  Future<bool> openAppSettings() => _platform.openAppSettings();
  Future<bool> openLocationSettings() => _platform.openLocationSettings();
}
