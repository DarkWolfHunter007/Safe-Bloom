class LegalContent {
  static const String privacyPolicy = '''
# Safe Bloom — Privacy Policy

Last updated: August 2026

## Core Privacy Architecture: "Your Data. Your Cloud. Zero Servers."

Safe Bloom is built on a strict privacy-first technical architecture designed to ensure that your sensitive reproductive health data remains strictly on your personal device.

### 1. Local Encrypted Storage
All period logs, flow intensities, symptom entries, notes, and cycle parameters are stored in an on-device SQLite database encrypted with SQLCipher using 256-bit AES encryption.

### 2. Encryption Key Security
The database encryption key is generated randomly on your device and stored in hardware-backed secure storage (iOS Keychain and Android Keystore / EncryptedSharedPreferences). Safe Bloom developers have no access to your encryption key or health data.

### 3. Zero Accounts & Zero Trackers
- No account registration, email address, or name is required.
- No analytics SDKs (such as Firebase Analytics, Mixpanel, or Amplitude) are included in the application.
- No advertising tracking identifiers (IDFA or GAID) are collected or processed.

### 4. Network Connections
Safe Bloom operates 100% offline for core tracking functionality. User-initiated external actions (such as opening external URLs via web browser or using platform print services) route through standard OS handlers.

### 5. Medical & Contraception Disclaimer
Cycle predictions and fertility windows calculated by Safe Bloom are mathematical estimates based on historical data. They are not medical advice or a substitute for contraception or professional medical diagnosis.
''';

  static const String termsOfService = '''
# Safe Bloom — Terms of Service

Last updated: August 2026

### 1. Agreement & Privacy Commitment
By downloading and using Safe Bloom, you agree to these Terms. Safe Bloom is designed to operate locally on your device with local SQLCipher hardware encryption.

### 2. Informational & Estimation Purpose Only
Safe Bloom provides cycle tracking and estimation based on historical user entries. Predictions are NOT guaranteed and MUST NOT be relied upon as a method of contraception or family planning without consulting a healthcare provider.

### 3. User Responsibility for Data Backups
Because Safe Bloom operates without central cloud servers, you are solely responsible for maintaining and backing up your device and data exports.

### 4. Limitation of Liability
Safe Bloom is provided "AS IS" without warranties of any kind. Under no circumstances shall the developers be liable for health decisions, data loss resulting from device malfunction, or un-backed-up device wipes.
''';

  static const String medicalDisclaimer =
      'Safe Bloom cycle predictions and fertility windows are mathematical estimates based on historical data. They are not a substitute for medical advice, contraception, or clinical diagnosis. Always consult a qualified healthcare provider for medical guidance.';
}
