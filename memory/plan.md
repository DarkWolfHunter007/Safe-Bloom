# Master Development Plan & Roadmap — Safe Bloom (Flutter Edition)

## Roadmap Overview (10 Weeks to Launch)

```
[Phase 1: Flutter Foundation & Models] ──► [Phase 2: Core Tracking & CycleEngine] ──► [Phase 3: Encryption & Cloud Backup]
                                                                                              │
[Phase 6: Play Store & App Store Launch] ◄── [Phase 5: Onboarding & Settings] ◄── [Phase 4: StoreKit / Google Billing & Ads]
```

---

## Milestone Breakdown

### Phase 1: Flutter Setup & Database (Weeks 1–2)
- [ ] Create Flutter project (`pubspec.yaml`, `lib/main.dart`).
- [ ] Configure `sqflite_sqlcipher` and `flutter_secure_storage`.
- [ ] Implement Dart data models: `UserProfile`, `PeriodEntry`, `SymptomEntry`, `CyclePrediction`, `JournalNote`.
- [ ] Build `DatabaseHelper` CRUD operations.

### Phase 2: Core Logic & Tracking UI (Weeks 3–4)
- [ ] Implement `CycleEngine` pure Dart logic (rolling 3-cycle average prediction & phase calculator).
- [ ] Write unit tests in `test/cycle_engine_test.dart`.
- [ ] Build `CalendarView` (month grid with phase highlights).
- [ ] Build `PeriodLoggerSheet` & `SymptomPicker`.
- [ ] Build `JournalView`.

### Phase 3: Cloud Backup & Restore (Weeks 5–6)
- [ ] Integrate Google Drive REST API (`googleapis` / `google_sign_in`).
- [ ] Integrate iCloud backup support for iOS.
- [ ] Build backup upload & fresh restore flow.

### Phase 4: Monetization & Ad Gate (Weeks 7–8)
- [ ] Integrate `in_app_purchase` (Apple StoreKit 2 + Google Play Billing).
- [ ] Implement `AdConfigService` (remote JSON, `http` cache, fail-open logic).
- [ ] Build `AdGateDialog` (5-second sponsor image countdown).

### Phase 5: Onboarding, Settings & Release (Weeks 9–10)
- [ ] Build 3-screen `OnboardingView`.
- [ ] Build `SettingsView` (Privacy policy, cloud backup toggle, data erasure).
- [ ] Test on Android Emulator & physical devices.
- [ ] Submit to Apple App Store & Google Play Store.

---

## Current Status Tracker

- **Current Active Phase:** Phase 1 (Flutter Architecture & Memory Specification Complete)
- **Next Task:** Flutter project initialization (`pubspec.yaml`, `lib/models`, `lib/services`)
