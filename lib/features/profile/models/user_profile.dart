import 'dart:convert';
import 'dart:typed_data';
import '../../../core/db/database_service.dart';

class UserProfile {
  final String id;
  final String displayName;
  final Uint8List? avatarBytes;
  final String bio;
  final UserStatus status;
  final List<String> interests;
  final String publicKey;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarBytes,
    this.bio = '',
    this.status = UserStatus.available,
    this.interests = const [],
    required this.publicKey,
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    Uint8List? avatarBytes,
    String? bio,
    UserStatus? status,
    List<String>? interests,
    String? publicKey,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      interests: interests ?? this.interests,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarBase64': avatarBytes != null ? base64Encode(avatarBytes!) : null,
      'bio': bio,
      'status': status.index,
      'interests': interests,
      'publicKey': publicKey,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Anonymous',
      avatarBytes: json['avatarBase64'] != null ? base64Decode(json['avatarBase64'] as String) : null,
      bio: json['bio'] as String? ?? '',
      status: UserStatus.values[(json['status'] as int? ?? 0).clamp(0, 2)],
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      publicKey: json['publicKey'] as String? ?? '',
    );
  }

  /// Compact binary payload for GATT Characteristic exchange
  Uint8List toGattPayload() {
    final jsonStr = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  static UserProfile? fromGattPayload(Uint8List bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  /// Helper to ensure avatar fits within the <=30KB BLE limit
  static Uint8List clampAvatarSize(Uint8List rawBytes, {int maxBytes = 30 * 1024}) {
    if (rawBytes.length <= maxBytes) {
      return rawBytes;
    }
    // Subsample / clamp slice if needed
    return rawBytes.sublist(0, maxBytes);
  }
}
