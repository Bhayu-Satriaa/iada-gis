import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    final url = ApiConstants.baseUrl;
    if (kDebugMode) print('API_BASE_URL: $url');
    _dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
            requestBody: true,
            responseBody: true,
      ));
    }
  }

  /// Chat endpoint
  Future<ChatResponse> sendMessages({
    required List<ChatMessage> messages,
    double? userLat,
    double? userLon,
  }) async {
    final Map<String, dynamic> payload = {
      'messages': messages.map((msg) => msg.toJson()).toList(),
      if (userLat != null) 'user_lat': userLat,
      if (userLon != null) 'user_lon': userLon,
    };

    try {
      final response = await _dio.post(
        ApiConstants.chatEndpoint,
        data: payload,
      );
      return ChatResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Gagal menghubungi server: ${e.message}');
    }
  }

  /// Fetch all spatial layers
  Future<List<Map<String, dynamic>>> getLayers() async {
    try {
      final response = await _dio.get(ApiConstants.layersEndpoint);
      final data = response.data;
      if (data is Map && data.containsKey('layers')) {
        final layers = data['layers'];
        if (layers is List) {
          return layers.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Gagal memuat layers: ${e.message}');
    }
  }

  /// Fetch all layers with GeoJSON geometry
  Future<List<Map<String, dynamic>>> getLayersGeojson({String? layerType, int limit = 200}) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (layerType != null) queryParams['layer_type'] = layerType;
      final response = await _dio.get('${ApiConstants.layersEndpoint}/geojson', queryParameters: queryParams);
      final data = response.data;
      if (data is Map && data.containsKey('features')) {
        final features = data['features'];
        if (features is List) {
          return features.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Gagal memuat geojson: ${e.message}');
    }
  }

  /// Fetch land suitability scoring
  Future<Map<String, dynamic>> getLandSuitability(
      double lat, double lon) async {
    try {
      final response = await _dio.post(
        ApiConstants.landSuitabilityEndpoint,
        data: {'latitude': lat, 'longitude': lon},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Gagal memuat scoring: ${e.message}');
    }
  }

  /// Fetch soil info only (lighter)
  Future<Map<String, dynamic>> getSoilInfo(double lat, double lon) async {
    try {
      final response = await _dio.get(
        ApiConstants.soilInfoEndpoint,
        queryParameters: {'lat': lat, 'lon': lon},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Gagal memuat info tanah: ${e.message}');
    }
  }
}
