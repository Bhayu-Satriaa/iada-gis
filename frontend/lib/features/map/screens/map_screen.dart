import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/app/chat_map_provider.dart';
import 'package:frontend/features/map/providers/map_providers.dart';
import 'package:frontend/features/map/screens/widgets/score_chip_row.dart';
import 'package:frontend/features/map/screens/widgets/map_legend_card.dart';
import 'package:frontend/features/map/screens/widgets/scoring_detail_sheet.dart';

/// Satu zona kawasan pertanian: geometri + atribut tanah (kolom properties).
class _Zone {
  final List<LatLng> points;
  final Map<String, dynamic> props;
  const _Zone(this.points, this.props);

  /// Kelas kesesuaian untuk komoditas tertentu, atau null bila tanpa data.
  String? soilClass(String crop) {
    final s = props['scores'];
    if (s is Map) {
      final v = s[crop];
      if (v != null) return v.toString();
    }
    return null;
  }
}

/// Basemap yang bisa dipilih dari menu.
class _Basemap {
  final String label;
  final String url;
  final List<String> subdomains;
  final String attribution;
  const _Basemap(this.label, this.url, this.attribution,
      {this.subdomains = const []});
}

const Map<String, _Basemap> kBasemaps = {
  // CARTO sengaja TIDAK dipakai: tile-nya kini mengembalikan gambar
  // bertuliskan "API KEY REQUIRED". Semua sumber di bawah tanpa kunci.
  'terang': _Basemap(
    'Peta Terang',
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    '© Esri, HERE, Garmin, OpenStreetMap',
  ),
  'gelap': _Basemap(
    'Peta Gelap',
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    '© Esri, HERE, Garmin, OpenStreetMap',
  ),
  'satelit': _Basemap(
    'Citra Satelit',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    '© Esri, Maxar, Earthstar Geographics',
  ),
  'relief': _Basemap(
    'Relief',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Shaded_Relief/MapServer/tile/{z}/{y}/{x}',
    '© Esri, Maxar, Earthstar Geographics',
  ),
  'natgeo': _Basemap(
    'NatGeo',
    'https://server.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer/tile/{z}/{y}/{x}',
    '© National Geographic, Esri',
  ),
  'topografi': _Basemap(
    'Topografi',
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap',
    subdomains: ['a', 'b', 'c'],
  ),
  'jalan': _Basemap(
    'Peta Jalan',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    '© OpenStreetMap contributors',
  ),
};

