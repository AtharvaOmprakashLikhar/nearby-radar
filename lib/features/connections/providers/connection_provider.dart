import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ble/ble_native_bridge.dart';
import '../../../core/ble/nearby_ble_constants.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/db/database_service.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../radar/models/radar_peer.dart';
import '../models/connection_payload.dart';

class IncomingRequestInfo {
  final String deviceAddress;
  final ConnectionRequestPayload payload;

  const IncomingRequestInfo({required this.deviceAddress, required this.payload});
}

class ConnectionStateModel {
  final IncomingRequestInfo? pendingIncomingRequest;
  final String? activePeerId;
  final String? activeSafetyCode;
  final bool isConnecting;
  final Map<String, Uint8List> sessionKeys; // peerId -> sessionKey

  const ConnectionStateModel({
    this.pendingIncomingRequest,
    this.activePeerId,
    this.activeSafetyCode,
    this.isConnecting = false,
    this.sessionKeys = const {},
  });

  ConnectionStateModel copyWith({
    IncomingRequestInfo? pendingIncomingRequest,
    bool clearPending = false,
    String? activePeerId,
    String? activeSafetyCode,
    bool? isConnecting,
    Map<String, Uint8List>? sessionKeys,
  }) {
    return ConnectionStateModel(
      pendingIncomingRequest: clearPending ? null : (pendingIncomingRequest ?? this.pendingIncomingRequest),
      activePeerId: activePeerId ?? this.activePeerId,
      activeSafetyCode: activeSafetyCode ?? this.activeSafetyCode,
      isConnecting: isConnecting ?? this.isConnecting,
      sessionKeys: sessionKeys ?? this.sessionKeys,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionStateModel> {
  final Ref ref;

  ConnectionNotifier(this.ref) : super(const ConnectionStateModel()) {
    _initBridgeListeners();
  }

  void _initBridgeListeners() {
    BleNativeBridge.initialize();

    BleNativeBridge.onConnectionRequestReceived = (deviceAddress, payloadBytes) {
      final req = ConnectionRequestPayload.fromBytes(payloadBytes);
      if (req != null) {
        // Check if contact is blocked
        final contact = ref.read(databaseServiceProvider).getContact(req.senderProfile.id);
        if (contact?.isBlocked == true) return;

        state = state.copyWith(
          pendingIncomingRequest: IncomingRequestInfo(
            deviceAddress: deviceAddress,
            payload: req,
          ),
        );
      }
    };
  }

  /// Sends a connection request to a nearby peer over GATT
  Future<bool> sendConnectionRequest(RadarPeer peer) async {
    state = state.copyWith(isConnecting: true);
    try {
      final myProfile = ref.read(profileProvider).value;
      if (myProfile == null) return false;

      final myIdentity = await CryptoService.getOrCreateIdentity();

      final device = BluetoothDevice.fromId(peer.deviceId);
      await device.connect(timeout: const Duration(seconds: 5));

      // Request larger MTU
      try {
        await device.requestMtu(NearbyBleConstants.targetMtu);
      } catch (_) {}

      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid == Guid(NearbyBleConstants.serviceUuid),
      );
      final connChar = targetService.characteristics.firstWhere(
        (c) => c.uuid == Guid(NearbyBleConstants.connRequestCharUuid),
      );

      final requestPayload = ConnectionRequestPayload(
        senderProfile: myProfile,
        senderPublicKey: myIdentity.publicKeyHex,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await connChar.write(requestPayload.toBytes());

      // Save peer as contact on initiate/accept
      final safetyCode = CryptoService.computeSafetyCode(myIdentity.publicKeyHex, peer.userIdHash.toString());
      final contact = ContactModel(
        id: peer.deviceId,
        displayName: peer.fullProfile?.displayName ?? "Peer ${peer.deviceId.substring(peer.deviceId.length - 4)}",
        avatarBytes: peer.fullProfile?.avatarBytes,
        bio: peer.fullProfile?.bio ?? '',
        status: peer.status,
        publicKey: peer.userIdHash.toString(),
        safetyCode: safetyCode,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      ref.read(databaseServiceProvider).saveContact(contact);

      state = state.copyWith(
        isConnecting: false,
        activePeerId: peer.deviceId,
        activeSafetyCode: safetyCode,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isConnecting: false);
      return false;
    }
  }

  /// Accepts an incoming connection request and completes the key exchange
  Future<void> acceptIncomingRequest() async {
    final incoming = state.pendingIncomingRequest;
    if (incoming == null) return;

    final myProfile = ref.read(profileProvider).value;
    final myIdentity = await CryptoService.getOrCreateIdentity();
    if (myProfile == null) return;

    final safetyCode = CryptoService.computeSafetyCode(
      myIdentity.publicKeyHex,
      incoming.payload.senderPublicKey,
    );

    // Derive symmetric session key
    final peerPubBytes = Uint8List.fromList(incoming.payload.senderPublicKey.codeUnits);
    final sessionKey = CryptoService.deriveSessionKey(myIdentity.privateKey, peerPubBytes);

    final updatedKeys = Map<String, Uint8List>.from(state.sessionKeys);
    updatedKeys[incoming.payload.senderProfile.id] = sessionKey;

    // Save peer as Contact
    final contact = ContactModel(
      id: incoming.payload.senderProfile.id,
      displayName: incoming.payload.senderProfile.displayName,
      avatarBytes: incoming.payload.senderProfile.avatarBytes,
      bio: incoming.payload.senderProfile.bio,
      status: incoming.payload.senderProfile.status,
      publicKey: incoming.payload.senderPublicKey,
      safetyCode: safetyCode,
      createdAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );
    ref.read(databaseServiceProvider).saveContact(contact);

    // Notify requester with Response payload
    final responsePayload = ConnectionResponsePayload(
      accepted: true,
      recipientPublicKey: myIdentity.publicKeyHex,
      safetyCode: safetyCode,
    );

    await BleNativeBridge.notifyClient(
      deviceAddress: incoming.deviceAddress,
      characteristicUuid: NearbyBleConstants.connRequestCharUuid,
      payload: responsePayload.toBytes(),
    );

    state = state.copyWith(
      clearPending: true,
      activePeerId: incoming.payload.senderProfile.id,
      activeSafetyCode: safetyCode,
      sessionKeys: updatedKeys,
    );
  }

  /// Declines an incoming request
  Future<void> declineIncomingRequest() async {
    final incoming = state.pendingIncomingRequest;
    if (incoming == null) return;

    final responsePayload = const ConnectionResponsePayload(
      accepted: false,
      recipientPublicKey: '',
      safetyCode: '',
    );

    await BleNativeBridge.notifyClient(
      deviceAddress: incoming.deviceAddress,
      characteristicUuid: NearbyBleConstants.connRequestCharUuid,
      payload: responsePayload.toBytes(),
    );

    state = state.copyWith(clearPending: true);
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionStateModel>((ref) {
  return ConnectionNotifier(ref);
});
