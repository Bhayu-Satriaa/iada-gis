import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider untuk current tab index (0=Chat, 1=Peta)
final currentTabProvider = StateProvider<int>((ref) => 0);