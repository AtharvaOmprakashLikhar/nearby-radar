import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_radar/core/crypto/crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CryptoService Tests', () {
    test('Safety code is symmetric regardless of argument order', () {
      const pubA = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
      const pubB = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

      final code1 = CryptoService.computeSafetyCode(pubA, pubB);
      final code2 = CryptoService.computeSafetyCode(pubB, pubA);

      expect(code1, equals(code2));
      expect(code1.length, equals(7)); // "123 456"
      expect(code1.contains(' '), isTrue);
    });

    test('Short userId hash is exactly 4 bytes', () {
      const userId = "4e3b1c67-9d2a-4f5e-8b1a-2c3d4e5f6a7b";
      final hash = CryptoService.computeShortUserIdHash(userId);

      expect(hash.length, equals(4));
    });

    test('Encrypt and decrypt roundtrip succeeds with correct session key', () {
      final sessionKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        sessionKey[i] = i * 7;
      }

      final plaintext = Uint8List.fromList(utf8.encode("Hello from peer-to-peer offline radar!"));
      final encrypted = CryptoService.encryptPayload(plaintext, sessionKey);

      expect(encrypted.length, greaterThan(plaintext.length));

      final decrypted = CryptoService.decryptPayload(encrypted, sessionKey);
      expect(decrypted, isNotNull);
      expect(utf8.decode(decrypted!), equals("Hello from peer-to-peer offline radar!"));
    });

    test('Decryption fails with tampered ciphertext', () {
      final sessionKey = Uint8List(32);
      final plaintext = Uint8List.fromList(utf8.encode("Sensitive offline data"));
      final encrypted = CryptoService.encryptPayload(plaintext, sessionKey);

      // Tamper with ciphertext byte
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      final result = CryptoService.decryptPayload(tampered, sessionKey);
      expect(result, isNull);
    });

    test('Decryption fails with wrong session key', () {
      final sessionKey1 = Uint8List(32);
      final sessionKey2 = Uint8List(32)..fillRange(0, 32, 1);

      final plaintext = Uint8List.fromList(utf8.encode("Secret message"));
      final encrypted = CryptoService.encryptPayload(plaintext, sessionKey1);

      final result = CryptoService.decryptPayload(encrypted, sessionKey2);
      expect(result, isNull);
    });
  });
}
