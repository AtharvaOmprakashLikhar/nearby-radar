import 'dart:convert';
import 'dart:typed_data';
import '../../../core/db/database_service.dart';

class ChatMessagePacket {
  final String messageId;
  final String senderId;
  final String recipientId;
  final MessageType type;
  final String content; // If text: plaintext/ciphertext; If file: metadata json
  final String? fileUrl;
  final int fileSize;
  final String? replyToId;
  final int timestamp;

  const ChatMessagePacket({
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.type,
    required this.content,
    this.fileUrl,
    this.fileSize = 0,
    this.replyToId,
    required this.timestamp,
  });

  Uint8List toBytes() {
    final map = {
      'id': messageId,
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type.name,
      'content': content,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'replyToId': replyToId,
      'timestamp': timestamp,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static ChatMessagePacket? fromBytes(Uint8List bytes) {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return ChatMessagePacket(
        messageId: map['id'] as String,
        senderId: map['senderId'] as String,
        recipientId: map['recipientId'] as String,
        type: MessageType.values.byName(map['type'] as String? ?? 'text'),
        content: map['content'] as String,
        fileUrl: map['fileUrl'] as String?,
        fileSize: map['fileSize'] as int? ?? 0,
        replyToId: map['replyToId'] as String?,
        timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return null;
    }
  }
}
