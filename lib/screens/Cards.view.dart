import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CardsView extends StatefulWidget {
  const CardsView({super.key});

  @override
  State<CardsView> createState() => CardsViewState();
}

class CardsViewState extends State<CardsView> {
  final MapController mapController = MapController();
  
  // Position initiale : Casablanca
  static const LatLng casablanca = LatLng(33.5731, -7.5898);
  LatLng selectedPosition = casablanca;
  double zoom = 12.0;

  void changeZoom(double value) {
    final newZoom = (zoom + value).clamp(3.0, 18.0);
    mapController.move(mapController.camera.center, newZoom);
  }

  void resetMap() {
    mapController.move(casablanca, 12);
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: casablanca,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 18,
              // Sélectionner une position
              onTap: (tapPosition, point) {
                setState(() {
                  selectedPosition = point;
                });
              },
              // Correctly placed inside MapOptions
              onPositionChanged: (camera, hasGesture) {
                zoom = camera.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tp33',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: selectedPosition,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),
          
          // Boutons de zoom
          Positioned(
            top: 20,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomPlus',
                  onPressed: () => changeZoom(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoomMinus',
                  onPressed: () => changeZoom(-1),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'resetMap',
                  onPressed: resetMap,
                  child: const Icon(Icons.home),
                ),
              ],
            ),
          ),
          
          // Coordonnées géographiques
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Position sélectionnée',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Latitude : ${selectedPosition.latitude.toStringAsFixed(5)}',
                    ),
                    Text(
                      'Longitude : ${selectedPosition.longitude.toStringAsFixed(5)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}