class ChatResponse {
  final String answer;
  final String intentType;
  final int placesFound;
  final int documentsFound;
  final List<Map<String, dynamic>> citations;
  final Map<String, dynamic>? geoJson;
  final Map<String, dynamic>? hwsdResult; // data kesesuaian lahan HWSD

  /// Asal-usul data yang dipakai untuk menjawab (untuk transparansi).
  /// Tiap entri: {jenis, label, detail}.
  final List<Map<String, dynamic>> dataSources;

  ChatResponse({
    required this.answer,
    required this.intentType,
    required this.placesFound,
    required this.documentsFound,
    this.citations = const [],
    this.geoJson,
    this.hwsdResult,
    this.dataSources = const [],
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] ?? '',
      intentType: json['intent_type'] ?? '',
      placesFound: json['places_found'] ?? 0,
      documentsFound: json['documents_found'] ?? 0,
      citations: json['citations'] != null
          ? List<Map<String, dynamic>>.from(json['citations'])
          : [],
      geoJson: json['geo_json'] as Map<String, dynamic>?,
      hwsdResult: json['hwsd_result'] as Map<String, dynamic>?,
      dataSources: json['data_sources'] != null
          ? List<Map<String, dynamic>>.from(json['data_sources'])
          : const [],
    );
  }
}


class ChatMessage{
  final String role;
  final String content;

  ChatMessage({
    required this.role,
    required this.content
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content
  };
}

class UIMessage{
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatResponse? botData;

  /// True selama jawaban masih mengalir masuk, dipakai untuk menampilkan
  /// indikator "menyusun jawaban…" di gelembung chat.
  final bool isStreaming;

  UIMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.botData,
    this.isStreaming = false,
  }): timestamp =  timestamp ?? DateTime.now();

  UIMessage copyWith({String? text, ChatResponse? botData, bool? isStreaming}) {
    return UIMessage(
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      botData: botData ?? this.botData,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
