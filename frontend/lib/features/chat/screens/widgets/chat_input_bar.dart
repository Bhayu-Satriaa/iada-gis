import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/chat/providers/chat_providers.dart';
import 'package:frontend/core/services/location_service.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend({double? lat, double? lon}) {
    final isLoading = ref.read(isLoadingProvider);
    if (isLoading) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(
      text,
      lat: lat,
      lon: lon,
    );

    _controller.clear();
    // Reset location setelah kirim
    ref.read(userLocationProvider.notifier).state = null;
  }

  Future<void> _handleGetLocation() async {
    if (_isGettingLocation) return;

    setState(() => _isGettingLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        ref.read(userLocationProvider.notifier).state = {
          'lat': position.latitude,
          'lon': position.longitude,
        };
        _showSnackBar(
          '📍 Lokasi didapat: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          Colors.green,
        );
      } else if (mounted) {
        _showSnackBar('Gagal mendapatkan lokasi. Cek GPS & permission.', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Pilih Lokasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Gunakan Lokasi Saya (GPS)'),
              subtitle: const Text('Ambil posisi saat ini'),
              onTap: () {
                Navigator.pop(context);
                _handleGetLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.orange),
              title: const Text('Ketik Nama Lokasi'),
              subtitle: const Text('Contoh: "Palaran", "Samarinda"'),
              onTap: () {
                Navigator.pop(context);
                _showManualLocationDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showManualLocationDialog() {
    final TextEditingController locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Masukkan Lokasi'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            hintText: 'Contoh: Palaran, Samarinda',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final location = locationController.text.trim();
              if (location.isNotEmpty) {
                // Kirim query dengan lokasi manual
                // Backend akan geocode otomatis
                Navigator.pop(context);
                _controller.text = '${_controller.text} di $location';
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              }
            },
            child: const Text('Pilih'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(isLoadingProvider);
    final userLocation = ref.watch(userLocationProvider);
    final hasLocation = userLocation != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indikator lokasi aktif
            if (hasLocation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${userLocation['lat']!.toStringAsFixed(4)}, ${userLocation['lon']!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        ref.read(userLocationProvider.notifier).state = null;
                      },
                      child: Icon(Icons.close, size: 14, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            // Input bar
            Row(
              children: [
                // Tombol lokasi
                Container(
                  decoration: BoxDecoration(
                    color: _isGettingLocation
                        ? Colors.blue[100]
                        : hasLocation
                            ? Colors.green[100]
                            : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasLocation ? Icons.location_on : Icons.location_off,
                            color: hasLocation ? Colors.green[700] : Colors.grey[600],
                          ),
                    onPressed: isLoading ? null : _showLocationOptions,
                    tooltip: 'Atur Lokasi',
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: hasLocation
                          ? 'Tanya tentang lokasi Anda...'
                          : 'Ketik Pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(
                      lat: userLocation?['lat'],
                      lon: userLocation?['lon'],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol kirim
                Container(
                  decoration: BoxDecoration(
                    color: isLoading ? Colors.grey[400] : Colors.green[600],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: isLoading
                        ? null
                        : () => _handleSend(
                              lat: userLocation?['lat'],
                              lon: userLocation?['lon'],
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
