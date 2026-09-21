import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
// import 'package:frontend/features/map/providers/map_provider.dart';

final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Simpan lokasi user saat ini (lat, lon)
/// null = belum ada lokasi
final userLocationProvider = StateProvider<Map<String, double>?>((ref) => null);

class ChatNotifier extends Notifier<List<UIMessage>> {

  @override
  List<UIMessage> build() => [];

  Future<void> sendMessage(String text, {double? lat, double? lon}) async {
    if (ref.read(isLoadingProvider)) return;

    state = [...state, UIMessage(text: text, isUser: true)];

    ref.read(isLoadingProvider.notifier).state = true;

    final requestPayload = [ChatMessage(role: 'user', content: text)];

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.sendMessages(
        messages: requestPayload,
        userLat: lat,
        userLon: lon
      );

      state = [
        ...state,
        UIMessage(
          text: response.answer, 
          isUser: false,
          botData: response,
        )
      ];
      
      // ref.read(mapProvider.notifier).updateGeoJson(response.geoJson);

    } catch (e) {
      if (kDebugMode) {
        print('Chat error: $e');
      }
      state = [
        ...state,
        UIMessage(text: 'Maaf, terjadi kesalahan koneksi', isUser: false)
      ];
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<UIMessage>>(
  ChatNotifier.new
);