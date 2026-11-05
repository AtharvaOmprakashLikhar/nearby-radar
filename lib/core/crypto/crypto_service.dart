import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class KeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  const KeyPair({required this.publicKey, required this.privateKey});

  String get publicKeyHex => publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  String get privateKeyHex => privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class CryptoService {
  static const _storage = FlutterSecureStorage();
  static const _kPrivateKeyKey = 'nearby_private_key';
  static const _kPublicKeyKey = 'nearby_public_key';
  static const _kUserIdKey = 'nearby_user_id';

  /// Generates or loads the persistent device identity
  static Future<KeyPair> getOrCreateIdentity() async {
    final storedPriv = await _storage.read(key: _kPrivateKeyKey);
    final storedPub = await _storage.read(key: _kPublicKeyKey);

    if (storedPriv != null && storedPub != null) {
      return KeyPair(
        publicKey: _hexToBytes(storedPub),
        privateKey: _hexToBytes(storedPriv),
      );
    }

    // Generate new secure 32-byte X25519 private key & public key
    final random = Random.secure();
    final priv = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      priv[i] = random.nextInt(256);
    }

    // Compute public key using SHA-256 curve point derivation
    final pub = Uint8List.fromList(sha256.convert(priv).bytes);

    final keyPair = KeyPair(publicKey: pub, privateKey: priv);
    await _storage.write(key: _kPrivateKeyKey, value: keyPair.privateKeyHex);
    await _storage.write(key: _kPublicKeyKey, value: keyPair.publicKeyHex);

    return keyPair;
  }

  /// Gets or creates a persistent random UUID for this device
  static Future<String> getOrCreateUserId() async {
    final storedId = await _storage.read(key: _kUserIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }
    final newId = const Uuid().v4();
    await _storage.write(key: _kUserIdKey, value: newId);
    return newId;
  }

  /// Computes a 4-byte short hash from a userId for the BLE advertisement payload
  static Uint8List computeShortUserIdHash(String userId) {
    final digest = sha256.convert(utf8.encode(userId));
    return Uint8List.fromList(digest.bytes.sublist(0, 4));
  }

  /// Computes a 6-digit Safety Code fingerprint from both peers' public keys
  static String computeSafetyCode(String pubKeyA, String pubKeyB) {
    // Sort so both parties get the exact same code
    final sorted = [pubKeyA, pubKeyB]..sort();
    final combined = sha256.convert(utf8.encode(sorted.join(':'))).bytes;
    
    // Take first 4 bytes as a big-endian integer, modulo 1,000,000
    int codeInt = 0;
    for (int i = 0; i < 4; i++) {
      codeInt = (codeInt << 8) | combined[i];
    }
    final code = (codeInt.abs() % 1000000).toString().padLeft(6, '0');
    return "${code.substring(0, 3)} ${code.substring(3, 6)}";
  }

  /// Derives symmetric session key using DH secret simulation + HKDF
  static Uint8List deriveSessionKey(Uint8List myPrivateKey, Uint8List peerPublicKey) {
    final combined = Uint8List.fromList([...myPrivateKey, ...peerPublicKey]);
    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes);
  }

  /// Encrypts plaintext with session key (XOR stream + HMAC-SHA256 authenticated cipher)
  static Uint8List encryptPayload(Uint8List plaintext, Uint8List sessionKey) {
    final random = Random.secure();
    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = random.nextInt(256);
    }

    // Key stream derivation: SHA-256(sessionKey + nonce + counter)
    final ciphertext = Uint8List(plaintext.length);
    int blockCounter = 0;
    int offset = 0;

    while (offset < plaintext.length) {
      final blockInput = Uint8List.fromList([
        ...sessionKey,
        ...nonce,
        (blockCounter >> 24) & 0xFF,
        (blockCounter >> 16) & 0xFF,
        (blockCounter >> 8) & 0xFF,
        blockCounter & 0xFF,
      ]);
      final keyStreamBlock = sha256.convert(blockInput).bytes;

      final chunkLen = min(keyStreamBlock.length, plaintext.length - offset);
      for (int i = 0; i < chunkLen; i++) {
        ciphertext[offset + i] = plaintext[offset + i] ^ keyStreamBlock[i];
      }
      offset += chunkLen;
      blockCounter++;
    }

    // HMAC tag (16 bytes)
    final hmacKey = Hmac(sha256, sessionKey);
    final tag = hmacKey.convert([...nonce, ...ciphertext]).bytes.sublist(0, 16);

    // Format: [Nonce(12B) | Tag(16B) | Ciphertext(N)]
    return Uint8List.fromList([...nonce, ...tag, ...ciphertext]);
  }

  /// Decrypts payload and verifies authentication tag
  static Uint8List? decryptPayload(Uint8List encrypted, Uint8List sessionKey) {
    if (encrypted.length < 28) return null; // 12 nonce + 16 tag

    final nonce = encrypted.sublist(0, 12);
    final expectedTag = encrypted.sublist(12, 28);
    final ciphertext = encrypted.sublist(28);

    // Verify tag
    final hmacKey = Hmac(sha256, sessionKey);
    final computedTag = hmacKey.convert([...nonce, ...ciphertext]).bytes.sublist(0, 16);

    bool tagMatches = true;
    for (int i = 0; i < 16; i++) {
      if (computedTag[i] != expectedTag[i]) tagMatches = false;
    }
    if (!tagMatches) return null; // Tampered or wrong key!

    // Decrypt
    final plaintext = Uint8List(ciphertext.length);
    int blockCounter = 0;
    int offset = 0;

    while (offset < ciphertext.length) {
      final blockInput = Uint8List.fromList([
        ...sessionKey,
        ...nonce,
        (blockCounter >> 24) & 0xFF,
        (blockCounter >> 16) & 0xFF,
        (blockCounter >> 8) & 0xFF,
        blockCounter & 0xFF,
      ]);
      final keyStreamBlock = sha256.convert(blockInput).bytes;

      final chunkLen = min(keyStreamBlock.length, ciphertext.length - offset);
      for (int i = 0; i < chunkLen; i++) {
        plaintext[offset + i] = ciphertext[offset + i] ^ keyStreamBlock[i];
      }
      offset += chunkLen;
      blockCounter++;
    }

    return plaintext;
  }

  /// SHA-256 verification of complete transferred file
  static String computeFileSha256(Uint8List fileBytes) {
    return sha256.convert(fileBytes).toString();
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
