import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();

  factory NetworkConnectivityService() {
    return _instance;
  }

  NetworkConnectivityService._internal();

  final _connectionStatusController = StreamController<bool>.broadcast();
  bool _isConnected = true;

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Initial check
    await _checkConnectivity();

    // Periodic check every 5 seconds
    Timer.periodic(Duration(seconds: 5), (_) async {
      await _checkConnectivity();
    });
  }

  /// Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (connected != _isConnected) {
        _isConnected = connected;
        _connectionStatusController.add(connected);
        debugPrint(
          '🌐 [Network] Connection status changed: $_isConnected',
        );
      }
    } on SocketException catch (_) {
      if (_isConnected != false) {
        _isConnected = false;
        _connectionStatusController.add(false);
        debugPrint('🌐 [Network] No internet connection detected');
      }
    } catch (e) {
      debugPrint('🌐 [Network] Error checking connectivity: $e');
    }
  }

  /// Manual connectivity check
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      debugPrint('🌐 [Network] Error in manual check: $e');
      return false;
    }
  }

  /// Cleanup
  void dispose() {
    _connectionStatusController.close();
  }
}
