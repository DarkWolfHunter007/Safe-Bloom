import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService Unit Tests', () {
    const testJson = '{"profile":{"last_period_start":"2026-08-01T00:00:00.000Z","avg_cycle_length":28,"avg_period_length":5},"period_entries":[{"id":"p1","timestamp":"2026-08-01T00:00:00.000Z","flow":"heavy"}]}';
    const testPassword = 'SafeBloomVaultPassword2026!';

    test('Encrypt and decrypt roundtrip matches original plaintext perfectly with SafeBloomVault format', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      expect(encryptedVault, isNotEmpty);
      expect(encryptedVault, contains('SafeBloomVault'));
      expect(encryptedVault, contains('AES-256-CTR-HMAC-SHA256'));

      final decrypted = BackupCryptoService.decryptVault(
        vaultJsonString: encryptedVault,
        passphrase: testPassword,
      );

      expect(decrypted, equals(testJson));
    });

    test('Decrypts legacy ENCRYPTED_VAULT_V1 payload successfully (backward compatibility)', () {
      final normalEncrypted = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );
      final Map<String, dynamic> decoded = jsonDecode(normalEncrypted);
      decoded['format'] = 'ENCRYPTED_VAULT_V1';
      final legacyJson = jsonEncode(decoded);

      final decrypted = BackupCryptoService.decryptVault(
        vaultJsonString: legacyJson,
        passphrase: testPassword,
      );

      expect(decrypted, equals(testJson));
    });

    test('Wrong password throws InvalidBackupPasswordException without decrypting', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: encryptedVault,
          passphrase: 'WrongPassword123!',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Empty password throws exception', () {
      expect(
        () => BackupCryptoService.encryptVault(
          plaintextJson: testJson,
          passphrase: '',
        ),
        throwsA(isA<BackupCryptoException>()),
      );

      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: encryptedVault,
          passphrase: '',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Tampered ciphertext causes MAC verification failure', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      final originalCipher = base64Decode(decoded['ciphertext']);
      originalCipher[0] ^= 0x01; // Flip one bit
      decoded['ciphertext'] = base64Encode(originalCipher);

      final tamperedVault = jsonEncode(decoded);

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: tamperedVault,
          passphrase: testPassword,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Tampered salt causes MAC verification failure', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      final originalSalt = base64Decode(decoded['salt']);
      originalSalt[0] ^= 0xFF;
      decoded['salt'] = base64Encode(originalSalt);

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: jsonEncode(decoded),
          passphrase: testPassword,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Tampered IV causes MAC verification failure', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      final originalIv = base64Decode(decoded['iv']);
      originalIv[0] ^= 0xFF;
      decoded['iv'] = base64Encode(originalIv);

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: jsonEncode(decoded),
          passphrase: testPassword,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Tampered MAC causes MAC verification failure', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      final originalMac = base64Decode(decoded['mac']);
      originalMac[0] ^= 0x55;
      decoded['mac'] = base64Encode(originalMac);

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: jsonEncode(decoded),
          passphrase: testPassword,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Malformed JSON throws MalformedBackupPayloadException', () {
      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: 'not-a-json-payload',
          passphrase: testPassword,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('Missing envelope fields throws MalformedBackupPayloadException', () {
      final invalidEnvelope = jsonEncode({'safe_bloom_backup_version': 1});
      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: invalidEnvelope,
          passphrase: testPassword,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('Unsupported future version throws UnsupportedVaultVersionException', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      decoded['version'] = 99;
      decoded['safe_bloom_backup_version'] = 99;

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: jsonEncode(decoded),
          passphrase: testPassword,
        ),
        throwsA(isA<UnsupportedVaultVersionException>()),
      );
    });

    test('Unsupported format identifier throws MalformedBackupPayloadException', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      final Map<String, dynamic> decoded = jsonDecode(encryptedVault);
      decoded['format'] = 'UnrecognizedForeignVault';

      expect(
        () => BackupCryptoService.decryptVault(
          vaultJsonString: jsonEncode(decoded),
          passphrase: testPassword,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('validateAndParseDecryptedPayload validates valid payload schema and builds entities', () {
      final validPayload = jsonEncode({
        'version': 1,
        'profile': {
          'last_period_start': '2026-08-01T00:00:00.000Z',
          'avg_cycle_length': 28,
          'avg_period_length': 5,
        },
        'period_entries': [
          {'id': 'p1', 'timestamp': '2026-08-01T00:00:00.000Z', 'flow': 'heavy', 'notes': 'Heavy flow'}
        ],
        'symptom_entries': [
          {'id': 's1', 'timestamp': '2026-08-01T00:00:00.000Z', 'category': 'pain', 'type': 'Cramps', 'intensity': 3}
        ]
      });

      final parsed = BackupCryptoService.validateAndParseDecryptedPayload(validPayload);
      expect(parsed.profile.avgCycleLength, 28);
      expect(parsed.periodEntries.length, 1);
      expect(parsed.periodEntries.first.id, 'p1');
      expect(parsed.symptomEntries.length, 1);
      expect(parsed.symptomEntries.first.type, 'Cramps');
    });

    test('validateAndParseDecryptedPayload rejects payload with missing profile', () {
      final invalidPayload = jsonEncode({
        'version': 1,
        'period_entries': [],
      });

      expect(
        () => BackupCryptoService.validateAndParseDecryptedPayload(invalidPayload),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('validateAndParseDecryptedPayload rejects impossible cycle lengths', () {
      final invalidPayload = jsonEncode({
        'profile': {
          'last_period_start': '2026-08-01T00:00:00.000Z',
          'avg_cycle_length': 999, // Impossible
          'avg_period_length': 5,
        },
      });

      expect(
        () => BackupCryptoService.validateAndParseDecryptedPayload(invalidPayload),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('validateAndParseDecryptedPayload rejects invalid flow level', () {
      final invalidPayload = jsonEncode({
        'profile': {
          'last_period_start': '2026-08-01T00:00:00.000Z',
          'avg_cycle_length': 28,
          'avg_period_length': 5,
        },
        'period_entries': [
          {'id': 'p1', 'timestamp': '2026-08-01T00:00:00.000Z', 'flow': 'INVALID_FLOW'}
        ]
      });

      expect(
        () => BackupCryptoService.validateAndParseDecryptedPayload(invalidPayload),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });
  });
}
