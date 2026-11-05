import 'dart:async';
import 'package:flutter/services.dart';

typedef ConnectionRequestCallback = void Function(String deviceAddress, Uint8List payload);
typedef MessageChunkCallback = void Function(String deviceAddress, Uint8List payload);
typedef TransferNegotiationCallback = void Function(String deviceAddress, Uint8List payload);

class BleNativeBridge {
  static const MethodChannel _advertiserChannel = MethodChannel('com.nearby.radar/ble_advertiser');
  static const MethodChannel _gattChannel = MethodChannel('com.nearby.radar/ble_gatt_server');
  static const MethodChannel _foregroundChannel = MethodChannel('com.nearby.radar/foreground_service');

  static ConnectionRequestCallback? onConnectionRequestReceived;
  static MessageChunkCallback? onMessageChunkReceived;
  static TransferNegotiationCallback? onTransferNegotiationReceived;

  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _gattChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectionRequest':
          final address = call.arguments['deviceAddress'] as String;
          final payload = call.arguments['payload'] as Uint8List;
          onConnectionRequestReceived?.call(address, payload);
          break;
        case 'onMessageChunk':
          final address = call.arguments['deviceAddress'] as String;
          final payload = call.arguments['payload'] as Uint8List;
          onMessageChunkReceived?.call(address, payload);
          break;
        case 'onTransferNegotiation':
          final address = call.arguments['deviceAddress'] as String;
          final payload = call.arguments['payload'] as Uint8List;
          onTransferNegotiationReceived?.call(address, payload);
          break;
      }
    });
  }

  // Foreground Service
  static Future<bool> startForegroundService() async {
    try {
      final res = await _foregroundChannel.invokeMethod<bool>('startService');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopForegroundService() async {
    try {
      final res = await _foregroundChannel.invokeMethod<bool>('stopService');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  // BLE Advertiser
  static Future<bool> startAdvertising({required Uint8List userIdHash, required int status}) async {
    try {
      final res = await _advertiserChannel.invokeMethod<bool>('startAdvertising', {
        'userIdHash': userIdHash,
        'status': status,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopAdvertising() async {
    try {
      final res = await _advertiserChannel.invokeMethod<bool>('stopAdvertising');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  // BLE GATT Server
  static Future<bool> startGattServer() async {
    try {
      final res = await _gattChannel.invokeMethod<bool>('startServer');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopGattServer() async {
    try {
      final res = await _gattChannel.invokeMethod<bool>('stopServer');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setProfilePayload(Uint8List payload) async {
    try {
      await _gattChannel.invokeMethod('setProfilePayload', {'payload': payload});
    } catch (e) {}
  }

  static Future<void> notifyClient({
    required String deviceAddress,
    required String characteristicUuid,
    required Uint8List payload,
  }) async {
    try {
      await _gattChannel.invokeMethod('notifyClient', {
        'deviceAddress': deviceAddress,
        'characteristicUuid': characteristicUuid,
        'payload': payload,
      });
    } catch (e) {}
  }
}
