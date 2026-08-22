# Safe Bloom 🌸

<div align="center">

**Zero-Knowledge, Privacy-First Cycle, Fertility & Pregnancy Tracker**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Release](https://img.shields.io/badge/Release-v1.0.0-E05A47?style=for-the-badge)](https://github.com/DarkWolfHunter007/Safe-Bloom/releases/tag/v1.0.0)
[![Tests](https://img.shields.io/badge/Tests-242%2F242%20Passed%20(100%25)-4E8752?style=for-the-badge)](https://github.com/DarkWolfHunter007/Safe-Bloom)
[![Encryption](https://img.shields.io/badge/Database-SQLCipher%20AES--256-5B2C6F?style=for-the-badge)](https://www.zetetic.net/sqlcipher/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

*Your Cycle. Your Privacy. Your Power.*

</div>

---

## 🔒 The Safe Bloom Philosophy

Most period tracking apps treat intimate reproductive health data as a commercial commodity—uploading cycles, symptoms, sexual activity, and pregnancy status to cloud servers, third-party analytics trackers, and advertising networks.

**Safe Bloom is built differently.** It is engineered with a **strict Zero-Knowledge, Offline-First Architecture**:
- **Zero Cloud Servers:** No remote accounts, no cloud sync, and no user tracking.
- **Hardware-Backed AES-256 Encryption:** All database entries are encrypted locally with SQLCipher using keys generated in your device's hardware Keystore / Keychain.
- **Air-Gapped Privacy:** Data never leaves your physical phone unless you explicitly export an encrypted, password-protected backup file.
- **Emergency Nuclear Purge:** Instant, single-tap cryptographic wiping of all records, database files, and encryption keys.

---

## ✨ Features

### 🌸 1. Intelligent Menstrual & Fertility Prediction Engine
* **Moving-Average Dynamic Predictions:** Continuously learns and refines cycle length and period duration calculations based on your historical cycle data.
* **4-Phase Hormonal Timeline:** Visual daily breakdown and calendar highlighting for:
  * **Menstrual Phase** (Period days)
  * **Follicular Phase** (Estrogen rise & energy building)
  * **Ovulatory Phase** (Peak fertility window & conception probability)
  * **Luteal Phase** (Progesterone surge & PMS insights)
* **Spotting & Irregular Bleeding Isolation:** Dedicated spotting classification that logs light bleeding without distorting future cycle predictions or creating phantom periods.
* **Retroactive Cycle Management:** Edit, add, or delete historical periods with immediate downstream metric recalculations.

### 👶 2. Try to Conceive (TTC) & Pregnancy Companion Mode
* **Try to Conceive (TTC):** Pinpoints the 6-day fertile window with peak ovulation countdowns and fertility insights.
* **Full Pregnancy Tracking Mode:**
  * Gestational age calculation (weeks and days) from Last Menstrual Period (LMP) or conception.
  * Estimated Due Date (EDD) projections using clinical algorithms (Naegele's rule).
  * Trimester milestone tracker (1st, 2nd, and 3rd Trimesters).
  * Weekly baby growth comparisons with fruits and vegetables.
  * Trimester-tailored health, nutrition, and wellness guides.
  * **Intelligent Alarm Suppression:** Automatically suppresses menstrual and ovulation alarms while Pregnancy Mode is active.

### 📝 3. Daily Wellness, Symptom, & Hydration Logging
* **Comprehensive Symptom Library:** Categorized logging for Physical symptoms (cramps, headaches, bloating), Mood, Energy levels, Cervical Mucus, Flow intensity, and Custom notes.
* **Interactive Water Intake Tracker:** Daily hydration tracking with quick-add increments, daily goal progress rings, and historical stats.
* **Multi-Month Interactive Calendar:** Color-coded calendar with distinct visual markers for confirmed periods, predicted cycles, peak fertility, and daily symptom logs.

### 🔔 4. 100% Local Device Notifications & Reminders
* **Zero Cloud Push Infrastructure:** Alarms are scheduled directly with the native OS alarm clock manager (`flutter_local_notifications: 19.5.0` + `timezone: 0.10.1`).
* **Configurable Reminders:**
  * Period Prediction Alert (2 days prior).
  * Peak Fertility / Ovulation Alert (1 day prior).
  * Daily Health & Symptom Logging Reminder (customizable time).
  * Hydration Reminders (11:00 AM, 3:00 PM, 7:00 PM).
  * New Wellness Guides & Articles.
* **Discreet Lock Screen Mode:** Masks sensitive reproductive terms with neutral, private self-care prompts on lock screens.
* **Real-Time Permission Detection:** Directly queries Android `NotificationManagerCompat` to reflect OS permission state and provides one-tap system settings navigation.
* **Developer System Diagnostics:** In-app testing panel with individual alert preview chips for immediate verification.

### 📊 5. Medical-Grade Ob/Gyn Clinical Report Generator
* **Doctor Consultation Ready:** Generates professional, offline PDF summaries of cycle variance, flow statistics, spotting patterns, and logged symptoms.
* **Offline Rendering:** Built entirely on-device with zero cloud rendering or external network dependencies.

### 🗄️ 6. End-to-End Encrypted Vault Backup & Restore
* **Passphrase-Protected Encrypted Vaults:** Exports a zero-knowledge JSON vault encrypted using PBKDF2-HMAC-SHA256 and AES-GCM.
* **Air-Gapped Portability:** Move backups via offline storage, USB, or local file sharing.
* **Welcome Flow Restoration:** Single-tap backup vault import directly from the onboarding screen.

### 🛡️ 7. Biometric Security & Screen Privacy
* **Biometric App Lock:** Fingerprint, Face Unlock, and Touch ID authentication on app launch, app switching, and background resumption.
* **Screenshot & Screen Recording Prevention (`FLAG_SECURE`):** Configurable in Settings to block OS-level screen capture, screen recorders, and app-switcher thumbnail caching.
* **Database Recovery Protocol:** Built-in cryptographic integrity checks with automated repair and recovery paths if hardware keys become desynchronized.

---

## 🏗️ Architecture & Security Deep Dive

```
┌─────────────────────────────────────────────────────────────┐
│                       Safe Bloom UI                         │
│   (Flutter 3.x • Material Design 3 • Zero Cloud Push)      │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼                               ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│   Local Notification Engine   │ │     Encrypted Services     │
│   • AlarmManager (OS Level)  │ │   • BackupCryptoService    │
│   • Timezone 0.10.1 (Local)  │ │   • ScreenSecurityService  │
│   • Zero Remote Push Servers │ │   • BiometricAuthService   │
└──────────────┬───────────────┘ └─────────────┬──────────────┘
               │                               │
               ▼                               ▼
┌─────────────────────────────────────────────────────────────┐
│               Data Access & Repository Layer                │
│             (Offline-First TrackingRepository)              │
└──────────────────────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│             SQLCipher Database Engine (AES-256)             │
│   • PRAGMA cipher_page_size = 4096                          │
│   • PRAGMA kdf_iter = 64000                                 │
│   • Keys generated & sealed in Android Keystore / Keychain  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Codebase Structure

```
lib/
├── core/
│   ├── services/           # Encryption, storage, & local notification engine
│   ├── theme/              # Typography, spacing, & botanical color palette
│   └── utils/              # ID generation & cycle grouping utilities
├── features/
│   ├── insights/           # Health guides, wellness articles, & cycle charts
│   ├── onboarding/         # Zero-knowledge setup & vault restore
│   ├── security/           # Biometric lock, recovery views, & screen security
│   ├── settings/           # Notification preferences, purge, & vault export
│   └── tracking/           # Core domain models, cycle calculator, & views
└── main.dart               # Startup pipeline & non-blocking initialization
```

---

## 🚀 Getting Started & Local Development

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
* [Dart SDK](https://dart.dev/get-started) (`>= 3.0.0 < 4.0.0`)
* Android SDK (API Level 35) & JDK 17+
* Xcode 15+ (for iOS development)

### Setup & Run
```bash
# 1. Clone the repository
git clone https://github.com/DarkWolfHunter007/Safe-Bloom.git
cd Safe-Bloom

# 2. Install dependencies
flutter pub get

# 3. Run full test suite
flutter test

# 4. Run the app on a connected device/emulator
flutter run
```

### Running Test Suite
Safe Bloom includes **242 unit and integration tests** verifying cycle calculations, SQLCipher database encryption, backup vaults, data purges, and local notifications:
```bash
flutter test
```

---

## 📦 Building Production APKs

Safe Bloom utilizes full R8 minification, bytecode desugaring (`desugar_jdk_libs: 2.1.4`), and resource shrinking to keep binaries lightweight:

```bash
# Build architecture-split release APKs (Recommended)
flutter build apk --split-per-abi --release

# Output binaries:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (26.1 MB - Modern 64-bit devices)
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (22.3 MB - 32-bit legacy devices)
# build/app/outputs/flutter-apk/app-x86_64-release.apk     (28.1 MB - Emulators / ChromeOS)
```

---

## 📋 Changelog
For a detailed breakdown of features, improvements, and fixes in each version, view our [Changelog](changelog/v1.0.0.md).

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.