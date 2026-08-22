import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService Unit Tests', () {
    const testJson = '{"profile":{"avg_cycle_length":28},"period_entries":[{"id":"1","flow":"heavy"}]}';
    const testPassword = 'SafeBloomVaultPassword2026!';

    test('Encrypt and decrypt roundtrip matches original plaintext perfectly', () {
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: testJson,
        passphrase: testPassword,
      );

      expect(encryptedVault, isNotEmpty);
      expect(encryptedVault, contains('ENCRYPTED_VAULT_V1'));
      expect(encryptedVault, contains('AES-256-CTR-HMAC-SHA256'));

      final decrypted = BackupCryptoService.decryptVault(
        vaultJsonString: encryptedVault,
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
      // Flip one bit
      originalCipher[0] ^= 0x01;
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
  });
}
