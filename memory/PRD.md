# Product Requirements Document (PRD) — Safe Bloom

**App Name:** Safe Bloom  
**Platforms:** iOS & Android (Cross-Platform via Flutter)  
**Business Model:** Freemium (Subscriptions + Direct-Sold Flat-Rate Sponsorship Ad Gates)  
**License:** MIT (Public GitHub repository, attribution required)

---

## 1. Product Vision & Objective

To build the most trusted period and cycle tracking app across iOS and Android by proving that intimate health data never leaves the user's control.

**The Core Differentiator:** 100% zero-server architecture. All user data is stored locally in a **SQLCipher 256-bit AES encrypted database**. Encryption keys are saved in hardware-backed storage (**iOS Keychain / Android Keystore**). Cloud backups are encrypted and saved directly to the user's personal **Google Drive** or **iCloud**.

**Marketing Headline:** *"Your data. Your cloud. Zero servers."*

---

## 2. Technical Architecture (Zero-Server & Cross-Platform)

- **Framework:** Flutter 3.x (Dart 3.x)
- **Local DB:** `sqflite_sqlcipher` (AES-256 encrypted SQLite)
- **Encryption Key Storage:** `flutter_secure_storage` (iOS Keychain & Android Keystore)
- **Cloud Backup:** 
  - Android & iOS: Google Drive REST API (`appDataFolder` scope).
  - iOS: iCloud Drive integration.
- **Authentication & Backend:** NONE. 100% anonymous.
- **HealthKit / Health Connect:** EXCLUDED for MVP to maintain zero compliance friction with ad gates.

---

## 3. Monetization & Ad Logic

### A. Subscriptions (In-App Purchases)
- `in_app_purchase` package (Apple App Store StoreKit 2 & Google Play Billing).
- Monthly ($4.99) / Annual ($29.99).
- "Restore Purchases" button on all paywalls.

### B. Direct-Sold Sponsorship Gates (Flat-Rate)
- **No 3rd-party Ad SDKs (No AdMob).**
- **Remote Config (JSON):** Lightweight JSON fetched from GitHub Pages on launch.
- **Offline Caching:** Standard HTTP cache & local file storage for sponsor images.
- **Fail-Open Fallback:** If network fails or `active: false`, daily insight unlocks immediately for 24h.
- **Ad Gate UX:** 5-second countdown with static sponsor image -> 24h unlock timestamp set in secure storage.

---

## 4. Feature Breakdown (MVP Scope)

### 4.1 Onboarding
1. **Screen 1 (Privacy Promise):** "Your data stays on your phone. Backups go to your personal cloud."
2. **Screen 2 (Setup):** Date picker for last period, average cycle/period length steppers.
3. **Screen 3 (Paywall):** Premium value proposition with "Start Free" and "Restore Purchases".

### 4.2 Core Tracking
- **Period Log:** Flow levels (Spotting, Light, Medium, Heavy) with timestamps for multiple daily logs.
- **Symptom Log:** Tag-based categories (Pain, Mood, Energy, Sleep, Skin, Intimate, Exercise). Intensity 1–5 + notes.
- **Cycle Engine:** Pure Dart algorithm calculating predictions via rolling 3-cycle average.

### 4.3 Action Plan Insights (Ad-Gated)
- Phase-aligned tips (Menstrual, Follicular, Ovulation, Luteal) for diet, fitness, and lifestyle.
- Gated behind 5-second sponsor ad for free users; seamless for Premium.

### 4.4 Encrypted Cloud Backup & Restore
- Encrypted DB blob uploaded directly to user's Google Drive `appDataFolder` or iCloud.
- **Restore:** Fresh install authenticates Google Drive / iCloud -> downloads blob -> decrypts locally using hardware key -> restores DB.
- **Settings -> Data Erasure:** Option to wipe local data or local + cloud backup.

---

## 5. App Store & Google Play Compliance

- **App Privacy Label:** "Data Not Collected".
- **Zero Tracking Frameworks:** No ATT / IDFA or Google Advertising ID requests.
- **Analytics:** Anonymous local event counters via secure storage. Aggregate metrics via App Store Connect & Google Play Console only.

---

## 6. Phase 1 Launch Roadmap (10 Weeks)

- **Weeks 1–2:** Flutter architecture setup, Dart data models, SQLCipher database helper.
- **Weeks 3–4:** CycleEngine Dart logic, unit tests, and Core Tracking UI.
- **Weeks 5–6:** Encrypted Google Drive & iCloud backup/restore integration.
- **Weeks 7–8:** `in_app_purchase` setup & Remote Config Ad Gate system.
- **Weeks 9–10:** Android & iOS beta testing, polish, and App Store / Google Play submission.
