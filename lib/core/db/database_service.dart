import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserStatus { available, busy, invisible }

enum MessageType { text, image, video, gif, pdf, voice, file }

enum DeliveryStatus { queued, sent, delivered, read }

class ContactModel {
  final String id;
  final String displayName;
  final Uint8List? avatarBytes;
  final String bio;
  final UserStatus status;
  final String publicKey;
  final String safetyCode;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  const ContactModel({
    required this.id,
    required this.displayName,
    this.avatarBytes,
    this.bio = '',
    this.status = UserStatus.available,
    required this.publicKey,
    this.safetyCode = '',
    this.isBlocked = false,
    required this.createdAt,
    required this.lastSeenAt,
  });

  ContactModel copyWith({
    String? displayName,
    Uint8List? avatarBytes,
    String? bio,
    UserStatus? status,
    String? safetyCode,
    bool? isBlocked,
    DateTime? lastSeenAt,
  }) {
    return ContactModel(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      publicKey: publicKey,
      safetyCode: safetyCode ?? this.safetyCode,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String content;
  final MessageType messageType;
  final String? fileUrl;
  final int fileSize;
  final DeliveryStatus deliveryStatus;
  final String? replyToId;
  final Map<String, String> reactions; // emoji -> userId
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.messageType = MessageType.text,
    this.fileUrl,
    this.fileSize = 0,
    this.deliveryStatus = DeliveryStatus.queued,
    this.replyToId,
    this.reactions = const {},
    required this.timestamp,
  });

  MessageModel copyWith({
    DeliveryStatus? deliveryStatus,
    Map<String, String>? reactions,
    String? fileUrl,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      content: content,
      messageType: messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      replyToId: replyToId,
      reactions: reactions ?? this.reactions,
      timestamp: timestamp,
    );
  }
}

class TransferModel {
  final String id;
  final String messageId;
  final String filePath;
  final int totalBytes;
  final int transferredBytes;
  final String status; // pending, transferring, completed, failed
  final String transferType; // ble, wifi_direct
  final String checksumSha256;
  final DateTime startedAt;

  const TransferModel({
    required this.id,
    required this.messageId,
    required this.filePath,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = 'pending',
    this.transferType = 'ble',
    required this.checksumSha256,
    required this.startedAt,
  });

  double get progress => totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class DatabaseService {
  final Map<String, ContactModel> _contacts = {};
  final List<MessageModel> _messages = [];
  final Map<String, TransferModel> _transfers = {};

  // Contacts
  List<ContactModel> getAllContacts() {
    return _contacts.values.where((c) => !c.isBlocked).toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  }

  ContactModel? getContact(String id) => _contacts[id];

  void saveContact(ContactModel contact) {
    _contacts[contact.id] = contact;
  }

  void blockContact(String id, bool blocked) {
    if (_contacts.containsKey(id)) {
      _contacts[id] = _contacts[id]!.copyWith(isBlocked: blocked);
    }
  }

  void removeContact(String id) {
    _contacts.remove(id);
  }

  // Messages
  List<MessageModel> getMessagesForConversation(String conversationId) {
    return _messages
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<MessageModel> getQueuedMessages(String recipientId) {
    return _messages
        .where((m) => m.recipientId == recipientId && m.deliveryStatus == DeliveryStatus.queued)
        .toList();
  }

  void addMessage(MessageModel msg) {
    _messages.add(msg);
  }

  void updateMessageStatus(String messageId, DeliveryStatus status) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(deliveryStatus: status);
    }
  }

  void addReaction(String messageId, String emoji, String userId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final updatedReactions = Map<String, String>.from(_messages[index].reactions);
      updatedReactions[emoji] = userId;
      _messages[index] = _messages[index].copyWith(reactions: updatedReactions);
    }
  }

  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
  }

  // Transfers
  void recordTransfer(TransferModel transfer) {
    _transfers[transfer.id] = transfer;
  }

  TransferModel? getTransfer(String id) => _transfers[id];
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
