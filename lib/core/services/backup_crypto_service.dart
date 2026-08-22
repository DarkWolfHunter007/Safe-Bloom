import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class BackupCryptoException implements Exception {
  final String message;
  const BackupCryptoException(this.message);
  @override
  String toString() => 'BackupCryptoException: $message';
}

class InvalidBackupPasswordException extends BackupCryptoException {
  const InvalidBackupPasswordException([super.message = 'Invalid password or corrupted backup vault.']);
}

class MalformedBackupPayloadException extends BackupCryptoException {
  const MalformedBackupPayloadException([super.message = 'Malformed or incompatible backup payload.']);
}

/// Standardized cryptographic service for password-protected Safe Bloom backup vaults.
/// Uses PBKDF2-HMAC-SHA256 key derivation + AES-256-CTR + HMAC-SHA256 (Encrypt-then-MAC).
class BackupCryptoService {
  static const int kVersion = 1;
  static const String kAlgorithm = 'AES-256-CTR-HMAC-SHA256';
  static const int kPbkdf2Iterations = 20000;
  static const int kSaltLength = 16;
  static const int kIvLength = 16;
  static const int kMaxPayloadBytes = 10 * 1024 * 1024; // 10 MB sanity limit

  /// Encrypts plaintext JSON data with a user-provided passphrase into a protected envelope.
  static String encryptVault({
    required String plaintextJson,
    required String passphrase,
  }) {
    if (passphrase.trim().isEmpty) {
      throw const BackupCryptoException('Passphrase cannot be empty.');
    }

    final random = Random.secure();
    final salt = Uint8List(kSaltLength);
    for (int i = 0; i < kSaltLength; i++) {
      salt[i] = random.nextInt(256);
    }

    final iv = Uint8List(kIvLength);
    for (int i = 0; i < kIvLength; i++) {
      iv[i] = random.nextInt(256);
    }

    // Derive 64 bytes: 32 bytes for AES-256 encryption key, 32 bytes for HMAC-SHA256 authentication key
    final derivedKeys = _pbkdf2(
      password: utf8.encode(passphrase),
      salt: salt,
      iterations: kPbkdf2Iterations,
      derivedKeyLength: 64,
    );

    final encKey = Uint8List.sublistView(derivedKeys, 0, 32);
    final authKey = Uint8List.sublistView(derivedKeys, 32, 64);

    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintextJson));
    final ciphertextBytes = _aes256Ctr(plaintextBytes, encKey, iv);

    // Compute HMAC-SHA256 over: version (1 byte) + salt + iv + ciphertext
    final macData = BytesBuilder(copy: false)
      ..addByte(kVersion)
      ..add(salt)
      ..add(iv)
      ..add(ciphertextBytes);

    final hmac = Hmac(sha256, authKey);
    final macDigest = hmac.convert(macData.toBytes());

    final envelope = {
      'safe_bloom_backup_version': kVersion,
      'format': 'ENCRYPTED_VAULT_V1',
      'algorithm': kAlgorithm,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': kPbkdf2Iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(ciphertextBytes),
      'mac': base64Encode(macDigest.bytes),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Decrypts a protected envelope using the user-provided passphrase after verifying MAC integrity.
  static String decryptVault({
    required String vaultJsonString,
    required String passphrase,
  }) {
    if (passphrase.trim().isEmpty) {
      throw const InvalidBackupPasswordException('Password cannot be empty.');
    }

    if (vaultJsonString.length > kMaxPayloadBytes) {
      throw const MalformedBackupPayloadException('Backup file exceeds maximum allowed size (10 MB).');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(vaultJsonString);
    } catch (_) {
      throw const MalformedBackupPayloadException('Invalid JSON formatting in backup file.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const MalformedBackupPayloadException('Backup payload must be a JSON object.');
    }

    final version = decoded['safe_bloom_backup_version'];
    final format = decoded['format'];
    final saltStr = decoded['salt'];
    final ivStr = decoded['iv'];
    final ciphertextStr = decoded['ciphertext'];
    final macStr = decoded['mac'];
    final iterations = decoded['iterations'] is int ? decoded['iterations'] as int : kPbkdf2Iterations;

    if (version == null || format != 'ENCRYPTED_VAULT_V1' || saltStr is! String || ivStr is! String || ciphertextStr is! String || macStr is! String) {
      throw const MalformedBackupPayloadException('Missing or invalid encrypted vault envelope headers.');
    }

    Uint8List salt;
    Uint8List iv;
    Uint8List ciphertext;
    Uint8List expectedMac;
    try {
      salt = base64Decode(saltStr);
      iv = base64Decode(ivStr);
      ciphertext = base64Decode(ciphertextStr);
      expectedMac = base64Decode(macStr);
    } catch (_) {
      throw const MalformedBackupPayloadException('Corrupted base64 encoding in vault payload.');
    }

    if (salt.length != kSaltLength || iv.length != kIvLength) {
      throw const MalformedBackupPayloadException('Invalid cryptographic parameter lengths.');
    }

    // Derive keys
    final derivedKeys = _pbkdf2(
      password: utf8.encode(passphrase),
      salt: salt,
      iterations: iterations,
      derivedKeyLength: 64,
    );

    final encKey = Uint8List.sublistView(derivedKeys, 0, 32);
    final authKey = Uint8List.sublistView(derivedKeys, 32, 64);

    // Verify HMAC
    final macData = BytesBuilder(copy: false)
      ..addByte(version is int ? version : kVersion)
      ..add(salt)
      ..add(iv)
      ..add(ciphertext);

    final hmac = Hmac(sha256, authKey);
    final actualMac = Uint8List.fromList(hmac.convert(macData.toBytes()).bytes);

    if (!_constantTimeEquals(actualMac, expectedMac)) {
      throw const InvalidBackupPasswordException('Incorrect password or corrupted backup vault.');
    }

    // Decrypt ciphertext using AES-256-CTR
    final decryptedBytes = _aes256Ctr(ciphertext, encKey, iv);
    try {
      return utf8.decode(decryptedBytes);
    } catch (_) {
      throw const MalformedBackupPayloadException('Decrypted payload is not valid UTF-8 text.');
    }
  }

  /// Constant-time byte comparison to prevent timing attacks.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Standard PBKDF2 with HMAC-SHA256
  static Uint8List _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int derivedKeyLength,
  }) {
    final hmac = Hmac(sha256, password);
    const hLen = 32; // SHA-256 output length
    final l = (derivedKeyLength / hLen).ceil();
    final r = derivedKeyLength - (l - 1) * hLen;

    final derivedKey = Uint8List(derivedKeyLength);
    int keyOffset = 0;

    for (int i = 1; i <= l; i++) {
      // U1 = PRF(password, salt || INT_32_BE(i))
      final saltBlock = BytesBuilder(copy: false)
        ..add(salt)
        ..addByte((i >> 24) & 0xFF)
        ..addByte((i >> 16) & 0xFF)
        ..addByte((i >> 8) & 0xFF)
        ..addByte(i & 0xFF);

      var u = Uint8List.fromList(hmac.convert(saltBlock.toBytes()).bytes);
      var t = Uint8List.fromList(u);

      // U2..Uc
      for (int j = 1; j < iterations; j++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }

      final copyLength = (i == l) ? r : hLen;
      derivedKey.setRange(keyOffset, keyOffset + copyLength, t.sublist(0, copyLength));
      keyOffset += copyLength;
    }

    return derivedKey;
  }

  /// AES-256 in CTR mode (self-contained FIPS 197 compliant)
  static Uint8List _aes256Ctr(Uint8List input, Uint8List key32, Uint8List iv16) {
    final expandedKey = _expandKey256(key32);
    final output = Uint8List(input.length);
    final counter = Uint8List.fromList(iv16);
    final encryptedCounter = Uint8List(16);

    for (int offset = 0; offset < input.length; offset += 16) {
      _encryptBlock(counter, encryptedCounter, expandedKey);
      final blockSize = min(16, input.length - offset);
      for (int i = 0; i < blockSize; i++) {
        output[offset + i] = input[offset + i] ^ encryptedCounter[i];
      }

      // Increment 128-bit big-endian counter
      for (int i = 15; i >= 0; i--) {
        counter[i] = (counter[i] + 1) & 0xFF;
        if (counter[i] != 0) break;
      }
    }

    return output;
  }

  // --- AES Core Primitives ---

  static final List<int> _sbox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5e, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  static final List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static Uint32List _expandKey256(Uint8List key) {
    final w = Uint32List(60); // 4 * (14 + 1) = 60 words for AES-256
    for (int i = 0; i < 8; i++) {
      w[i] = (key[4 * i] << 24) |
          (key[4 * i + 1] << 16) |
          (key[4 * i + 2] << 8) |
          key[4 * i + 3];
    }

    for (int i = 8; i < 60; i++) {
      var temp = w[i - 1];
      if (i % 8 == 0) {
        temp = _subWord(_rotWord(temp)) ^ (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = _subWord(temp);
      }
      w[i] = w[i - 8] ^ temp;
    }
    return w;
  }

  static int _rotWord(int word) => ((word << 8) & 0xFFFFFFFF) | ((word >> 24) & 0xFF);

  static int _subWord(int word) {
    return (_sbox[(word >> 24) & 0xFF] << 24) |
        (_sbox[(word >> 16) & 0xFF] << 16) |
        (_sbox[(word >> 8) & 0xFF] << 8) |
        _sbox[word & 0xFF];
  }

  static int _xtimes(int b) => ((b << 1) ^ (((b >> 7) & 1) * 0x1b)) & 0xFF;

  static void _encryptBlock(Uint8List input, Uint8List output, Uint32List w) {
    var state = Uint8List.fromList(input);

    // Initial AddRoundKey
    for (int i = 0; i < 4; i++) {
      final keyWord = w[i];
      state[4 * i] ^= (keyWord >> 24) & 0xFF;
      state[4 * i + 1] ^= (keyWord >> 16) & 0xFF;
      state[4 * i + 2] ^= (keyWord >> 8) & 0xFF;
      state[4 * i + 3] ^= keyWord & 0xFF;
    }

    // 13 Main Rounds
    for (int round = 1; round <= 13; round++) {
      // SubBytes
      for (int i = 0; i < 16; i++) {
        state[i] = _sbox[state[i]];
      }

      // ShiftRows
      final s0 = state[0], s4 = state[4], s8 = state[8], s12 = state[12];
      final s1 = state[1], s5 = state[5], s9 = state[9], s13 = state[13];
      final s2 = state[2], s6 = state[6], s10 = state[10], s14 = state[14];
      final s3 = state[3], s7 = state[7], s11 = state[11], s15 = state[15];

      state[0] = s0; state[4] = s4; state[8] = s8; state[12] = s12;
      state[1] = s5; state[5] = s9; state[9] = s13; state[13] = s1;
      state[2] = s10; state[6] = s14; state[10] = s2; state[14] = s6;
      state[3] = s15; state[7] = s3; state[11] = s7; state[15] = s11;

      // MixColumns
      for (int c = 0; c < 4; c++) {
        final col = c * 4;
        final a0 = state[col], a1 = state[col + 1], a2 = state[col + 2], a3 = state[col + 3];
        state[col] = _xtimes(a0) ^ (_xtimes(a1) ^ a1) ^ a2 ^ a3;
        state[col + 1] = a0 ^ _xtimes(a1) ^ (_xtimes(a2) ^ a2) ^ a3;
        state[col + 2] = a0 ^ a1 ^ _xtimes(a2) ^ (_xtimes(a3) ^ a3);
        state[col + 3] = (_xtimes(a0) ^ a0) ^ a1 ^ a2 ^ _xtimes(a3);
      }

      // AddRoundKey
      for (int i = 0; i < 4; i++) {
        final keyWord = w[round * 4 + i];
        state[4 * i] ^= (keyWord >> 24) & 0xFF;
        state[4 * i + 1] ^= (keyWord >> 16) & 0xFF;
        state[4 * i + 2] ^= (keyWord >> 8) & 0xFF;
        state[4 * i + 3] ^= keyWord & 0xFF;
      }
    }

    // Final Round (Round 14) — No MixColumns
    for (int i = 0; i < 16; i++) {
      state[i] = _sbox[state[i]];
    }

    final s0 = state[0], s4 = state[4], s8 = state[8], s12 = state[12];
    final s1 = state[1], s5 = state[5], s9 = state[9], s13 = state[13];
    final s2 = state[2], s6 = state[6], s10 = state[10], s14 = state[14];
    final s3 = state[3], s7 = state[7], s11 = state[11], s15 = state[15];

    state[0] = s0; state[4] = s4; state[8] = s8; state[12] = s12;
    state[1] = s5; state[5] = s9; state[9] = s13; state[13] = s1;
    state[2] = s10; state[6] = s14; state[10] = s2; state[14] = s6;
    state[3] = s15; state[7] = s3; state[11] = s7; state[15] = s11;

    for (int i = 0; i < 4; i++) {
      final keyWord = w[14 * 4 + i];
      state[4 * i] ^= (keyWord >> 24) & 0xFF;
      state[4 * i + 1] ^= (keyWord >> 16) & 0xFF;
      state[4 * i + 2] ^= (keyWord >> 8) & 0xFF;
      state[4 * i + 3] ^= keyWord & 0xFF;
    }

    output.setRange(0, 16, state);
  }
}
