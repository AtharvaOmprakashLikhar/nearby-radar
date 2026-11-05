import 'dart:convert';
import 'dart:typed_data';
import '../../profile/models/user_profile.dart';

class ConnectionRequestPayload {
  final UserProfile senderProfile;
  final String senderPublicKey;
  final int timestamp;

  const ConnectionRequestPayload({
    required this.senderProfile,
    required this.senderPublicKey,
    required this.timestamp,
  });

  Uint8List toBytes() {
    final map = {
      'type': 'request',
      'profile': senderProfile.toJson(),
      'publicKey': senderPublicKey,
      'timestamp': timestamp,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static ConnectionRequestPayload? fromBytes(Uint8List bytes) {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (map['type'] != 'request') return null;
      return ConnectionRequestPayload(
        senderProfile: UserProfile.fromJson(map['profile'] as Map<String, dynamic>),
        senderPublicKey: map['publicKey'] as String,
        timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return null;
    }
  }
}

class ConnectionResponsePayload {
  final bool accepted;
  final String recipientPublicKey;
  final String safetyCode;

  const ConnectionResponsePayload({
    required this.accepted,
    required this.recipientPublicKey,
    required this.safetyCode,
  });

  Uint8List toBytes() {
    final map = {
      'type': 'response',
      'accepted': accepted,
      'publicKey': recipientPublicKey,
      'safetyCode': safetyCode,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static ConnectionResponsePayload? fromBytes(Uint8List bytes) {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (map['type'] != 'response') return null;
      return ConnectionResponsePayload(
        accepted: map['accepted'] as bool? ?? false,
        recipientPublicKey: map['publicKey'] as String? ?? '',
        safetyCode: map['safetyCode'] as String? ?? '',
      );
    } catch (e) {
      return null;
    }
  }
}
