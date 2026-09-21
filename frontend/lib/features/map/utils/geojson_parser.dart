import 'package:latlong2/latlong.dart';

/// Hasil parsing GeoJSON.
/// [polygons] — setiap item adalah outer ring satu polygon sebagai list koordinat.
/// [centroid] — titik tengah rata-rata semua koordinat, null jika tidak ada data.
class GeoJsonParseResult {
  final List<List<LatLng>> polygons;
  final LatLng? centroid;

  const GeoJsonParseResult({required this.polygons, this.centroid});
}

/// Pure function — tidak bergantung pada Flutter/flutter_map sama sekali.
/// Menerima Map GeoJSON FeatureCollection, mengembalikan [GeoJsonParseResult].
/// Mendukung geometry type: Polygon dan MultiPolygon.
GeoJsonParseResult parseGeoJson(Map<String, dynamic>? geoJson) {
  if (geoJson == null || geoJson['features'] == null) {
    return const GeoJsonParseResult(polygons: []);
  }

  final List<List<LatLng>> parsedPolygons = [];
  double sumLat = 0;
  double sumLon = 0;
  int pointCount = 0;

  final features = geoJson['features'] as List;

  for (final feature in features) {
    final geometry = feature['geometry'];
    if (geometry == null) continue;

    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'] as List;

    if (type == 'Polygon') {
      final result = _parseSinglePolygon(coordinates);
      parsedPolygons.addAll(result.polygons);
      sumLat += result.sumLat;
      sumLon += result.sumLon;
      pointCount += result.pointCount;
    } else if (type == 'MultiPolygon') {
      for (final polygonCoords in coordinates) {
        final result = _parseSinglePolygon(polygonCoords as List);
        parsedPolygons.addAll(result.polygons);
        sumLat += result.sumLat;
        sumLon += result.sumLon;
        pointCount += result.pointCount;
      }
    }
    // geometry type lain (Point, LineString, dll) diabaikan
  }

  final LatLng? centroid = pointCount > 0
      ? LatLng(sumLat / pointCount, sumLon / pointCount)
      : null;

  return GeoJsonParseResult(polygons: parsedPolygons, centroid: centroid);
}

// ---------------------------------------------------------------------------
// Helper — top-level function (bukan nested), hanya untuk internal file ini.
// ---------------------------------------------------------------------------

/// Record internal untuk akumulasi data saat parsing satu polygon.
typedef _PolygonParseData = ({
  List<List<LatLng>> polygons,
  double sumLat,
  double sumLon,
  int pointCount,
});

/// Parse satu Polygon (koordinat = [outerRing, ...holes]).
/// Hanya outer ring yang dipakai, holes diabaikan.
_PolygonParseData _parseSinglePolygon(List coordinates) {
  final outerRing = coordinates[0] as List;
  final List<LatLng> points = [];
  double sumLat = 0;
  double sumLon = 0;

  for (final coord in outerRing) {
    final double lon = (coord[0] as num).toDouble();
    final double lat = (coord[1] as num).toDouble();
    points.add(LatLng(lat, lon));
    sumLat += lat;
    sumLon += lon;
  }

  return (
    polygons: [points],
    sumLat: sumLat,
    sumLon: sumLon,
    pointCount: outerRing.length,
  );
}