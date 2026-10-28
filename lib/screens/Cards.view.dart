import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/route_result.dart';
import '../services/location_service.dart';
import '../services/osrm_service.dart';

enum _SelectedPoint { departure, arrival }

class CardsView extends StatefulWidget {
  const CardsView({
    super.key,
    this.osrmService,
    this.locationService,
    this.tileProvider,
    this.isActive = true,
  });

  final OsrmService? osrmService;
  final LocationService? locationService;
  // Les tests injectent un fournisseur de tuiles sans accès réseau.
  final TileProvider? tileProvider;
  final bool isActive;

  @override
  State<CardsView> createState() => CardsViewState();
}

class CardsViewState extends State<CardsView> with WidgetsBindingObserver {
  final MapController mapController = MapController();
  static const LatLng casablanca = LatLng(33.5731, -7.5898);
  late final OsrmService _osrmService;
  late final LocationService _locationService;

  LatLng? _departure;
  LatLng? _arrival;
  LatLng? _userPosition;
  RouteResult? _route;
  _SelectedPoint _selectedPoint = _SelectedPoint.departure;
  bool _calculating = false;
  bool _locating = false;
  bool _tracking = false;
  String? _routeError;
  LocationException? _locationError;
  String _gpsStatus = 'GPS inactif. Votre position est affichée en bleu.';
  StreamSubscription<Position>? _positionSubscription;
  int _routeRequest = 0;
  int _gpsRequest = 0;
  int _trackingRequest = 0;

