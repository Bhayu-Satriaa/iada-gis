import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class ScoringDetailSheet extends StatelessWidget {
  final Map<String, dynamic> scoringData;

  const ScoringDetailSheet({super.key, required this.scoringData});

  @override
  Widget build(BuildContext context) {
    final soil = scoringData['soil_info'] as Map<String, dynamic>?;
    final scores = scoringData['scores'] as List<dynamic>? ?? [];
    final summary = scoringData['summary'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.landscape, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analisis Kesesuaian Lahan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                        if (soil != null)
                          Text(
                            'SMU ${soil['smu_id']} • ${soil['texture_label'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Soil info card
              if (soil != null) _buildSoilInfoCard(soil),
              const SizedBox(height: 16),

              // Scores
              Text(
                'Kesesuaian Komoditas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              ...scores.map((score) => _buildScoreCard(score)),

              // Summary
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
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
          );
        },
      ),
    );
  }

  Widget _buildSoilInfoCard(Map<String, dynamic> soil) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _soilRow('Tekstur Tanah', '${soil['texture_label'] ?? '-'}',
              Icons.texture),
          _soilRow('pH Tanah', '${soil['ph_h2o'] ?? '-'}', Icons.science),
          _soilRow('Drainase', '${soil['drainage_label'] ?? '-'}',
              Icons.water_drop),
          _soilRow(
              'Karbon Organik',
              '${(soil['organic_carbon_pct'] as num?)?.toStringAsFixed(2) ?? '-'}%',
              Icons.eco),
        ],
      ),
    );
  }

  Widget _soilRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(dynamic score) {
    final cropName = score['crop_name'] ?? '-';
    final overall = score['overall'] ?? '-';
    final label = score['label'] ?? '-';
    final emoji = score['emoji'] ?? '❓';
    final factors = score['limiting_factors'] as List<dynamic>? ?? [];
    final params = score['parameters'] as List<dynamic>? ?? [];

    final color = _scoreColor(overall);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cropName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                    Text(
                      '$overall — $label',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  overall,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: factors
                  .map((f) => Chip(
                        label: Text('⚠️ $f',
                            style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
          // Detail parameters (expandable)
          if (params.isNotEmpty)
            Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                title: Text(
                  'Detail Parameter',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                children: params.map<Widget>((p) {
                  final pColor = _scoreColor(p['suitability'] ?? '-');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p['parameter'] ?? '-'}',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.mutedForeground),
                          ),
                        ),
                        Text(
                          '${p['suitability'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
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
