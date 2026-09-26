import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Ambil posisi user saat ini
  /// Return null jika gagal (permission ditolak, service mati, timeout)
  static Future<Position?> getCurrentLocation() async {
    try {
      // 1. Cek apakah location service aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Minta user aktifkan GPS
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      // 2. Cek & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // User permanent deny → buka app settings
        await Geolocator.openAppSettings();
        return null;
      }

      // 3. Ambil posisi (timeout 10 detik)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('Timeout: Lokasi tidak dapat diambil dalam 12 detik');
        },
      );

      return position;
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }

  /// Cek apakah permission sudah diberikan
  static Future<bool> hasPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// Cek apakah location service aktif
  static Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
