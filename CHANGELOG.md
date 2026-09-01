# Changelog

All notable changes to **Safe Bloom** are documented in this file and detailed in the [changelog/](changelog/) directory.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [[v1.1.0]](changelog/v1.1.0.md) - 2026-09-01

### Added
- **Single-File Encrypted Vault (`.safebloom`)**: Full file-based encrypted backup and restore system (`format: "SafeBloomVault"`, `version: 1`, `algorithm: "AES-256-CTR-HMAC-SHA256"`).
- **Native OS Share Sheet Integration**: Export backups directly to device files, cloud drives, or device-to-device transfer using `share_plus` without clipboard interaction.
- **Native System File Picker**: Browse and select `.safebloom` backup files directly using `file_picker`.
- **Pre-Decryption Envelope Validation**: Automatic 10MB size limit and container structural validation before password prompt.
- **Strict Domain Schema Validation**: Clinical bounds validation for `UserProfile`, `PeriodEntry`, and `SymptomEntry` before database writes.
- **Comprehensive Test Suite**: Added 10 extensive integration and tampering tests in `test/encrypted_vault_file_export_import_test.dart` (268 total tests passing).

### Changed
- **Settings UI**: Replaced clipboard copy/paste buttons with `EXPORT ENCRYPTED VAULT` and `IMPORT ENCRYPTED VAULT` workflows.
- **Database Recovery UI**: Upgraded emergency recovery view to pick `.safebloom` files directly from disk.
- **Atomic Transaction Commit**: `DatabaseHelper.executeAtomicImport` now safely executes inside a single ACID transaction (`clearExisting: true`), guaranteeing existing data is never destroyed prematurely if validation or decryption fails.
- **Dependencies**: Added `file_picker: ^11.0.3`, `share_plus: ^12.0.2`, and `path_provider: ^2.1.6`.

### Security
- Eliminated clipboard leaks during vault export and import.
- Maintained PBKDF2-HMAC-SHA256 (20,000 iterations) and AES-256-CTR with constant-time HMAC-SHA256 MAC verification.
- Maintained backward compatibility with legacy `ENCRYPTED_VAULT_V1` payloads.

---

## [[v1.0.0]](changelog/v1.0.0.md) - 2026-08-22

### Added
- Initial public release of Safe Bloom — Offline-first, Zero-Knowledge Cycle, Fertility & Pregnancy Tracker.
- SQLCipher AES-256 local database encryption with Android Keystore / iOS Keychain hardware keys.
- Biometric App Lock screen (Fingerprint, Face Unlock, Touch ID).
- Screenshot and screen recording prevention (`FLAG_SECURE`).
- 4-Phase hormonal timeline and moving-average cycle prediction engine.
- Spotting and irregular bleeding isolation.
- Try to Conceive (TTC) mode and Pregnancy Companion tracking mode.
- 100% local device notifications and alarms via OS AlarmManager.
- Medical-grade Ob/Gyn PDF consultation report generator.
- Single-tap emergency nuclear purge.