  @override
  void initState() {
    super.initState();
    _osrmService = widget.osrmService ?? OsrmService();
    _locationService = widget.locationService ?? LocationService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CardsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) _stopTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopTracking();
    }
  }

  void changeZoom(double value) {
    final camera = mapController.camera;
    mapController.move(camera.center, (camera.zoom + value).clamp(3.0, 18.0));
  }

  void _invalidateRoute() {
    // Une réponse tardive ne doit pas restaurer un ancien trajet.
    _routeRequest++;
    _route = null;
    _routeError = null;
    _calculating = false;
  }

  void _selectPosition(LatLng point) {
    setState(() {
      _invalidateRoute();
      final position = LatLng(
        point.latitude,
        ((point.longitude + 180) % 360) - 180,
      );
      if (_selectedPoint == _SelectedPoint.departure) {
        _departure = position;
        if (_arrival == null) _selectedPoint = _SelectedPoint.arrival;
      } else {
        _arrival = position;
      }
    });
  }

  void resetMap() {
    setState(() {
      _invalidateRoute();
      _departure = null;
      _arrival = null;
      _selectedPoint = _SelectedPoint.departure;
    });
    mapController.move(casablanca, 12);
  }

  Future<void> _calculateRoute() async {
    if (_calculating) return;
    final departure = _departure;
    final arrival = _arrival;
    if (departure == null || arrival == null) {
      setState(() {
        _routeError = departure == null
            ? 'Aucun départ sélectionné. Touchez la carte pour le choisir.'
            : 'Aucune arrivée sélectionnée. Touchez la carte pour la choisir.';
      });
      return;
    }
    final request = ++_routeRequest;
    setState(() {
      _calculating = true;
      _route = null;
      _routeError = null;
    });
    try {
      final route = await _osrmService.calculateRoute(departure, arrival);
      if (!mounted || request != _routeRequest) return;
      setState(() => _route = route);
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [departure, arrival, ...route.points],
          padding: const EdgeInsets.fromLTRB(40, 50, 72, 40),
          maxZoom: 16,
        ),
      );
    } catch (error) {
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _routeError = error is OsrmException
            ? error.message
            : 'Impossible de calculer l’itinéraire. Réessayez.';
      });
    } finally {
      if (mounted && request == _routeRequest) {
        setState(() => _calculating = false);
      }
    }
  }

  LatLng _coordinates(Position position) {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw const LocationException(
        LocationFailure.unavailable,
        'Position GPS indisponible : les coordonnées reçues sont invalides.',
      );
    }
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _locate({bool useAsDeparture = false}) async {
    if (_locating) return;
    final request = ++_gpsRequest;
    final routeRequest = _routeRequest;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final position = _coordinates(
        await _locationService.getCurrentPosition(),
      );
      if (!mounted || request != _gpsRequest) return;
      final selectionUnchanged = routeRequest == _routeRequest;
      setState(() {
        _userPosition = position;
        if (useAsDeparture && selectionUnchanged) {
          _usePositionAsDeparture(position);
        }
        _gpsStatus = _tracking
            ? 'Suivi GPS actif.'
            : 'Position GPS actualisée.';
      });
      if (selectionUnchanged) mapController.move(position, 15);
    } catch (error) {
      if (!mounted || request != _gpsRequest) return;
      setState(() => _locationError = LocationException.from(error));
    } finally {
      if (mounted && request == _gpsRequest) {
        setState(() => _locating = false);
      }
    }
  }

  void _usePositionAsDeparture(LatLng position) {
    _invalidateRoute();
    _departure = position;
    _selectedPoint = _SelectedPoint.arrival;
  }

  Future<void> _startTracking() async {
    if (_locating || _tracking) return;
    final request = ++_trackingRequest;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      await _locationService.ensureAccess();
      if (!mounted || request != _trackingRequest) return;
      _positionSubscription = _locationService.getPositionStream().listen(
        (position) {
          if (!mounted || request != _trackingRequest) return;
          try {
            final point = _coordinates(position);
            setState(() {
              _userPosition = point;
              _gpsStatus =
                  'Suivi GPS actif · précision : '
                  '${position.accuracy.round()} m.';
            });
            // Ne recentre pas la carte et ne recalcule jamais OSRM ici.
          } catch (error) {
            _handleTrackingError(error);
          }
        },
        onError: (Object error) {
          if (mounted && request == _trackingRequest) {
            _handleTrackingError(error);
          }
        },
        onDone: () {
          if (mounted && request == _trackingRequest) _stopTracking();
        },
      );
      setState(() {
        _tracking = true;
        _gpsStatus = 'Suivi GPS actif · en attente d’une position…';
      });
    } catch (error) {
      if (!mounted || request != _trackingRequest) return;
      setState(() => _locationError = LocationException.from(error));
    } finally {
      if (mounted && request == _trackingRequest) {
        setState(() => _locating = false);
      }
    }
  }

  void _handleTrackingError(Object error) {
    _stopTracking();
    setState(() => _locationError = LocationException.from(error));
  }

  void _stopTracking() {
    _gpsRequest++;
    _trackingRequest++;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (!mounted) return;
    setState(() {
      _tracking = false;
      _locating = false;
      _gpsStatus = 'Suivi GPS arrêté. La dernière position reste affichée.';
    });
  }

  Future<void> _openSettings(bool appSettings) async {
    try {
      final opened = appSettings
          ? await _locationService.openAppSettings()
          : await _locationService.openLocationSettings();
      if (!opened) throw StateError('Réglages indisponibles');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = const LocationException(
          LocationFailure.unavailable,
          'Ouvrez les réglages de votre appareil pour autoriser la localisation.',
        );
      });
    }
  }

  Future<void> _openAttribution() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
      );
      if (!opened) throw StateError('Lien indisponible');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Licence : https://www.openstreetmap.org/copyright'),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeRequest++;
    _gpsRequest++;
    _trackingRequest++;
    final subscription = _positionSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    if (widget.osrmService == null) _osrmService.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 760 ||
            (constraints.maxWidth >= 560 && constraints.maxHeight < 420);
        final mapHeight = wide
            ? constraints.maxHeight
            : constraints.maxHeight * 5 / 11;
        final map = _buildMap(compactControls: mapHeight < 190);
        final panel = Material(
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _buildPanel(),
          ),
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: map),
              SizedBox(
                width: constraints.maxWidth >= 760
                    ? 340
                    : constraints.maxWidth * 0.48,
                child: panel,
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 5, child: map),
            Expanded(flex: 6, child: panel),
          ],
        );
      },
    );
  }

  Widget _buildMap({required bool compactControls}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: casablanca,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, point) => _selectPosition(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tp33',
                tileProvider: widget.tileProvider,
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.points,
                      color: const Color(0xFF1565C0),
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_departure != null)
                    _pointMarker(_departure!, Colors.green.shade700, 'Départ'),
                  if (_arrival != null)
                    _pointMarker(_arrival!, Colors.red.shade700, 'Arrivée'),
                  if (_userPosition != null)
                    Marker(
                      point: _userPosition!,
                      width: 28,
                      height: 28,
                      child: Semantics(
                        label: 'Ma position GPS',
                        child: Container(
                          key: const Key('user-position-marker'),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Attribution visible et extérieure au panneau défilant.
              Align(
                alignment: Alignment.bottomRight,
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: _openAttribution,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '© Contributeurs OpenStreetMap',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              child: Flex(
                direction: compactControls ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom avant',
                    onPressed: () => changeZoom(1),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Zoom arrière',
                    onPressed: () => changeZoom(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Recentrer sur Casablanca',
                    onPressed: () => mapController.move(casablanca, 12),
                    icon: const Icon(Icons.home_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _pointMarker(LatLng point, Color color, String label) => Marker(
    point: point,
    width: 44,
    height: 44,
    alignment: Alignment.topCenter,
    child: Tooltip(
      message: label,
      child: Icon(Icons.location_pin, color: color, size: 44),
    ),
  );

  Widget _buildPanel() {
    final route = _route;
    final locationError = _locationError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mon itinéraire',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedPoint == _SelectedPoint.departure
              ? 'Touchez la carte pour choisir le départ.'
              : 'Touchez la carte pour choisir l’arrivée.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Choisir le départ'),
              avatar: Icon(Icons.trip_origin, color: Colors.green.shade700),
              selected: _selectedPoint == _SelectedPoint.departure,
              onSelected: (_) =>
                  setState(() => _selectedPoint = _SelectedPoint.departure),
            ),
            ChoiceChip(
              label: const Text('Choisir l’arrivée'),
              avatar: Icon(Icons.location_on, color: Colors.red.shade700),
              selected: _selectedPoint == _SelectedPoint.arrival,
              onSelected: (_) =>
                  setState(() => _selectedPoint = _SelectedPoint.arrival),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _coordinateText('Départ', _departure),
        _coordinateText('Arrivée', _arrival),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _calculating ? null : _calculateRoute,
          icon: const Icon(Icons.route),
          label: Text(
            _calculating ? 'Calcul en cours…' : 'Calculer l’itinéraire',
          ),
        ),
        if (_calculating) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(semanticsLabel: 'Calcul OSRM en cours'),
        ],
        if (_routeError != null) _errorText(_routeError!),
        if (route != null)
          Card(
            color: const Color(0xFFE5F0FF),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Itinéraire routier calculé',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Distance totale : ${route.formattedDistance}'),
                  Text('Durée estimée : ${route.formattedDuration}'),
                  const Text(
                    'Estimation OSRM en voiture, hors trafic en temps réel.',
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : () => _locate(),
              icon: const Icon(Icons.my_location),
              label: const Text('Ma position'),
            ),
            OutlinedButton.icon(
              onPressed: _tracking
                  ? _stopTracking
                  : (_locating ? null : _startTracking),
              icon: Icon(_tracking ? Icons.gps_off : Icons.gps_fixed),
              label: Text(_tracking ? 'Arrêter le suivi GPS' : 'Suivi GPS'),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _locating
              ? null
              : () {
                  final position = _userPosition;
                  if (position == null) {
                    unawaited(_locate(useAsDeparture: true));
                  } else {
                    setState(() => _usePositionAsDeparture(position));
                  }
                },
          icon: const Icon(Icons.start),
          label: const Text('Utiliser ma position comme départ'),
        ),
        if (_locating)
          const LinearProgressIndicator(
            semanticsLabel: 'Recherche GPS en cours',
          ),
        Text(_gpsStatus, style: const TextStyle(fontSize: 12)),
        if (locationError != null) ...[
          _errorText(locationError.message),
          if (!kIsWeb &&
              (locationError.failure == LocationFailure.deniedForever ||
                  locationError.failure == LocationFailure.disabled))
            TextButton(
              onPressed: () => _openSettings(
                locationError.failure == LocationFailure.deniedForever,
              ),
              child: const Text('Ouvrir les réglages'),
            ),
        ],
        TextButton.icon(
          onPressed: resetMap,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Réinitialiser'),
        ),
      ],
    );
  }

  Widget _coordinateText(String label, LatLng? point) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      point == null
          ? '$label : non sélectionné'
          : '$label : latitude ${point.latitude.toStringAsFixed(5)}, '
                'longitude ${point.longitude.toStringAsFixed(5)}',
      style: const TextStyle(fontSize: 12),
    ),
  );

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    ),
  );
}