const Map<String, String> kCrops = {
  'padi': 'Padi',
  'jagung': 'Jagung',
  'kelapa_sawit': 'Kelapa Sawit',
  'kedelai': 'Kedelai',
};

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  int? _highlightedIndex;
  Map<String, dynamic>? _pickedMarkerResult;
  List<_Zone> _lastZones = const [];

  /// Komoditas yang mewarnai peta.
  String _crop = 'padi';

  /// Basemap aktif. Peta Gelap dipakai sebagai default karena zona berwarna
  /// (S1–N) paling kontras di atas latar gelap.
  String _basemap = 'gelap';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(layersProvider.notifier).fetchLayers();
    });
  }

  // ── Parsing zona ──────────────────────────────────────────────────────────

  List<_Zone> _zonesFromLayers(List<Map<String, dynamic>> layers) {
    final out = <_Zone>[];
    for (final layer in layers) {
      try {
        final raw = layer['geojson'] as String?;
        if (raw == null) continue;
        final geo = jsonDecode(raw) as Map<String, dynamic>;
        final props = (layer['properties'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        out.addAll(_zonesFromGeometry(geo, props));
      } catch (_) {}
    }
    return out;
  }

  List<_Zone> _zonesFromGeoJson(Map<String, dynamic> geoJson) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final out = <_Zone>[];
    for (final f in features) {
      try {
        final m = f as Map;
        final geo = m['geometry'] as Map<String, dynamic>?;
        if (geo == null) continue;
        final props = (m['properties'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        out.addAll(_zonesFromGeometry(geo, props));
      } catch (_) {}
    }
    return out;
  }

  List<_Zone> _zonesFromGeometry(
    Map<String, dynamic> geometry,
    Map<String, dynamic> props,
  ) {
    final type = geometry['type'] as String?;
    final coords = geometry['coordinates'] as List<dynamic>?;
    if (coords == null) return [];

    final rings = <List<dynamic>>[];
    if (type == 'Polygon') {
      rings.add(coords);
    } else if (type == 'MultiPolygon') {
      for (final p in coords) {
        if (p is List && p.isNotEmpty) rings.add(p);
      }
    }

    final out = <_Zone>[];
    for (final ring in rings) {
      final outer = ring.isNotEmpty ? ring[0] as List<dynamic> : null;
      if (outer == null) continue;
      final pts = <LatLng>[];
      for (final c in outer) {
        if (c is List && c.length >= 2) {
          pts.add(LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ));
        }
      }
      if (pts.length >= 3) out.add(_Zone(pts, props));
    }
    return out;
  }

  // ── Pewarnaan ─────────────────────────────────────────────────────────────

  /// Basemap yang gelap/ramai perlu zona lebih pekat supaya warna terbaca.
  bool get _darkBase => _basemap == 'gelap' || _basemap == 'satelit';

  Color _zoneFill(_Zone z, String crop, bool highlighted) {
    final cls = z.soilClass(crop);
    final base = cls == null ? const Color(0xFF94A3B8) : scoreColor(cls);
    final fill = _darkBase
        ? (highlighted ? 0.78 : 0.58)
        : (highlighted ? 0.55 : 0.38);
    return base.withOpacity(fill);
  }

  Color _zoneBorder(_Zone z, String crop, bool highlighted) {
    if (highlighted) return AppTheme.accent;
    final cls = z.soilClass(crop);
    return cls == null ? const Color(0xFF64748B) : scoreColor(cls);
  }

  Polygon _polygonOf(_Zone z, {required bool highlighted}) {
    return Polygon(
      points: z.points,
      color: _zoneFill(z, _crop, highlighted),
      borderColor: _zoneBorder(z, _crop, highlighted),
      borderStrokeWidth: highlighted ? 3 : (_darkBase ? 1.3 : 0.8),
    );
  }

  List<Polygon> _renderZones(List<_Zone> zones) {
    final idx = _highlightedIndex;
    return [
      for (int i = 0; i < zones.length; i++)
        _polygonOf(zones[i], highlighted: i == idx),
    ];
  }

  // ── Kamera & geometri ─────────────────────────────────────────────────────

  Map<String, double>? _boundsOf(List<_Zone> zones) {
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    bool any = false;
    for (final z in zones) {
      for (final p in z.points) {
        any = true;
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
    }
    if (!any) return null;
    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLon': minLon,
      'maxLon': maxLon,
    };
  }

  void _fitZones(List<_Zone> zones) {
    if (zones.isEmpty) return;
    final b = _boundsOf(zones);
    if (b == null) return;
    final dLat = b['maxLat']! - b['minLat']!;
    final dLon = b['maxLon']! - b['minLon']!;
    final maxDiff = dLat > dLon ? dLat : dLon;
    double zoom = 13;
    if (maxDiff > 1) {
      zoom = 9;
    } else if (maxDiff > 0.5) {
      zoom = 10;
    } else if (maxDiff > 0.2) {
      zoom = 11;
    } else if (maxDiff > 0.1) {
      zoom = 12;
    }
    try {
      _mapController.move(
        LatLng((b['minLat']! + b['maxLat']!) / 2,
            (b['minLon']! + b['maxLon']!) / 2),
        zoom,
      );
    } catch (_) {}
  }

  bool _pointInPolygon(LatLng p, List<LatLng> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      if (((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _highlightZoneAt(LatLng point) {
    int? found;
    for (int i = 0; i < _lastZones.length; i++) {
      final pts = _lastZones[i].points;
      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
      for (final p in pts) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
      if (point.latitude < minLat ||
          point.latitude > maxLat ||
          point.longitude < minLon ||
          point.longitude > maxLon) {
        continue;
      }
      if (_pointInPolygon(point, pts)) {
        found = i;
        break;
      }
    }
    if (found != _highlightedIndex) {
      setState(() => _highlightedIndex = found);
    }
  }

  // ── Marker ────────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers(
    List<Map<String, dynamic>> saved, {
    Map<String, dynamic>? extra,
    double? extraLat,
    double? extraLon,
  }) {
    final pts = <Map<String, dynamic>>[...saved];
    if (extra != null && extraLat != null && extraLon != null) {
      pts.add({'lat': extraLat, 'lon': extraLon, 'result': extra});
    }

    final markers = <Marker>[];
    for (final d in pts) {
      final lat = (d['lat'] as num?)?.toDouble();
      final lon = (d['lon'] as num?)?.toDouble();
      final result = d['result'] as Map<String, dynamic>?;
      if (lat == null || lon == null || result == null) continue;

      final scores = result['scores'] as List<dynamic>? ?? [];
      final first = scores.isNotEmpty ? scores.first : null;
      final overall = first is Map ? first['overall']?.toString() : null;
      final color = scoreColor(overall);

      markers.add(Marker(
        point: LatLng(lat, lon),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => setState(() => _pickedMarkerResult = result),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: Center(
              child: Text(scoreEmoji(overall),
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
      ));
    }
    return markers;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final layersState = ref.watch(layersProvider);
    final scoringState = ref.watch(scoringProvider);
    final savedMarkers = ref.watch(scoringMarkersProvider);
    final chatMapData = ref.watch(chatMapProvider);

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

    List<_Zone> zones = _zonesFromLayers(layersState.layers);
    if (chatMapData.geoJson != null) {
      final chatZones = _zonesFromGeoJson(chatMapData.geoJson!);
      if (chatZones.isNotEmpty) {
        zones = chatZones;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitZones(chatZones);
        });
      }
    }
    _lastZones = zones;
    final polygons = _renderZones(zones);

    final chatHwsd = chatMapData.hwsdResult;
    final markers = _buildMarkers(
      savedMarkers,
      extra: chatHwsd,
      extraLat: (chatHwsd?['lat'] as num?)?.toDouble(),
      extraLon: (chatHwsd?['lon'] as num?)?.toDouble(),
    );

    final displayResult =
        _pickedMarkerResult ?? scoringState.result ?? chatHwsd;
    final bm = kBasemaps[_basemap] ?? kBasemaps['terang']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Pertanian'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu peta',
            onSelected: (v) => _onMenu(v, zones),
            itemBuilder: (context) => [
              if (zones.isNotEmpty)
                const PopupMenuItem(
                  value: 'fit',
                  child: _MenuRow(icon: Icons.fit_screen, label: 'Lihat Semua'),
                ),
              if (chatMapData.geoJson != null)
                const PopupMenuItem(
                  value: 'layers',
                  child: _MenuRow(icon: Icons.layers, label: 'Semua Layer'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: null,
                enabled: false,
                child: _MenuLabel('Warnai peta menurut'),
              ),
              ...kCrops.entries.map((e) => CheckedPopupMenuItem<String>(
                    value: 'crop:${e.key}',
                    checked: _crop == e.key,
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 13.5)),
                  )),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: null,
                enabled: false,
                child: _MenuLabel('Tampilan peta'),
              ),
              ...kBasemaps.entries.map((e) => CheckedPopupMenuItem<String>(
                    value: 'base:${e.key}',
                    checked: _basemap == e.key,
                    child: Text(e.value.label,
                        style: const TextStyle(fontSize: 13.5)),
                  )),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh',
                child: _MenuRow(icon: Icons.refresh, label: 'Muat Ulang'),
              ),
            ],
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
                _highlightZoneAt(point);
                setState(() => _pickedMarkerResult = null);
                ref
                    .read(scoringProvider.notifier)
                    .fetchScoring(point.latitude, point.longitude);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: bm.url,
                subdomains: bm.subdomains,
                userAgentPackageName: 'com.example.frontend',
              ),
              PolygonLayer(polygons: polygons),
              MarkerLayer(markers: markers),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution(bm.attribution)],
              ),
            ],
          ),

          Positioned(
            top: 12,
            left: 12,
            child: _buildInfoPill(
              isLoading: scoringState.isLoading,
              zoneCount: zones.length,
              markerCount: markers.length,
            ),
          ),

          Positioned(
            top: 12,
            right: 12,
            child: MapLegendCard(
              selectedResult: displayResult,
              cropLabel: kCrops[_crop] ?? '',
              zones: zones
                  .map((z) => z.soilClass(_crop))
                  .whereType<String>()
                  .toList(),
            ),
          ),

          // Panel detail. WAJIB dibungkus Positioned.fill: DraggableScrollableSheet
          // menghitung posisinya dari tinggi constraint yang ia terima. Sebagai
          // anak Stack biasa ia diberi constraint longgar, sehingga panel salah
          // hitung dan muncul di ATAS layar menutupi peta.
          if (displayResult != null)
            Positioned.fill(
              child: ScoringDetailSheet(scoringData: displayResult),
            ),
        ],
      ),
    );
  }

  void _onMenu(String value, List<_Zone> zones) {
    if (value.startsWith('crop:')) {
      setState(() => _crop = value.substring(5));
      return;
    }
    if (value.startsWith('base:')) {
      setState(() => _basemap = value.substring(5));
      return;
    }
    switch (value) {
      case 'fit':
        _fitZones(zones);
        break;
      case 'layers':
        ref.read(chatMapProvider.notifier).clear();
        setState(() {
          _pickedMarkerResult = null;
          _highlightedIndex = null;
        });
        break;
      case 'refresh':
        ref.read(layersProvider.notifier).fetchLayers();
        ref.read(scoringMarkersProvider.notifier).clear();
        ref.read(scoringProvider.notifier).clear();
        ref.read(chatMapProvider.notifier).clear();
        setState(() {
          _pickedMarkerResult = null;
          _highlightedIndex = null;
        });
        break;
    }
  }

  Widget _buildInfoPill({
    required bool isLoading,
    required int zoneCount,
    required int markerCount,
  }) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            )
          else
            Icon(Icons.touch_app, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLoading ? 'Menganalisis...' : 'Tap peta: analisis',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                Text(
                  '$zoneCount zona · $markerCount analisis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.mutedForeground),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13.5)),
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final String text;
  const _MenuLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedForeground,
      ),
    );
  }
}
