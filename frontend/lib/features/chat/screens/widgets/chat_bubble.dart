import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/features/chat/screens/widgets/citations_chip.dart';
import 'package:frontend/features/chat/screens/widgets/hwsd_card.dart';
import 'package:frontend/features/chat/screens/widgets/chat_map_preview.dart';
import 'package:frontend/app/tab_provider.dart';
import 'package:frontend/app/chat_map_provider.dart';
import 'package:frontend/app/theme.dart';

class ChatBubble extends ConsumerWidget {
  final UIMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final botData = message.botData;
    final hasSpatialData = !isUser && botData?.geoJson != null;
    final hasCitations = !isUser && (botData?.citations.isNotEmpty ?? false);
    final hasHwsdData = !isUser && botData?.hwsdResult != null;
    final hasDataSources =
        !isUser && (botData?.dataSources.isNotEmpty ?? false);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 12,
          right: isUser ? 12 : 48,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.card,
          border: isUser
              ? null
              : Border.all(color: AppTheme.border, width: 1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spatial badge
            if (hasSpatialData) _buildSpatialBadge(context),

            // HWSD badge
            if (hasHwsdData) _buildHwsdBadge(context),

            // Message text
            Padding(
              padding: EdgeInsets.fromLTRB(
                14.0,
                (hasSpatialData || hasHwsdData) ? 8.0 : 12.0,
                14.0,
                hasCitations ? 6.0 : 12.0,
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: TextStyle(
                        height: 1.5,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    )
                  : (message.isStreaming && message.text.isEmpty)
                      ? const _MenyusunJawaban()
                      : MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          height: 1.5,
                          fontSize: 14,
                          color: AppTheme.cardForeground,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cardForeground,
                        ),
                        em: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.cardForeground,
                        ),
                        listBullet: TextStyle(
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
            ),

            // Mini Map Preview (jika ada geo_json)
            if (hasSpatialData && botData!.geoJson != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ChatMapPreview(
                  geoJson: botData.geoJson!,
                  hwsdResult: botData.hwsdResult,
                  onTap: () {
                    // TODO: Navigate to full map screen with this data
                  },
                ),
              ),

            // Citations
            if (hasCitations)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: botData!.citations
                      .map((c) => CitationsChip(citation: c))
                      .toList(),
                ),
              ),

            // HWSD Card
            if (hasHwsdData)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: HwsdCard(hwsdResult: botData!.hwsdResult!),
              ),

            // Sumber data — transparansi asal-usul data
            if (hasDataSources)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _buildDataSources(context, botData!.dataSources),
              ),

            // Action buttons (lihat peta)
            if (hasSpatialData) _buildActionButtons(context, ref, botData),
          ],
        ),
      ),
    );
  }

  Widget _buildSpatialBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.map_rounded, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Spasial Ditemukan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  'Lihat di tab Peta untuk detail',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildHwsdBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.eco_rounded, size: 16, color: AppTheme.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analisis Kesesuaian Lahan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
                Text(
                  'Hasil scoring HWSD tersedia',
                  style: TextStyle(
                    fontSize: 11,
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

  /// Blok "Sumber Data" — menunjukkan dari mana data jawaban berasal.
  ///
  /// Ditampilkan agar pengguna bisa menilai sendiri seberapa layak data itu
  /// dipercaya. Hanya sumber yang benar-benar dipakai yang muncul.
  Widget _buildDataSources(
    BuildContext context,
    List<Map<String, dynamic>> sumber,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.source_outlined,
                size: 14,
                color: AppTheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                'SUMBER DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in sumber)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _ikonSumber(s['jenis']),
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['label'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.cardForeground,
                          ),
                        ),
                        if ((s['detail'] ?? '').toString().isNotEmpty)
                          Text(
                            '${s['detail']}',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _ikonSumber(dynamic jenis) {
    switch (jenis) {
      case 'tanah':
        return Icons.terrain_outlined;
      case 'kawasan':
        return Icons.map_outlined;
      case 'dokumen':
        return Icons.description_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, ChatResponse? botData) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Simpan data polygon + scoring ke provider
                if (botData?.geoJson != null) {
                  ref.read(chatMapProvider.notifier).setMapData(
                    botData!.geoJson!,
                    botData.hwsdResult,
                  );
                }
                // Navigate ke tab peta (index 1)
                ref.read(currentTabProvider.notifier).state = 1;
              },
              icon: Icon(Icons.map, size: 16, color: AppTheme.primary),
              label: Text(
                'Lihat Peta',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indikator sementara saat jawaban masih mengalir dari server.
/// Tanpa ini gelembung bot tampak kosong selama beberapa detik pertama.
class _MenyusunJawaban extends StatelessWidget {
  const _MenyusunJawaban();

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 10),
        Text(
          'Menyusun jawaban…',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppTheme.cardForeground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
