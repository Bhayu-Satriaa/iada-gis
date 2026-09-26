import 'package:flutter_riverpod/flutter_riverpod.dart';

// Data yang dikirim dari chat ke map tab
class ChatMapData {
  final Map<String, dynamic>? geoJson;
  final Map<String, dynamic>? hwsdResult;

  ChatMapData({this.geoJson, this.hwsdResult});

  ChatMapData copyWith({
    Map<String, dynamic>? geoJson,
    Map<String, dynamic>? hwsdResult,
  }) {
    return ChatMapData(
      geoJson: geoJson ?? this.geoJson,
      hwsdResult: hwsdResult ?? this.hwsdResult,
    );
  }
}

class ChatMapNotifier extends Notifier<ChatMapData> {
  @override
  ChatMapData build() => ChatMapData();

  void setMapData(Map<String, dynamic> geoJson, Map<String, dynamic>? hwsdResult) {
    state = ChatMapData(geoJson: geoJson, hwsdResult: hwsdResult);
  }

  void clear() {
    state = ChatMapData();
  }
}

final chatMapProvider =
    NotifierProvider<ChatMapNotifier, ChatMapData>(ChatMapNotifier.new);