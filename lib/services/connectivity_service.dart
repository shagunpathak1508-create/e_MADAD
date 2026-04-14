import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();
  static bool _isOnline = true;

  static bool get isOnline => _isOnline;

  static Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((result) => result.any((r) => r != ConnectivityResult.none));

  static Future<bool> checkOnline() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result.any((r) => r != ConnectivityResult.none);
    return _isOnline;
  }
}
