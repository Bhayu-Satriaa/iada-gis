import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/app/theme.dart';

class ChatMapPreview extends StatelessWidget {
  final Map<String, dynamic> geoJson;
  final Map<String, dynamic>? hwsdResult;
  final VoidCallback? onTap;

  const ChatMapPreview({
    super.key,
    required this.geoJson,
    this.hwsdResult,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final polygons = _parsePolygons(geoJson);
    if (polygons.isEmpty) return const SizedBox.shrink();

    // Hitung bounds dari semua polygon
    final bounds = _calculateBounds(polygons);
    final center = LatLng(
      (bounds['minLat']! + bounds['maxLat']!) / 2,
      (bounds['minLon']! + bounds['maxLon']!) / 2,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // Mini map
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _calculateZoom(bounds),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    PolygonLayer(polygons: polygons),
                    // Marker centroid jika ada HWSD
                    if (hwsdResult != null &&
                        hwsdResult!['lat'] != null &&
                        hwsdResult!['lon'] != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(
                            (hwsdResult!['lat'] as num).toDouble(),
                            (hwsdResult!['lon'] as num).toDouble(),
                          ),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.grass,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
              // HWSD scoring summary
              if (hwsdResult != null) _buildHwsdSummary(hwsdResult!),
              // Tap hint
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: AppTheme.primary.withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Tap untuk buka peta lengkap',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHwsdSummary(Map<String, dynamic> hwsd) {
    final soil = hwsd['soil_info'] as Map<String, dynamic>?;
    final scores = hwsd['scores'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.03),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Soil info
          if (soil != null)
            Row(
              children: [
                Icon(Icons.landscape, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${soil['texture'] ?? '-'} • pH ${soil['ph'] ?? '-'} • ${soil['drainage'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          // Crop scores
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: scores.map<Widget>((score) {
              final color = _scoreColor(score['overall'] ?? '-');
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(score['emoji'] ?? '❓',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 2),
                    Text(
                      '${score['crop'] ?? '-'}: ${score['overall'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Polygon> _parsePolygons(Map<String, dynamic> geoJson) {
    List<Polygon> polygons = [];
    final features = geoJson['features'] as List<dynamic>? ?? [];

    for (var feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null) continue;

        final type = geometry['type'] as String?;
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null) continue;

        if (type == 'Polygon') {
          final outerRing = coordinates[0] as List<dynamic>;
          List<LatLng> points = [];
          for (var coord in outerRing) {
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
              color: AppTheme.primary.withOpacity(0.15),
              borderStrokeWidth: 1,
            ));
          }
        } else if (type == 'MultiPolygon') {
          for (var polygonCoords in coordinates) {
            if (polygonCoords is List && polygonCoords.isNotEmpty) {
              final outerRing = polygonCoords[0] as List<dynamic>;
              List<LatLng> points = [];
              for (var coord in outerRing) {
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
                  color: AppTheme.primary.withOpacity(0.15),
                  borderStrokeWidth: 1,
                ));
              }
            }
          }
        }
      } catch (_) {}
    }
    return polygons;
  }

  Map<String, double> _calculateBounds(List<Polygon> polygons) {
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (var polygon in polygons) {
      for (var point in polygon.points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLon) minLon = point.longitude;
        if (point.longitude > maxLon) maxLon = point.longitude;
      }
    }
    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLon': minLon,
      'maxLon': maxLon,
    };
  }

  double _calculateZoom(Map<String, double> bounds) {
    final latDiff = bounds['maxLat']! - bounds['minLat']!;
    final lonDiff = bounds['maxLon']! - bounds['minLon']!;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff > 1) return 9;
    if (maxDiff > 0.5) return 10;
    if (maxDiff > 0.2) return 11;
    if (maxDiff > 0.1) return 12;
    return 13;
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