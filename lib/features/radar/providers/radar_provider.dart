import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ble/nearby_ble_constants.dart';
import '../../../core/db/database_service.dart';
import '../../profile/models/user_profile.dart';
import '../models/radar_peer.dart';

class RadarState {
  final Map<String, RadarPeer> peers;
  final bool isScanning;
  final String? errorMessage;

  const RadarState({
    this.peers = const {},
    this.isScanning = false,
    this.errorMessage,
  });

  RadarState copyWith({
    Map<String, RadarPeer>? peers,
    bool? isScanning,
    String? errorMessage,
  }) {
    return RadarState(
      peers: peers ?? this.peers,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
    );
  }

  List<RadarPeer> get activePeers =>
      peers.values.where((p) => p.decayOpacity > 0.0).toList();
}

class RadarNotifier extends StateNotifier<RadarState> {
  StreamSubscription? _scanSub;
  Timer? _decayTimer;

  RadarNotifier() : super(const RadarState()) {
    _initScanner();
  }

  void _initScanner() {
    // Listen for scan results
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _processScanResults(results);
    });

    // 1-second decay and purge timer
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _purgeExpiredPeers();
    });
  }

  void _processScanResults(List<ScanResult> results) {
    final currentPeers = Map<String, RadarPeer>.from(state.peers);
    bool changed = false;

    for (final r in results) {
      final deviceId = r.device.remoteId.str;

      // Extract service data for Nearby Radar UUID
      final targetGuid = Guid(NearbyBleConstants.serviceUuid);
      final serviceData = r.advertisementData.serviceData[targetGuid];

      Uint8List userIdHash;
      UserStatus status = UserStatus.available;

      if (serviceData != null && serviceData.isNotEmpty) {
        userIdHash = Uint8List.fromList(serviceData.sublist(0, serviceData.length.clamp(0, 4)));
        if (serviceData.length >= 5) {
          status = UserStatus.values[serviceData[4].clamp(0, 2)];
        }
      } else {
        // Fallback hash from device remote ID
        userIdHash = Uint8List.fromList(deviceId.codeUnits.sublist(0, 4));
      }

      // Ignore invisible peers
      if (status == UserStatus.invisible) continue;

      final existing = currentPeers[deviceId];
      final previousSmoothed = existing?.smoothedRssi ?? r.rssi.toDouble();
      final newSmoothed = RadarPeer.smoothRssi(previousSmoothed, r.rssi);
      final distance = RadarPeer.calculateDistance(newSmoothed);

      final stableAngle = existing?.stableAngle ?? RadarPeer.computeStableAngle(deviceId, userIdHash);

      currentPeers[deviceId] = (existing ?? RadarPeer(
        deviceId: deviceId,
        userIdHash: userIdHash,
        status: status,
        rawRssi: r.rssi,
        smoothedRssi: newSmoothed,
        estimatedDistanceMeters: distance,
        stableAngle: stableAngle,
        lastSeen: DateTime.now(),
      )).copyWith(
        rawRssi: r.rssi,
        smoothedRssi: newSmoothed,
        estimatedDistanceMeters: distance,
        lastSeen: DateTime.now(),
      );

      changed = true;
    }

    if (changed) {
      state = state.copyWith(peers: currentPeers);
    }
  }

  void _purgeExpiredPeers() {
    final now = DateTime.now();
    final updated = Map<String, RadarPeer>.from(state.peers);
    bool changed = false;

    updated.removeWhere((key, peer) {
      final diff = now.difference(peer.lastSeen).inSeconds;
      if (diff >= 16) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      state = state.copyWith(peers: updated);
    }
  }

  Future<void> startScan() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        state = state.copyWith(errorMessage: "Bluetooth LE is not supported on this device.");
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        state = state.copyWith(errorMessage: "Please turn on Bluetooth to scan nearby peers.");
        return;
      }

      await FlutterBluePlus.startScan(
        withServices: [Guid(NearbyBleConstants.serviceUuid)],
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.balanced,
      );

      state = state.copyWith(isScanning: true, errorMessage: null);
    } catch (e) {
      state = state.copyWith(errorMessage: "Scan failed: $e", isScanning: false);
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      state = state.copyWith(isScanning: false);
    } catch (e) {}
  }

  /// Fetches full user profile from the peer's GATT server on demand
  Future<UserProfile?> fetchProfileOverGatt(String deviceId) async {
    final peer = state.peers[deviceId];
    if (peer?.fullProfile != null) return peer!.fullProfile;

    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(timeout: const Duration(seconds: 4));

      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid == Guid(NearbyBleConstants.serviceUuid),
      );
      final profileChar = targetService.characteristics.firstWhere(
        (c) => c.uuid == Guid(NearbyBleConstants.profileCharUuid),
      );

      final bytes = await profileChar.read();
      await device.disconnect();

      if (bytes.isNotEmpty) {
        final profile = UserProfile.fromGattPayload(Uint8List.fromList(bytes));
        if (profile != null) {
          final updated = Map<String, RadarPeer>.from(state.peers);
          if (updated.containsKey(deviceId)) {
            updated[deviceId] = updated[deviceId]!.copyWith(fullProfile: profile);
            state = state.copyWith(peers: updated);
          }
          return profile;
        }
      }
    } catch (e) {
      // Disconnect safely on failure
      try {
        await BluetoothDevice.fromId(deviceId).disconnect();
      } catch (_) {}
    }
    return null;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _decayTimer?.cancel();
    super.dispose();
  }
}

final radarProvider = StateNotifierProvider<RadarNotifier, RadarState>((ref) {
  return RadarNotifier();
});
