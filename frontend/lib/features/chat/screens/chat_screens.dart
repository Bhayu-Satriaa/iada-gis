import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/features/chat/providers/chat_providers.dart';
import 'package:frontend/features/chat/screens/widgets/chat_bubble.dart';
import 'package:frontend/features/chat/screens/widgets/chat_input_bar.dart';
import 'package:frontend/shared/widgets/loading_indicator.dart';
import 'package:frontend/app/theme.dart';

class ChatScreens extends ConsumerStatefulWidget {
  const ChatScreens({super.key});

  @override
  ConsumerState<ChatScreens> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreens> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final isLoading = ref.watch(isLoadingProvider);

    ref.listen(chatProvider, (previous, next) {
      if (next.length > (previous?.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IADA-GIS'),
                Text(
                  'Asisten Pertanian Kaltim',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: messages[index]);
                    },
                  ),
          ),
          if (isLoading) const LoadingIndicator(),
          const ChatInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.eco_outlined,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Selamat Datang!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tanya apa saja tentang pertanian\ndi Kalimantan Timur',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Quick actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _quickActionChip(Icons.location_on, 'Cek Tanah di Saya'),
                _quickActionChip(Icons.search, 'Cari Lahan'),
                _quickActionChip(Icons.eco, 'Kesesuaian Tanaman'),
                _quickActionChip(Icons.info_outline, 'Info Dokumen'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionChip(IconData icon, String label) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.primary),
      label: Text(label),
      backgroundColor: AppTheme.card,
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onPressed: () {
        // TODO: Auto-fill query
      },
    );
  }
}
