import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/features/map/screens/widgets/score_chip_row.dart';

/// Panel detail kesesuaian lahan.
///
/// Bertingkat (draggable), mengikuti pola referensi desain:
///   - Peek    : identitas tanah + ringkasan 4 skor komoditas
///   - Setengah: kartu data tanah (label–nilai) + banner kepastian data
///   - Penuh   : rincian per parameter, alasan, dan catatan mesin penilai
class ScoringDetailSheet extends StatelessWidget {
  final Map<String, dynamic> scoringData;

  const ScoringDetailSheet({super.key, required this.scoringData});

  @override
  Widget build(BuildContext context) {
    final soil = scoringData['soil_info'] as Map<String, dynamic>?;
    final scores = scoringData['scores'] as List<dynamic>? ?? [];
    final summary = scoringData['summary'] as String? ?? '';
    final incomplete = _dataIncomplete(soil, scores);

    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Judul ────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.landscape,
                        size: 19, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analisis Kesesuaian Lahan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                        Text(
                          'SMU ${soil?['smu_id'] ?? '-'}'
                          '${soil?['texture_label'] != null ? ' · ${soil!['texture_label']}' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Ringkasan skor (terlihat sejak peek) ─────────────────
              if (scores.isNotEmpty) ScoreChipRow(scores: scores),
              const SizedBox(height: 16),

              // ── Banner kepastian data ────────────────────────────────
              if (incomplete) ...[
                _buildDataWarning(soil, scores),
                const SizedBox(height: 14),
              ],

              // ── Kartu data tanah ─────────────────────────────────────
              if (soil != null) ...[
                _sectionTitle('Data Tanah'),
                const SizedBox(height: 7),
                _buildSoilGrid(soil),
                const SizedBox(height: 16),
              ],

              // ── Skor per komoditas ───────────────────────────────────
              _sectionTitle('Kesesuaian Komoditas'),
              const SizedBox(height: 7),
              ...scores.map((s) => _buildScoreCard(s)),

              // ── Ringkasan teks ───────────────────────────────────────
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.foreground,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Bagian-bagian ────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.foreground,
        ),
      );

  /// Skor dianggap tidak berkepastian penuh bila data tanah tidak lengkap
  /// atau ada komoditas yang dihitung dengan data parsial.
  bool _dataIncomplete(Map<String, dynamic>? soil, List<dynamic> scores) {
    if (soil == null) return true;
    if ((soil['data_completeness'] ?? '').toString() != 'full') return true;
    for (final s in scores) {
      if (s is Map && s['data_sufficient'] == false) return true;
    }
    return false;
  }

  List<String> _missingParameters(List<dynamic> scores) {
    final missing = <String>{};
    for (final s in scores) {
      if (s is! Map) continue;
      final params = s['parameters'] as List<dynamic>? ?? [];
      for (final p in params) {
        if (p is Map && p['value'] == null && p['parameter'] != 'Drainase') {
          missing.add('${p['parameter']}');
        }
      }
    }
    return missing.toList();
  }

  Widget _buildDataWarning(
      Map<String, dynamic>? soil, List<dynamic> scores) {
    final missing = _missingParameters(scores);
    final completeness = soil?['data_completeness'] ?? 'tidak diketahui';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 17, color: Color(0xFFE65100)),
              const SizedBox(width: 6),
              Text(
                'Kepastian data terbatas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            missing.isEmpty
                ? 'Kelengkapan data tanah: $completeness. Skor di bawah '
                    'dihitung dari data yang tersedia dan bersifat perkiraan.'
                : 'Parameter tidak tersedia: ${missing.join(', ')}. Nilai '
                    'kosong diasumsikan S2 (cukup sesuai), sehingga skor di '
                    'bawah bersifat perkiraan — bukan pengukuran lengkap.',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8D6E63),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Grid label–nilai dua kolom, mengikuti gaya kartu data pada referensi.
  Widget _buildSoilGrid(Map<String, dynamic> soil) {
    final oc = soil['organic_carbon_pct'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _gridCell('Tekstur', '${soil['texture_label'] ?? '-'}'),
              _gridCell('pH Tanah', '${soil['ph_h2o'] ?? '-'}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _gridCell('Drainase', '${soil['drainage_label'] ?? '-'}'),
              _gridCell(
                'Karbon Organik',
                oc is num ? '${oc.toStringAsFixed(2)}%' : '-',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 12, color: AppTheme.mutedForeground),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Komponen dominan ${soil['share_pct'] ?? '-'}% · '
                  'kelengkapan: ${soil['data_completeness'] ?? 'unknown'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.mutedForeground,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.cardForeground,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(dynamic score) {
    final m = score is Map ? score : const {};
    final cropName = m['crop_name'] ?? '-';
    final overall = m['overall']?.toString();
    final label = m['label'] ?? '-';
    final emoji = m['emoji'] ?? '❓';
    final factors = m['limiting_factors'] as List<dynamic>? ?? [];
    final params = m['parameters'] as List<dynamic>? ?? [];
    final note = (m['note'] ?? '').toString();
    final color = scoreColor(overall);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cropName',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                    Text(
                      '$overall — $label',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  overall ?? '-',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // Faktor pembatas
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: factors
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚠️ $f',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ))
                  .toList(),
            ),
          ],

          // Rincian parameter
          if (params.isNotEmpty)
            Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 2),
                title: Text(
                  'Rincian parameter',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                children: params.map<Widget>((p) {
                  final pm = p is Map ? p : const {};
                  final pColor = scoreColor(pm['suitability']?.toString());
                  final pValue = pm['value'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${pm['parameter'] ?? '-'}'
                                '${pValue == null ? ' (tidak tersedia)' : ': $pValue'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                            ),
                            Text(
                              '${pm['suitability'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: pColor,
                              ),
                            ),
                          ],
                        ),
                        if ((pm['reason'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 1),
                            child: Text(
                              '${pm['reason']}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9E9E9E),
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF8D6E63),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
