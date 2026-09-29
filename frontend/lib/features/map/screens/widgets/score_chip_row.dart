import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

/// Warna resmi untuk tiap tingkat kesesuaian lahan (S1/S2/S3/N).
/// Dipakai bersama oleh legend, chip skor, marker, dan kartu detail
/// supaya satu skor selalu tampil dengan warna yang sama di mana pun.
Color scoreColor(String? score) {
  switch (score) {
    case 'S1':
      return AppTheme.s1Color;
    case 'S2':
      return AppTheme.s2Color;
    case 'S3':
      return AppTheme.s3Color;
    case 'N':
      return AppTheme.nColor;
    default:
      return AppTheme.mutedForeground;
  }
}

String scoreLabel(String? score) {
  switch (score) {
    case 'S1':
      return 'Sangat Sesuai';
    case 'S2':
      return 'Cukup Sesuai';
    case 'S3':
      return 'Sesuai Bersyarat';
    case 'N':
      return 'Tidak Sesuai';
    default:
      return '-';
  }
}

String scoreEmoji(String? score) {
  switch (score) {
    case 'S1':
      return '🟢';
    case 'S2':
      return '🟡';
    case 'S3':
      return '🟠';
    case 'N':
      return '🔴';
    default:
      return '⚪';
  }
}

/// Baris ringkas 4 skor komoditas — dipakai di bagian "peek" bottom sheet
/// dan di dalam kartu legend kontekstual.
class ScoreChipRow extends StatelessWidget {
  final List<dynamic> scores;
  final bool compact;

  const ScoreChipRow({
    super.key,
    required this.scores,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();

    return Row(
      children: scores.map<Widget>((s) {
        final m = s is Map ? s : const {};
        return Expanded(child: _chip(m));
      }).toList(),
    );
  }

  Widget _chip(Map<dynamic, dynamic> s) {
    final overall = s['overall']?.toString();
    final color = scoreColor(overall);
    final name = (s['crop_name'] ?? '-').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 5 : 7,
        horizontal: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            scoreEmoji(overall),
            style: TextStyle(fontSize: compact ? 13 : 15),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              color: AppTheme.mutedForeground,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            overall ?? '-',
            style: TextStyle(
              fontSize: compact ? 10 : 11.5,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
