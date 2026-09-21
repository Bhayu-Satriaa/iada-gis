import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend/features/map/utils/geojson_parser.dart';
import 'package:latlong2/latlong.dart';

class MapView extends StatefulWidget {
  final Map<String, dynamic>? geoJson;

  const MapView({super.key, required this.geoJson});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  List<Polygon> _polygons = [];
  LatLng _mapCenter = const LatLng(	-0.5017804, 117.1393089);

  @override
  void initState() {
    super.initState();
    _processGeoJson();
  }
  
  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.geoJson != oldWidget.geoJson) {
      _processGeoJson();
    }
  }

  void _processGeoJson() {
      final result = parseGeoJson(widget.geoJson);

    setState(() {
      _polygons = result.polygons.map((points) => Polygon(
          points: points,
          borderColor: Colors.blueAccent,
          color: Colors.blue.withValues(alpha: 0.3),
          borderStrokeWidth: 2
        )).toList();

      if (result.centroid != null) {
        _mapCenter = result.centroid!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_mapCenter, 14.0);
          }
        });
      }
    });
  }

 
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 14.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate
            )
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.frontend',
            ),

            PolygonLayer(polygons: _polygons)
          ]
        ),
      ),
    );
  }
}