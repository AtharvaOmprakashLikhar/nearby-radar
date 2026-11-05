import 'package:flutter/services.dart';

typedef WifiProgressCallback = void Function(String transferId, int bytesTransferred, int totalBytes, int speedBps);
typedef WifiCompleteCallback = void Function(String transferId, String filePath);
typedef WifiErrorCallback = void Function(String transferId, String error);
typedef WifiConnectionCallback = void Function(bool connected, bool isGroupOwner, String? groupOwnerAddress);

class WifiDirectEngine {
  static const MethodChannel _channel = MethodChannel('com.nearby.radar/wifi_direct');

  static WifiProgressCallback? onTransferProgress;
  static WifiCompleteCallback? onTransferCompleted;
  static WifiErrorCallback? onTransferFailed;
  static WifiConnectionCallback? onConnectionChanged;

  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectionChanged':
          final connected = call.arguments['connected'] as bool? ?? false;
          final isGroupOwner = call.arguments['isGroupOwner'] as bool? ?? false;
          final address = call.arguments['groupOwnerAddress'] as String?;
          onConnectionChanged?.call(connected, isGroupOwner, address);
          break;
        case 'onTransferProgress':
          final transferId = call.arguments['transferId'] as String;
          final transferred = call.arguments['bytesTransferred'] as int? ?? 0;
          final total = call.arguments['totalBytes'] as int? ?? 0;
          final speed = call.arguments['speedBps'] as int? ?? 0;
          onTransferProgress?.call(transferId, transferred, total, speed);
          break;
        case 'onTransferCompleted':
          final transferId = call.arguments['transferId'] as String;
          final filePath = call.arguments['filePath'] as String;
          onTransferCompleted?.call(transferId, filePath);
          break;
        case 'onTransferFailed':
          final transferId = call.arguments['transferId'] as String;
          final error = call.arguments['error'] as String;
          onTransferFailed?.call(transferId, error);
          break;
      }
    });
  }

  static Future<bool> createGroup() async {
    try {
      final res = await _channel.invokeMethod<bool>('createGroup');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeGroup() async {
    try {
      final res = await _channel.invokeMethod<bool>('removeGroup');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> connectToPeer(String deviceAddress) async {
    try {
      final res = await _channel.invokeMethod<bool>('connect', {'deviceAddress': deviceAddress});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startServer({required int port, required String destDirectory, required String transferId}) async {
    try {
      final res = await _channel.invokeMethod<bool>('startServer', {
        'port': port,
        'destDirectory': destDirectory,
        'transferId': transferId,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> sendFile({
    required String host,
    required int port,
    required String filePath,
    required String transferId,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('sendFile', {
        'host': host,
        'port': port,
        'filePath': filePath,
        'transferId': transferId,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}
