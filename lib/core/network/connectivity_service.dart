// lib/core/network/connectivity_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Monitors network connectivity and exposes a stream + current state.
// Used to show offline banners and prevent failed API calls.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, unknown }

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _statusController = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _current = NetworkStatus.unknown;

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus get status => _current;
  bool get isOnline => _current == NetworkStatus.online;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) {
      final status = _mapResults(results);
      if (status != _current) {
        _current = status;
        _statusController.add(_current);
      }
    });

    // Check initial status
    _connectivity.checkConnectivity().then((results) {
      _current = _mapResults(results);
      _statusController.add(_current);
    });
  }

  NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  void dispose() => _statusController.close();
}

// ── Riverpod Provider ────────────────────────────────────────────────────────
final connectivityProvider = StreamProvider<NetworkStatus>((ref) {
  ConnectivityService.instance.initialize();
  return ConnectivityService.instance.statusStream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider);
  return status.when(
    data: (s) => s == NetworkStatus.online,
    loading: () => true,
    error: (_, __) => true,
  );
});
