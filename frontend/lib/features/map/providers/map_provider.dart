import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapNotifier extends Notifier<Map<String, dynamic>?> {
    @override
    Map<String, dynamic>? build() => null;

    void updateGeoJson(Map<String, dynamic>? newData) {
        state = newData;
    }
}

final mapProvider = NotifierProvider<MapNotifier, Map<String, dynamic>?>(
    MapNotifier.new,
);
