import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoUtils {
  CryptoUtils._();

  static final _secureRandom = Random.secure();
  static final _argon2id = Argon2id(
    parallelism: 1,
    memory: 19 * 1024, // 19 MiB
    iterations: 2,
    hashLength: 32,
  );
  static final _aesGcm = AesGcm.with256bits();

  /// Generates cryptographically secure random bytes
  static Uint8List generateRandomBytes(int length) {
    final values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = _secureRandom.nextInt(256);
    }
    return values;
  }

  /// Hashes a password or recovery answer using Argon2id with salt
  static Future<String> hashPassword(String password, {Uint8List? salt}) async {
    final saltBytes = salt ?? generateRandomBytes(16);
    final secretKey = SecretKey(utf8.encode(password));
    final mac = await _argon2id.deriveKey(
      secretKey: secretKey,
      nonce: saltBytes,
    );
    final macBytes = await mac.extractBytes();

    // Format: base64(salt):base64(hash)
    final saltB64 = base64.encode(saltBytes);
    final hashB64 = base64.encode(macBytes);
    return '$saltB64:$hashB64';
  }

  /// Verifies a password against an Argon2id formatted hash (salt:hash)
  static Future<bool> verifyPassword(String password, String storedHash) async {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final saltBytes = base64.decode(parts[0]);
      final expectedHash = parts[1];

      final computed = await hashPassword(password, salt: Uint8List.fromList(saltBytes));
      final computedHash = computed.split(':')[1];

      return computedHash == expectedHash;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts bytes using AES-256-GCM with a SecretKey derived from key bytes
  static Future<Uint8List> encryptAesGcm(Uint8List plaintext, Uint8List key256) async {
    final secretKey = SecretKey(key256);
    final nonce = generateRandomBytes(12); // 96-bit nonce
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    // Format: nonce(12) + mac(16) + ciphertext
    final combined = BytesBuilder()
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);
    return combined.toBytes();
  }

  /// Decrypts bytes encrypted using AES-256-GCM
  static Future<Uint8List> decryptAesGcm(Uint8List encryptedData, Uint8List key256) async {
    if (encryptedData.length < 28) {
      throw ArgumentError('Invalid ciphertext length for AES-256-GCM');
    }
    final nonce = encryptedData.sublist(0, 12);
    final macBytes = encryptedData.sublist(12, 28);
    final cipherText = encryptedData.sublist(28);

    final secretKey = SecretKey(key256);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearText = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(clearText);
  }
}
