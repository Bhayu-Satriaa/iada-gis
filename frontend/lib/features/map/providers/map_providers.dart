import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';

// State untuk layers/spatial data
class LayersState {
  final List<Map<String, dynamic>> layers;
  final bool isLoading;
  final String? error;

  LayersState({this.layers = const [], this.isLoading = false, this.error});

  LayersState copyWith({
    List<Map<String, dynamic>>? layers,
    bool? isLoading,
    String? error,
  }) {
    return LayersState(
      layers: layers ?? this.layers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LayersNotifier extends Notifier<LayersState> {
  @override
  LayersState build() => LayersState();

  Future<void> fetchLayers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getLayers();
      state = LayersState(layers: response, isLoading: false);
    } catch (e) {
      state = LayersState(
        isLoading: false,
        error: 'Gagal memuat data layers: $e',
      );
    }
  }
}

final layersProvider =
    NotifierProvider<LayersNotifier, LayersState>(LayersNotifier.new);

// State untuk HWSD scoring
class ScoringState {
  final Map<String, dynamic>? result;
  final bool isLoading;
  final String? error;
  final double? lat;
  final double? lon;

  ScoringState({
    this.result,
    this.isLoading = false,
    this.error,
    this.lat,
    this.lon,
  });

  ScoringState copyWith({
    Map<String, dynamic>? result,
    bool? isLoading,
    String? error,
    double? lat,
    double? lon,
  }) {
    return ScoringState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}

class ScoringNotifier extends Notifier<ScoringState> {
  @override
  ScoringState build() => ScoringState();

  Future<void> fetchScoring(double lat, double lon) async {
    state = ScoringState(isLoading: true, lat: lat, lon: lon);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getLandSuitability(lat, lon);
      state = ScoringState(
        result: result,
        isLoading: false,
        lat: lat,
        lon: lon,
      );
    } catch (e) {
      state = ScoringState(
        isLoading: false,
        error: 'Gagal memuat scoring: $e',
        lat: lat,
        lon: lon,
      );
    }
  }

  void clear() {
    state = ScoringState();
  }
}

final scoringProvider =
    NotifierProvider<ScoringNotifier, ScoringState>(ScoringNotifier.new);

// Semua scoring markers yang sudah di-fetch
class ScoringMarkersNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void addMarker(Map<String, dynamic> marker) {
    state = [...state, marker];
  }

  void clear() {
    state = [];
  }
}

final scoringMarkersProvider = NotifierProvider<ScoringMarkersNotifier,
    List<Map<String, dynamic>>>(ScoringMarkersNotifier.new);
