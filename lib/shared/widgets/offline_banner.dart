// lib/shared/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/theme/app_theme.dart';

/// Displays a persistent banner when the device is offline.
/// Wrap your main scaffold body with this widget.
class OfflineBanner extends ConsumerWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    final isOffline = connectivity.when(
      data: (s) => s == NetworkStatus.offline,
      loading: () => false,
      error: (_, __) => false,
    );

    return Column(
      children: [
        if (isOffline)
          Material(
            color: const Color(0xFF1A1A2E),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No internet connection — showing cached data',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ).animate().slideY(begin: -1, end: 0, duration: 300.ms),
        Expanded(child: child),
      ],
    );
  }
}
