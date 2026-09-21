import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/features/map/providers/map_providers.dart';
import 'package:frontend/features/map/screens/widgets/scoring_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(layersProvider.notifier).fetchLayers();
    });
  }

  List<Polygon> _buildPolygons(List<Map<String, dynamic>> layers) {
    List<Polygon> polygons = [];
    for (var layer in layers) {
      if (layer.containsKey('coordinates')) {
        try {
          final coords = layer['coordinates'] as List<dynamic>;
          List<LatLng> points = [];
          for (var coord in coords) {
            if (coord is List && coord.length >= 2) {
              points.add(LatLng(
                (coord[1] as num).toDouble(),
                (coord[0] as num).toDouble(),
              ));
            }
          }
          if (points.length >= 3) {
            polygons.add(Polygon(
              points: points,
              borderColor: AppTheme.primary,
              color: AppTheme.primary.withOpacity(0.2),
              borderStrokeWidth: 2,
            ));
          }
        } catch (_) {}
      }
    }
    return polygons;
  }

  List<Marker> _buildMarkers(List<Map<String, dynamic>> scoringData) {
    List<Marker> markers = [];
    for (var data in scoringData) {
      final lat = data['lat'] as double?;
      final lon = data['lon'] as double?;
      final result = data['result'] as Map<String, dynamic>?;
      if (lat != null && lon != null && result != null) {
        final scores = result['scores'] as List<dynamic>? ?? [];
        final primaryScore = scores.isNotEmpty ? scores[0] : null;
        final color = _scoreColor(primaryScore?['overall'] ?? 'N');
        markers.add(Marker(
          point: LatLng(lat, lon),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showScoringDetail(result),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(primaryScore?['emoji'] ?? '❓',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ));
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final layersState = ref.watch(layersProvider);
    final scoringState = ref.watch(scoringProvider);
    final scoringMarkers = ref.watch(scoringMarkersProvider);

    // Auto-save scoring result to markers
    ref.listen<ScoringState>(scoringProvider, (prev, next) {
      if (next.result != null && !next.isLoading && next.lat != null) {
        final exists = ref
            .read(scoringMarkersProvider)
            .any((m) => m['lat'] == next.lat && m['lon'] == next.lon);
        if (!exists) {
          ref.read(scoringMarkersProvider.notifier).addMarker({
            'lat': next.lat,
            'lon': next.lon,
            'result': next.result,
          });
        }
      }
    });

    final polygons = _buildPolygons(layersState.layers);
    final markers = _buildMarkers(scoringMarkers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Pertanian'),
        actions: [
          if (polygons.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: () => _fitAllPolygons(polygons),
              tooltip: 'Lihat Semua',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(layersProvider.notifier).fetchLayers();
              ref.read(scoringMarkersProvider.notifier).clear();
              ref.read(scoringProvider.notifier).clear();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-0.5017804, 117.1393089),
              initialZoom: 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) {
                ref
                    .read(scoringProvider.notifier)
                    .fetchScoring(point.latitude, point.longitude);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend',
              ),
              PolygonLayer(polygons: polygons),
              MarkerLayer(markers: markers),
            ],
          ),

          // Info panel
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildInfoPanel(
                layersState.isLoading, layersState.layers.length, scoringMarkers.length),
          ),

          // Legend
          Positioned(
            bottom: scoringState.result != null ? 180 : 16,
            left: 12,
            child: _buildLegend(),
          ),

          // Loading indicator
          if (scoringState.isLoading)
            Positioned(
              bottom: scoringState.result != null ? 180 : 16,
              right: 12,
              child: _buildLoadingChip(),
            ),

          // Scoring result card
          if (scoringState.result != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildScoringMiniCard(scoringState.result!),
            ),
        ],
      ),
    );
  }

  void _fitAllPolygons(List<Polygon> polygons) {
    if (polygons.isEmpty) return;
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (var polygon in polygons) {
      for (var point in polygon.points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLon) minLon = point.longitude;
        if (point.longitude > maxLon) maxLon = point.longitude;
      }
    }
    _mapController.move(
      LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2),
      11.0,
    );
  }

  void _showScoringDetail(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScoringDetailSheet(scoringData: result),
    );
  }

  Widget _buildInfoPanel(bool isLoading, int layerCount, int markerCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.map, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tap di peta untuk analisis tanah',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$layerCount kawasan • $markerCount analisis',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingChip() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text('Analisis...',
              style: TextStyle(fontSize: 11, color: AppTheme.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildScoringMiniCard(Map<String, dynamic> result) {
    final soil = result['soil_info'] as Map<String, dynamic>?;
    final scores = result['scores'] as List<dynamic>? ?? [];

    return GestureDetector(
      onTap: () => _showScoringDetail(result),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (soil != null)
              Row(
                children: [
                  Icon(Icons.landscape, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${soil['texture_label'] ?? '-'} • pH ${soil['ph_h2o'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${soil['drainage_label'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: scores.map<Widget>((score) {
                final color = _scoreColor(score['overall'] ?? '-');
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(score['emoji'] ?? '❓',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          score['crop_name'] ?? '-',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          score['overall'] ?? '-',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text('Tap untuk detail',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Skor',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppTheme.foreground)),
          const SizedBox(height: 4),
          _legendDot(Colors.green, 'S1 Sangat Sesuai'),
          _legendDot(const Color(0xFF8BC34A), 'S2 Cukup Sesuai'),
          _legendDot(Colors.orange, 'S3 Bersyarat'),
          _legendDot(Colors.red, 'N Tidak Sesuai'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: AppTheme.mutedForeground)),
        ],
      ),
    );
  }

  Color _scoreColor(String score) {
    switch (score) {
      case 'S1':
        return Colors.green;
      case 'S2':
        return const Color(0xFF8BC34A);
      case 'S3':
        return Colors.orange;
      case 'N':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
