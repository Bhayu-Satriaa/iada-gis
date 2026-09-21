import 'package:flutter/material.dart';

/// Widget yang menampilkan hasil analisis kesesuaian lahan HWSD
/// dalam bentuk card di dalam chat bubble bot.
class HwsdCard extends StatefulWidget {
  final Map<String, dynamic> hwsdResult;

  const HwsdCard({super.key, required this.hwsdResult});

  @override
  State<HwsdCard> createState() => _HwsdCardState();
}

class _HwsdCardState extends State<HwsdCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scores = _parseScores(widget.hwsdResult);
    final soilInfo = widget.hwsdResult['soil_info'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(context, scores),

          // ── Skor per komoditas ───────────────────────────────────────────
          if (scores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: scores.map((s) => _buildScoreRow(s)).toList(),
              ),
            ),

          // ── Detail tanah (expandable) ────────────────────────────────────
          if (soilInfo != null && _expanded)
            _buildSoilDetail(soilInfo),

          // ── Toggle detail ────────────────────────────────────────────────
          if (soilInfo != null)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded ? 'Sembunyikan data tanah' : 'Lihat data tanah',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Map<String, dynamic>> scores) {
    // Cari skor terbaik untuk ditampilkan di header
    final bestLabel = scores.isNotEmpty
        ? _getSuitabilityLabel(scores.first['overall'] ?? 'N')
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          const Text(
            'Analisis Kesesuaian Lahan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          if (bestLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'HWSD v2.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(Map<String, dynamic> score) {
    final overall = score['overall'] as String? ?? 'N';
    final cropName = score['crop'] as String? ?? '-';
    final label = _getSuitabilityLabel(overall);
    final color = _getSuitabilityColor(overall);
    final emoji = _getSuitabilityEmoji(overall);
    final limiters = score['limiting_factors'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Badge skor
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                overall,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nama komoditas + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji $cropName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (limiters.isNotEmpty) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Flexible(
                        child: Text(
                          '⚠ ${limiters.join(', ')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilDetail(Map<String, dynamic> soil) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Tanah (HWSD)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 6),
          _soilRow(Icons.texture, 'Tekstur',
              soil['texture']?.toString() ?? 'N/A'),
          _soilRow(Icons.science_rounded, 'pH Tanah',
              soil['ph'] != null ? soil['ph'].toString() : 'N/A'),
          _soilRow(Icons.water_drop_rounded, 'Drainase',
              soil['drainage']?.toString() ?? 'N/A'),
          _soilRow(Icons.grass_rounded, 'Karbon Organik',
              soil['oc'] != null ? '${soil['oc']}%' : 'N/A'),
          const SizedBox(height: 2),
          Text(
            'Kelengkapan data: ${soil['completeness'] ?? 'unknown'}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _soilRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _parseScores(Map<String, dynamic> hwsd) {
    final rawScores = hwsd['scores'];
    if (rawScores == null) return [];
    return List<Map<String, dynamic>>.from(rawScores as List);
  }

  String _getSuitabilityLabel(String overall) {
    switch (overall) {
      case 'S1': return 'Sangat Sesuai';
      case 'S2': return 'Cukup Sesuai';
      case 'S3': return 'Sesuai Bersyarat';
      case 'N':  return 'Tidak Sesuai';
      default:   return overall;
    }
  }

  Color _getSuitabilityColor(String overall) {
    switch (overall) {
      case 'S1': return const Color(0xFF2E7D32); // hijau tua
      case 'S2': return const Color(0xFF558B2F); // hijau sedang
      case 'S3': return const Color(0xFFF57F17); // oranye
      case 'N':  return const Color(0xFFC62828); // merah
      default:   return Colors.grey;
    }
  }

  String _getSuitabilityEmoji(String overall) {
    switch (overall) {
      case 'S1': return '🟢';
      case 'S2': return '🟡';
      case 'S3': return '🟠';
      case 'N':  return '🔴';
      default:   return '⚪';
    }
  }
}
