import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/features/map/screens/widgets/score_chip_row.dart';

/// Kartu legend pada peta.
///
/// Selalu terlihat: empat warna tingkat kesesuaian plus jumlah zona untuk
/// masing-masing, sehingga warna di peta bisa langsung dibaca bersama datanya.
/// Bila ada titik/zona terpilih, blok "TERPILIH" ikut ditampilkan.
class MapLegendCard extends StatelessWidget {
  final Map<String, dynamic>? selectedResult;
  final String cropLabel;
  final List<String> zones;

  const MapLegendCard({
    super.key,
    this.selectedResult,
    this.cropLabel = '',
    this.zones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final soil = selectedResult?['soil_info'] as Map<String, dynamic>?;
    final scores = selectedResult?['scores'] as List<dynamic>? ?? [];

    final counts = <String, int>{'S1': 0, 'S2': 0, 'S3': 0, 'N': 0};
    int noData = 0;
    for (final z in zones) {
      if (counts.containsKey(z)) {
        counts[z] = counts[z]! + 1;
      } else {
        noData++;
      }
    }
    final hasCounts = zones.isNotEmpty;

    return Container(
      width: 176,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                Icon(Icons.legend_toggle, size: 13, color: AppTheme.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    cropLabel.isEmpty
                        ? 'Kesesuaian Lahan'
                        : 'Kesesuaian $cropLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          // Baris kelas + jumlah zona
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                for (final s in ['S1', 'S2', 'S3', 'N'])
                  _row(s, hasCounts ? counts[s]! : null),
                if (noData > 0) _row(null, noData),
              ],
            ),
          ),

          // Nilai zona terpilih
          if (soil != null) ...[
            const SizedBox(height: 4),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, size: 11, color: AppTheme.accent),
                      const SizedBox(width: 3),
                      Text(
                        'TERPILIH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SMU ${soil['smu_id'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cardForeground,
                    ),
                  ),
                  Text(
                    '${soil['texture_label'] ?? '-'} · pH ${soil['ph_h2o'] ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppTheme.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                  if (scores.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ScoreChipRow(scores: scores, compact: true),
                  ],
                ],
              ),
            ),
          ] else
            const SizedBox(height: 8),

          // Asal-usul data. Ditampilkan agar pengguna tahu dari mana angka di
          // peta berasal dan bisa menilai sendiri kelayakannya.
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'SUMBER DATA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                SizedBox(height: 4),
                _BarisSumber(
                  label: 'Kawasan',
                  detail: 'Shapefile kawasan pertanian per wilayah',
                ),
                _BarisSumber(
                  label: 'Data tanah',
                  detail: 'HWSD v2.0 (FAO & IIASA), resolusi ~1 km',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String? score, int? count) {
    final color = score == null
        ? const Color(0xFF94A3B8)
        : scoreColor(score);
    final label = score == null ? 'Tanpa data' : scoreLabel(score);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.55),
              borderRadius: BorderRadius.circular(2.5),
              border: Border.all(color: color, width: 0.8),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              score == null ? label : '$score · $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu baris asal-usul data di kaki kartu legend.
class _BarisSumber extends StatelessWidget {
  const _BarisSumber({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 9,
            height: 1.35,
            color: AppTheme.mutedForeground,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: detail),
          ],
        ),
      ),
    );
  }
}
