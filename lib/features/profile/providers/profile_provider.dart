import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/db/database_service.dart';
import '../models/user_profile.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  static const _kProfileKey = 'nearby_user_profile';

  ProfileNotifier() : super(const AsyncValue.loading()) {
    initProfile();
  }

  Future<void> initProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPair = await CryptoService.getOrCreateIdentity();
      final userId = await CryptoService.getOrCreateUserId();

      final savedJson = prefs.getString(_kProfileKey);
      if (savedJson != null) {
        final map = jsonDecode(savedJson) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(map).copyWith(
          id: userId,
          publicKey: keyPair.publicKeyHex,
        );
        state = AsyncValue.data(profile);
      } else {
        // Create initial default profile
        final defaultProfile = UserProfile(
          id: userId,
          displayName: 'Echo Explorer',
          bio: 'Exploring offline mesh networks.',
          status: UserStatus.available,
          interests: ['Radar', 'P2P', 'Privacy'],
          publicKey: keyPair.publicKeyHex,
        );
        await saveProfile(defaultProfile);
        state = AsyncValue.data(defaultProfile);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileKey, jsonEncode(profile.toJson()));
    state = AsyncValue.data(profile);
  }

  Future<void> updateNameAndBio(String name, String bio) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(displayName: name, bio: bio);
    await saveProfile(updated);
  }

  Future<void> updateAvatar(Uint8List rawBytes) async {
    final current = state.value;
    if (current == null) return;
    final clamped = UserProfile.clampAvatarSize(rawBytes);
    final updated = current.copyWith(avatarBytes: clamped);
    await saveProfile(updated);
  }

  Future<void> updateStatus(UserStatus newStatus) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(status: newStatus);
    await saveProfile(updated);
  }

  Future<void> updateInterests(List<String> interests) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(interests: interests);
    await saveProfile(updated);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier();
});
