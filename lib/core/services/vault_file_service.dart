import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'backup_crypto_service.dart';

class VaultFileException implements Exception {
  final String message;
  const VaultFileException(this.message);
  @override
  String toString() => 'VaultFileException: $message';
}

/// Service dedicated to handling .safebloom encrypted vault files on the filesystem,
/// system file picker dialogs, and native file sharing mechanisms.
class VaultFileService {
  /// Generates a standardized, privacy-preserving filename for the encrypted vault file.
  /// Format: SafeBloom-Vault-YYYY-MM-DD.safebloom
  static String generateVaultFileName([DateTime? date]) {
    final now = date ?? DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'SafeBloom-Vault-$year-$month-$day.${BackupCryptoService.kVaultFileExtension}';
  }

  /// Writes encrypted vault content to a .safebloom file in the target directory
  /// (defaults to the temporary system cache directory).
  static Future<File> createVaultFile({
    required String vaultContent,
    Directory? directory,
    String? customFileName,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final fileName = customFileName ?? generateVaultFileName();
    final filePath = p.join(dir.path, fileName);

    final file = File(filePath);
    await file.writeAsString(vaultContent, flush: true);
    return file;
  }

  /// Invokes the native OS share sheet to allow the user to save, air-drop,
  /// or transfer the .safebloom vault file securely.
  static Future<void> shareVaultFile(File file) async {
    if (!await file.exists()) {
      throw const VaultFileException('Vault file does not exist on disk.');
    }

    final xFile = XFile(
      file.path,
      mimeType: 'application/octet-stream',
      name: p.basename(file.path),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: 'Safe Bloom Encrypted Vault',
        text: 'Encrypted Safe Bloom backup file. Requires your vault password to decrypt.',
      ),
    );
  }

  /// Opens the native system file picker for the user to select an encrypted vault file.
  /// Uses FileType.any with in-memory data fetching to support Scoped Storage on all Android ROMs.
  static Future<File?> pickVaultFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final single = result.files.single;

    // 1. If bytes are available, write directly to local app cache to guarantee readable File access
    final bytes = single.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final tempDir = await getTemporaryDirectory();
      final safeName = single.name.isNotEmpty ? single.name : generateVaultFileName();
      final tempFile = File(p.join(tempDir.path, safeName));
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile;
    }

    // 2. If path is available, copy to app cache for reliable I/O
    final path = single.path;
    if (path != null && path.isNotEmpty) {
      final sourceFile = File(path);
      if (await sourceFile.exists()) {
        try {
          final tempDir = await getTemporaryDirectory();
          final safeName = single.name.isNotEmpty ? single.name : p.basename(path);
          final targetFile = File(p.join(tempDir.path, safeName));
          return await sourceFile.copy(targetFile.path);
        } catch (_) {
          return sourceFile;
        }
      }
    }

    return null;
  }

  /// Reads the content of a vault file from disk, performing size and envelope structural validation.
  static Future<String> readVaultFile(File file) async {
    if (!await file.exists()) {
      throw const VaultFileException('The specified vault file could not be found.');
    }

    final length = await file.length();
    if (length == 0) {
      throw const MalformedBackupPayloadException('The selected vault file is empty (0 bytes).');
    }

    if (length > BackupCryptoService.kMaxPayloadBytes) {
      throw const MalformedBackupPayloadException('Vault file exceeds maximum permitted size (10 MB).');
    }

    String content = await file.readAsString();
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    content = content.trim();

    // Validate envelope structure immediately
    BackupCryptoService.validateVaultEnvelope(content);
    return content;
  }

  /// Reads and validates raw bytes into a validated envelope string.
  static String readVaultFileFromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const MalformedBackupPayloadException('The selected vault file is empty (0 bytes).');
    }

    if (bytes.length > BackupCryptoService.kMaxPayloadBytes) {
      throw const MalformedBackupPayloadException('Vault file exceeds maximum permitted size (10 MB).');
    }

    String content = utf8.decode(bytes);
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    content = content.trim();

    BackupCryptoService.validateVaultEnvelope(content);
    return content;
  }

  /// Safely deletes staging/temporary vault files from the app cache directory.
  static Future<void> cleanTemporaryVaultFiles([File? specificFile]) async {
    try {
      if (specificFile != null && await specificFile.exists()) {
        final tempDir = await getTemporaryDirectory();
        if (p.isWithin(tempDir.path, specificFile.path) || specificFile.path.startsWith(tempDir.path)) {
          await specificFile.delete();
        }
      }
    } catch (_) {}
  }
}
