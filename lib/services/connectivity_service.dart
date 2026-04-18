import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();
  static bool _isOnline = true;
  static StreamSubscription? _sub;

  static bool get isOnline => _isOnline;

  static Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((result) {
        _isOnline = result.any((r) => r != ConnectivityResult.none);
        return _isOnline;
      });

  static Future<bool> checkOnline() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result.any((r) => r != ConnectivityResult.none);
    return _isOnline;
  }

  /// Start listening and auto-updating _isOnline
  static void startListening() {
    _sub?.cancel();
    _sub = onlineStream.listen((_) {});
  }

  static void stopListening() {
    _sub?.cancel();
    _sub = null;
  }
}
