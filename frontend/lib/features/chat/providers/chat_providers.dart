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

  List<UIMessage> _ganti(int indeks, UIMessage pesan) {
    final salinan = [...state];
    salinan[indeks] = pesan;
    return salinan;
  }

  Future<void> sendMessage(String text, {double? lat, double? lon}) async {
    if (ref.read(isLoadingProvider)) return;

    state = [...state, UIMessage(text: text, isUser: true)];

    ref.read(isLoadingProvider.notifier).state = true;

    final requestPayload = [ChatMessage(role: 'user', content: text)];

    // Gelembung bot dipasang langsung dalam mode streaming supaya pengguna
    // melihat ada aktivitas, lalu isinya bertambah seiring token datang.
    state = [
      ...state,
      UIMessage(text: '', isUser: false, isStreaming: true),
    ];
    final int indeksBot = state.length - 1;

    try {
      final api = ref.read(apiServiceProvider);

      await for (final kejadian in api.streamMessages(
        messages: requestPayload,
        userLat: lat,
        userLon: lon,
      )) {
        final String jenis = kejadian['type'] ?? '';

        if (jenis == 'meta') {
          // Peta + skor sudah siap di server: tampilkan sekarang, jangan
          // tunggu jawaban teks selesai.
          state = _ganti(
            indeksBot,
            state[indeksBot].copyWith(
              botData: ChatResponse(
                answer: '',
                intentType: kejadian['intent_type'] ?? '',
                placesFound: kejadian['places_found'] ?? 0,
                documentsFound: kejadian['documents_found'] ?? 0,
                citations: kejadian['citations'] != null
                    ? List<Map<String, dynamic>>.from(kejadian['citations'])
                    : const [],
                geoJson: kejadian['geo_json'] as Map<String, dynamic>?,
                hwsdResult: kejadian['hwsd_result'] as Map<String, dynamic>?,
                dataSources: kejadian['data_sources'] != null
                    ? List<Map<String, dynamic>>.from(kejadian['data_sources'])
                    : const [],
              ),
            ),
          );
        } else if (jenis == 'token') {
          state = _ganti(
            indeksBot,
            state[indeksBot].copyWith(
              text: state[indeksBot].text + (kejadian['text'] as String? ?? ''),
            ),
          );
        } else if (jenis == 'done') {
          // Jawaban utuh dari server dipakai sebagai sumber kebenaran,
          // supaya tidak ada potongan yang hilang karena masalah jaringan.
          final akhir = kejadian['answer'] as String?;
          state = _ganti(
            indeksBot,
            state[indeksBot].copyWith(
              text: (akhir != null && akhir.isNotEmpty)
                  ? akhir
                  : state[indeksBot].text,
              isStreaming: false,
            ),
          );
        } else if (jenis == 'error') {
          state = _ganti(
            indeksBot,
            state[indeksBot].copyWith(
              text: 'Maaf, terjadi kesalahan: ${kejadian['message']}',
              isStreaming: false,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Chat error: $e');
      }
      state = _ganti(
        indeksBot,
        state[indeksBot].copyWith(
          text: 'Maaf, terjadi kesalahan koneksi',
          isStreaming: false,
        ),
      );
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
      // Jaring pengaman: kalau aliran terputus tanpa kejadian 'done',
      // indikator "menyusun jawaban…" tidak boleh tertinggal selamanya.
      if (state[indeksBot].isStreaming) {
        state = _ganti(
          indeksBot,
          state[indeksBot].copyWith(isStreaming: false),
        );
      }
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<UIMessage>>(
  ChatNotifier.new
);