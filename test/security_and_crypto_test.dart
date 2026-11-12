import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/core/security/crypto_utils.dart';

void main() {
  group('CryptoUtils Tests', () {
    test('generateRandomBytes generates correct length and distinct values', () {
      final bytes1 = CryptoUtils.generateRandomBytes(32);
      final bytes2 = CryptoUtils.generateRandomBytes(32);

      expect(bytes1.length, 32);
      expect(bytes2.length, 32);
      expect(bytes1, isNot(equals(bytes2)));
    });

    test('hashPassword produces salt:hash format and verifyPassword succeeds', () async {
      const password = 'StrongPassword@123';
      final hash = await CryptoUtils.hashPassword(password);

      expect(hash.contains(':'), isTrue);
      final parts = hash.split(':');
      expect(parts.length, 2);
      expect(parts[0].isNotEmpty, isTrue);
      expect(parts[1].isNotEmpty, isTrue);

      final isMatch = await CryptoUtils.verifyPassword(password, hash);
      expect(isMatch, isTrue);

      final isWrongMatch = await CryptoUtils.verifyPassword('WrongPassword', hash);
      expect(isWrongMatch, isFalse);
    });

    test('AES-256-GCM encrypts and decrypts accurately', () async {
      final key = CryptoUtils.generateRandomBytes(32);
      final plainText = utf8.encode('Sangh Ledger Confidential Financial Record');
      final encrypted = await CryptoUtils.encryptAesGcm(Uint8List.fromList(plainText), key);

      expect(encrypted, isNot(equals(plainText)));
      expect(encrypted.length > plainText.length, isTrue);

      final decrypted = await CryptoUtils.decryptAesGcm(encrypted, key);
      expect(utf8.decode(decrypted), 'Sangh Ledger Confidential Financial Record');
    });

    test('AES-256-GCM decryption fails with wrong key', () async {
      final key1 = CryptoUtils.generateRandomBytes(32);
      final key2 = CryptoUtils.generateRandomBytes(32);
      final plainText = utf8.encode('Top Secret');
      final encrypted = await CryptoUtils.encryptAesGcm(Uint8List.fromList(plainText), key1);

      expect(
        () async => await CryptoUtils.decryptAesGcm(encrypted, key2),
        throwsA(anything),
      );
    });
  });
}

