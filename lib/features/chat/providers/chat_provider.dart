import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/ble/ble_native_bridge.dart';
import '../../../core/ble/nearby_ble_constants.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/db/database_service.dart';
import '../../connections/providers/connection_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../radar/providers/radar_provider.dart';
import '../models/chat_payload.dart';

class ChatState {
  final Map<String, List<MessageModel>> messagesByConversation;
  final Map<String, bool> typingStatus; // peerId -> isTyping
  final String? activeChatPeerId;

  const ChatState({
    this.messagesByConversation = const {},
    this.typingStatus = const {},
    this.activeChatPeerId,
  });

  ChatState copyWith({
    Map<String, List<MessageModel>>? messagesByConversation,
    Map<String, bool>? typingStatus,
    String? activeChatPeerId,
  }) {
    return ChatState(
      messagesByConversation: messagesByConversation ?? this.messagesByConversation,
      typingStatus: typingStatus ?? this.typingStatus,
      activeChatPeerId: activeChatPeerId ?? this.activeChatPeerId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;

  ChatNotifier(this.ref) : super(const ChatState()) {
    _initMessageListener();
    _listenForRadarReconnection();
  }

  void _initMessageListener() {
    BleNativeBridge.onMessageChunkReceived = (deviceAddress, payloadBytes) {
      _handleIncomingMessage(deviceAddress, payloadBytes);
    };
  }

  void _handleIncomingMessage(String deviceAddress, Uint8List payloadBytes) {
    final packet = ChatMessagePacket.fromBytes(payloadBytes);
    if (packet == null) return;

    // Decrypt content if session key exists
    final sessionKeys = ref.read(connectionProvider).sessionKeys;
    final sessionKey = sessionKeys[packet.senderId];

    String decryptedContent = packet.content;
    if (sessionKey != null) {
      try {
        final cipherBytes = base64Decode(packet.content);
        final plain = CryptoService.decryptPayload(cipherBytes, sessionKey);
        if (plain != null) {
          decryptedContent = utf8.decode(plain);
        }
      } catch (_) {}
    }

    final message = MessageModel(
      id: packet.messageId,
      conversationId: packet.senderId,
      senderId: packet.senderId,
      recipientId: packet.recipientId,
      content: decryptedContent,
      messageType: packet.type,
      fileUrl: packet.fileUrl,
      fileSize: packet.fileSize,
      deliveryStatus: DeliveryStatus.delivered,
      replyToId: packet.replyToId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
    );

    // Persist to DB
    ref.read(databaseServiceProvider).addMessage(message);

    // Update in-memory state
    final conv = List<MessageModel>.from(state.messagesByConversation[packet.senderId] ?? []);
    conv.add(message);

    final updated = Map<String, List<MessageModel>>.from(state.messagesByConversation);
    updated[packet.senderId] = conv;

    state = state.copyWith(messagesByConversation: updated);
  }

  void _listenForRadarReconnection() {
    // Whenever radar peers update, check if we can flush queued messages
    ref.listen(radarProvider, (previous, next) {
      for (final peer in next.activePeers) {
        final queued = ref.read(databaseServiceProvider).getQueuedMessages(peer.deviceId);
        if (queued.isNotEmpty) {
          _flushQueuedMessages(peer.deviceId, queued);
        }
      }
    });
  }

  Future<void> _flushQueuedMessages(String peerId, List<MessageModel> queued) async {
    for (final msg in queued) {
      await _deliverMessageOverBle(peerId, msg);
    }
  }

  Future<void> sendMessage({
    required String recipientId,
    required String text,
    MessageType type = MessageType.text,
    String? fileUrl,
    int fileSize = 0,
    String? replyToId,
  }) async {
    final myProfile = ref.read(profileProvider).value;
    if (myProfile == null) return;

    final messageId = const Uuid().v4();

    // Determine initial delivery status based on whether peer is in range
    final radarPeers = ref.read(radarProvider).activePeers;
    final isPeerInRange = radarPeers.any((p) => p.deviceId == recipientId);

    final initialStatus = isPeerInRange ? DeliveryStatus.sent : DeliveryStatus.queued;

    final message = MessageModel(
      id: messageId,
      conversationId: recipientId,
      senderId: myProfile.id,
      recipientId: recipientId,
      content: text,
      messageType: type,
      fileUrl: fileUrl,
      fileSize: fileSize,
      deliveryStatus: initialStatus,
      replyToId: replyToId,
      timestamp: DateTime.now(),
    );

    // Save to DB
    ref.read(databaseServiceProvider).addMessage(message);

    // Add to state
    final conv = List<MessageModel>.from(state.messagesByConversation[recipientId] ?? []);
    conv.add(message);
    final updated = Map<String, List<MessageModel>>.from(state.messagesByConversation);
    updated[recipientId] = conv;
    state = state.copyWith(messagesByConversation: updated);

    // If peer is in range, transmit immediately
    if (isPeerInRange) {
      await _deliverMessageOverBle(recipientId, message);
    }
  }

  Future<void> _deliverMessageOverBle(String recipientId, MessageModel msg) async {
    try {
      final sessionKeys = ref.read(connectionProvider).sessionKeys;
      final sessionKey = sessionKeys[recipientId];

      String contentPayload = msg.content;
      if (sessionKey != null) {
        final encrypted = CryptoService.encryptPayload(
          Uint8List.fromList(utf8.encode(msg.content)),
          sessionKey,
        );
        contentPayload = base64Encode(encrypted);
      }

      final packet = ChatMessagePacket(
        messageId: msg.id,
        senderId: msg.senderId,
        recipientId: msg.recipientId,
        type: msg.messageType,
        content: contentPayload,
        fileUrl: msg.fileUrl,
        fileSize: msg.fileSize,
        replyToId: msg.replyToId,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
      );

      final device = BluetoothDevice.fromId(recipientId);
      await device.connect(timeout: const Duration(seconds: 4));

      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid == Guid(NearbyBleConstants.serviceUuid),
      );
      final msgChar = targetService.characteristics.firstWhere(
        (c) => c.uuid == Guid(NearbyBleConstants.messageCharUuid),
      );

      await msgChar.write(packet.toBytes(), withoutResponse: true);

      // Update to delivered
      ref.read(databaseServiceProvider).updateMessageStatus(msg.id, DeliveryStatus.delivered);
      _updateMessageStatusInState(recipientId, msg.id, DeliveryStatus.delivered);
    } catch (e) {
      // Revert to queued if transmission fails
      ref.read(databaseServiceProvider).updateMessageStatus(msg.id, DeliveryStatus.queued);
      _updateMessageStatusInState(recipientId, msg.id, DeliveryStatus.queued);
    }
  }

  void _updateMessageStatusInState(String convId, String msgId, DeliveryStatus status) {
    final conv = List<MessageModel>.from(state.messagesByConversation[convId] ?? []);
    final idx = conv.indexWhere((m) => m.id == msgId);
    if (idx != -1) {
      conv[idx] = conv[idx].copyWith(deliveryStatus: status);
      final updated = Map<String, List<MessageModel>>.from(state.messagesByConversation);
      updated[convId] = conv;
      state = state.copyWith(messagesByConversation: updated);
    }
  }

  void addReaction(String conversationId, String messageId, String emoji) {
    final myProfile = ref.read(profileProvider).value;
    if (myProfile == null) return;

    ref.read(databaseServiceProvider).addReaction(messageId, emoji, myProfile.id);

    final conv = List<MessageModel>.from(state.messagesByConversation[conversationId] ?? []);
    final idx = conv.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final updatedReactions = Map<String, String>.from(conv[idx].reactions);
      updatedReactions[emoji] = myProfile.id;
      conv[idx] = conv[idx].copyWith(reactions: updatedReactions);

      final updated = Map<String, List<MessageModel>>.from(state.messagesByConversation);
      updated[conversationId] = conv;
      state = state.copyWith(messagesByConversation: updated);
    }
  }

  void deleteMessage(String conversationId, String messageId) {
    ref.read(databaseServiceProvider).deleteMessage(messageId);
    final conv = List<MessageModel>.from(state.messagesByConversation[conversationId] ?? []);
    conv.removeWhere((m) => m.id == messageId);
    final updated = Map<String, List<MessageModel>>.from(state.messagesByConversation);
    updated[conversationId] = conv;
    state = state.copyWith(messagesByConversation: updated);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
