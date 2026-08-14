# Safe Bloom — Next MVP Implementation Plan

```
Based on:  Next MVP PRD (32 sections)
Audit ref: AUDIT_REPORT.md (40 sections)
Date:      2026-08-13
Branch:    main  |  Commit: 5d9c261
```

---

## How to read this document

Each task has:
- **What** — the concrete deliverable
- **Files touched** — existing files modified
- **New files** — new files to create
- **Depends on** — tasks that must complete first
- **Done when** — definition of done (no placeholder behaviour permitted)

Tasks are ordered P0 → P3. Work P0s first, P1s second. P2/P3 can be parallelised once P0+P1 are green.

---

## P0 — Must fix before feature expansion

Active regressions, data-integrity failures, security issues, or hard release blockers. Nothing in P1 should begin until all P0s are resolved.

---

### P0-1 · Fix quick-symptom deletion DB sync bug

**What**
`TodayView._toggleQuickSymptom` removes symptoms from `_todaySymptoms` local list but never calls the database. On next load, the "deleted" symptom reappears. `DatabaseHelper` has no `deleteSymptomEntry` method at all.

**Files touched**
- `lib/features/tracking/data/datasources/database_helper.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/tracking/presentation/views/today_view.dart`

**Changes**
1. Add `deleteSymptomEntry(String id)` to `DatabaseHelper` and `TrackingRepository`.
2. In `TodayView._toggleQuickSymptom`: when toggling off, call `_repository.deleteSymptomEntry(existing.id)`. Adjust `_todaySymptoms` from `List<String>` to `List<SymptomEntry>` so IDs are available.

**Done when** Removing a chip, restarting the app, and re-opening Today view shows the symptom absent.

---

### P0-2 · Remove "encrypted" label from plaintext export

**What**
`exportEncryptedUserDataJson` produces plaintext JSON. Every callsite labels it "Encrypted Backup." False advertising on a privacy-first product.

**Files touched**
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/settings/presentation/views/settings_view.dart`

**Changes**
1. Rename method to `exportUserDataJson`.
2. Change dialog title to `"Export Data Backup"`, SnackBar to `"Backup copied — keep this data safe"`.
3. Add warning: `"This export is not password-protected. Store it securely."`.

**Done when** No UI string anywhere claims the clipboard JSON is encrypted.

---

### P0-3 · Implement "Mark Period Ended" functionality

**What**
The "MARK PERIOD ENDED TODAY" button shows a SnackBar and does nothing to the database.

**Files touched**
- `lib/features/tracking/presentation/views/today_view.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/tracking/data/datasources/database_helper.dart`

**Changes**
1. Add `getPeriodEntriesByDateRange(DateTime from, DateTime to)` to `DatabaseHelper`.
2. Add `endCurrentPeriod(DateTime endDate)` to `TrackingRepository`: deletes period entries in the current cycle group that fall after `endDate`, then recalculates and saves averages.
3. In `TodayView._togglePeriodToday(true)`: call `_repository.endCurrentPeriod(DateTime.now())`, then reload. Guard against ending before starting.

**Done when** Tapping "Mark Period Ended", restarting app, and checking calendar shows no period entries beyond the end date.

---

### P0-4 · Collision-resistant IDs

**What**
IDs use `DateTime.now().millisecondsSinceEpoch.toString()`. Two entries in the same millisecond silently overwrite each other.

**New files**
- `lib/core/utils/id_generator.dart` — `IdGenerator.newId()` using milliseconds + `Random.secure().nextInt(999999)`.

**Files touched**
- `lib/features/tracking/presentation/views/today_view.dart`
- `lib/features/tracking/presentation/views/calendar_view.dart`
- `lib/features/onboarding/presentation/views/onboarding_view.dart`

**Done when** No ID in the app is a bare millisecond timestamp.

---

### P0-5 · Consistent date-only handling

**What**
Date queries across the codebase mix `DateTime.now()` (includes time) with date-only comparisons. Querying calendar day boundaries is fragile.

**New files**
- `lib/core/utils/safe_bloom_date_utils.dart` — `dateOnly(DateTime)`, `dateKey(DateTime)`.

**Files touched**
- `lib/features/tracking/data/datasources/database_helper.dart`
- All callers constructing `DateTime` for DB queries.

**Changes**
Period entry timestamps stored as `dateOnly(now).toIso8601String()`. All date queries use `SafeBloomDateUtils.dateOnly()`.

**Done when** Logging at 23:59 and querying by that calendar day always returns the entry.

---

### P0-6 · Screenshot and app-switcher protection

**What**
Health data is visible in Android recent-apps and iOS app switcher.

**Files touched**
- `android/app/src/main/kotlin/.../MainActivity.kt`
- `ios/Runner/AppDelegate.swift`

**Changes**
1. Android: `window.setFlags(FLAG_SECURE, FLAG_SECURE)` in `MainActivity`.
2. iOS: add opaque overlay in `applicationDidEnterBackground`, remove in `applicationWillEnterForeground`.

**Done when** App content not visible in screenshots or switcher thumbnails.

---

### P0-7 · Remove non-functional settings toggles

**What**
"Anonymous Mode" and "Zero-Knowledge Backup" change only in-memory state. PRD: every control must work or be removed.

**Files touched**
- `lib/features/settings/presentation/views/settings_view.dart`
- `lib/features/tracking/domain/entities/user_profile.dart`
- `lib/features/tracking/data/datasources/database_helper.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`

**Changes**
1. Remove "Zero-Knowledge Backup" toggle. Replace slot with Export/Import buttons (from P1-3/P1-4).
2. Remove "Anonymous Mode" toggle. Replace with static info row: `"Safe Bloom collects no personal identifiers."`.
3. Remove `isCloudBackupEnabled` from `UserProfile`, DB schema (migration to version 2).

**Done when** Settings contains no toggle that changes no persisted behaviour.

---

### P0-8 · Android backup rules

**What**
`android:allowBackup` defaults to `true`. The SQLCipher DB and its key could both appear in ADB/cloud backups.

**New files**
- `android/app/src/main/res/xml/backup_rules.xml`

**Files touched**
- `android/app/src/main/AndroidManifest.xml`

**Changes**
Create backup rules excluding `safebloom_encrypted.db` and the EncryptedSharedPreferences file. Reference in `<application android:fullBackupContent="@xml/backup_rules">`.

**Done when** ADB backup does not include the SQLCipher DB or its key.

---

## P1 — Core MVP completion

---

### P1-1 · Period editing UI

**What**
Users cannot correct any period entry — date, flow, or notes.

**New files**
- `lib/features/tracking/presentation/views/edit_period_view.dart`

**Files touched**
- `lib/features/tracking/data/datasources/database_helper.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/tracking/presentation/views/calendar_view.dart`

**Changes**
1. Add `updatePeriodEntry(PeriodEntry)` to `DatabaseHelper` and `TrackingRepository` (upsert + recalculate averages).
2. `EditPeriodView`: date picker (past dates only, max 18 months back), flow chip selector, notes field, "SAVE CHANGES" + "DELETE ENTRY" (with confirmation dialog).
3. Calendar selected-day detail card: "Edit" button opens `EditPeriodView` with pre-populated entry.

**Depends on** P0-4, P0-5

**Done when** Edited entry survives restart. Calendar, dashboard, and predictions all reflect the change.

---

### P1-2 · Symptom editing, deletion, and real intensity

**What**
Symptoms can only be added. Intensity is hardcoded to 3. No delete.

**New files**
- `lib/features/tracking/presentation/widgets/edit_symptom_sheet.dart`

**Files touched**
- `lib/features/tracking/data/datasources/database_helper.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/tracking/presentation/views/calendar_view.dart`
- `lib/features/tracking/presentation/views/today_view.dart`
- `lib/features/tracking/presentation/widgets/period_logger_sheet.dart`

**Changes**
1. Add `updateSymptomEntry` and `deleteSymptomEntry` (P0-1 adds delete) to `DatabaseHelper` and `TrackingRepository`.
2. Add intensity slider (1–5) to `PeriodLoggerSheet` and `EditSymptomSheet`.
3. `EditSymptomSheet`: type label, intensity slider, notes field, "DELETE SYMPTOM" with confirmation.
4. Calendar symptom list and Today symptom list: tap-to-edit opens `EditSymptomSheet`.

**Depends on** P0-1

**Done when** Intensity saves a real value (not 3). Deleting a symptom removes it from DB. Edit persists across restart.

---

### P1-3 · Encrypted file export

**What**
Clipboard plaintext export must be replaced by an actual encrypted file.

**New packages**
- `encrypt: ^5.0.3`
- `share_plus: ^10.0.0`
- `path_provider: ^2.1.3`

**New files**
- `lib/core/services/backup_crypto_service.dart`

**Files touched**
- `pubspec.yaml`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/settings/presentation/views/settings_view.dart`

**Changes**
1. `BackupCryptoService`: AES-256-GCM encrypt/decrypt. Random IV prepended. Envelope: `{version, algo, iv, data}`.
2. `TrackingRepository.exportEncryptedBackupBytes(String password)`: builds full data map (including `daily_logs`), JSON-encodes, encrypts, returns `Uint8List`.
3. Settings: remove clipboard export. Add "Export Encrypted Backup" → PIN dialog → file written as `safebloom_backup_<date>.sbb` → `share_plus` share sheet.

**Depends on** P0-2

**Done when** Export file cannot be opened as JSON. Share sheet appears. File contains all data including water logs.

---

### P1-4 · Data import and restore

**What**
No import capability. Export without import is not a backup.

**New packages**
- `file_picker: ^8.1.2`

**New files**
- `lib/core/services/backup_import_service.dart`

**Files touched**
- `pubspec.yaml`
- `lib/features/tracking/data/repositories/tracking_repository.dart`
- `lib/features/settings/presentation/views/settings_view.dart`

**Changes**
1. `BackupImportService`: `validate`, `decryptAndParse` (typed exceptions: `WrongPasswordException`, `CorruptedBackupException`, `UnsupportedVersionException`), `schemaValidate`.
2. `TrackingRepository.restoreFromBackup(Map data)`: optional full-wipe before restore. Inserts all records. Recalculates averages.
3. Settings: "Restore from Backup" → file picker → password → summary screen → confirmation → restore.

**Depends on** P1-3 (defines file format)

**Done when** Export on one device, wipe, restore on same device (simulating new install) with correct password recovers all data. Wrong password shows error without touching data.

---

### P1-5 · Local notifications

**What**
No notification system exists.

**New packages**
- `flutter_local_notifications: ^18.0.0`
- `timezone: ^0.9.4`

**New files**
- `lib/core/services/notification_service.dart`

**Files touched**
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `lib/features/settings/presentation/views/settings_view.dart`
- `lib/features/onboarding/presentation/views/onboarding_view.dart`
- `lib/features/tracking/data/repositories/tracking_repository.dart`

**Changes**
1. `NotificationService`: init, `schedulePeriodReminder`, `cancelAllNotifications`, `rescheduleAll(UserProfile)`. Uses `TZDateTime`. Handles boot-receiver for Android restart.
2. Android: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `<receiver>` for boot, notification channel.
3. iOS `Info.plist`: `NSUserNotificationsUsageDescription`.
4. Settings "Notifications" section: enable toggle, days-before selector, reminder time picker — all persisted to `flutter_secure_storage`.
5. `TrackingRepository`: call `NotificationService.instance.rescheduleAll(profile)` after any write that changes the prediction.
6. Onboarding: optional permission request step.

**Depends on** P0-3, P0-5

**Done when** Period reminder arrives at correct time. Disable cancels all. Logging new period reschedules. After device restart, notifications restored.

---

### P1-6 · Cycle history screen

**What**
No way to view past periods as a list with statistics.

**New files**
- `lib/features/tracking/presentation/views/cycle_history_view.dart`

**Files touched**
- `lib/features/insights/presentation/views/insights_view.dart`

**Changes**
1. `CycleHistoryView`: groups periods into cycles (via P3-1 shared utility), displays scrollable list with per-cycle date, length, period length. Header shows: avg cycle, avg period, shortest, longest, regularity.
2. Embedded in Insights as a second tab/segment alongside the charts.

**Depends on** P1-1, P3-1

**Done when** User sees all historical cycles with accurate statistics matching `CycleCalculator` outputs.

---

### P1-7 · Honest empty states in Insights

**What**
When no symptom data exists, 6 hardcoded fake data points are rendered labeled "Sample symptom distribution." PRD: "Do not substitute fake health statistics."

**Files touched**
- `lib/features/insights/presentation/widgets/cycle_charts_widget.dart`

**Changes**
1. Remove all hardcoded sample symptom entries.
2. Show empty-state widget: `"Log symptoms for 2+ cycles to see your personal symptom trends."`.
3. Cycle trend chart: show only real data points. Add label when <2 cycles exist: `"Need more data — tracking since [date]."`.
4. Add symptom-by-phase breakdown once ≥2 cycles are logged.

**Depends on** P3-1

**Done when** No fabricated statistics anywhere. Empty state is informative and honest.

---

### P1-8 · Complete settings

**What**
Settings must contain only functional controls. PRD §17.

**Files touched**
- `lib/features/settings/presentation/views/settings_view.dart`

**New files**
- `lib/features/settings/presentation/views/privacy_policy_view.dart`
- `lib/features/settings/presentation/views/terms_view.dart`

**Settings rows after P0-7 cleanup:**

| Row | State |
|---|---|
| Biometric / PIN lock | Functional — keep |
| Notifications | → notification prefs (P1-5) |
| Export Encrypted Backup | → export flow (P1-3) |
| Restore from Backup | → import flow (P1-4) |
| OB-GYN PDF Report | Functional — keep |
| Privacy Policy | → `PrivacyPolicyView` |
| Terms of Service | → `TermsView` |
| Medical Disclaimer | Inline or dedicated view |
| App Version | Static row |
| Purge All My Data | Functional — keep |

**Depends on** P0-7, P1-3, P1-4, P1-5, P1-9

**Done when** Every row navigates somewhere or performs a real action. Nothing resets on restart.

---

### P1-9 · Privacy Policy, Terms, and Medical Disclaimer

**New files**
- `lib/features/settings/presentation/views/privacy_policy_view.dart`
- `lib/features/settings/presentation/views/terms_view.dart`
- `lib/core/content/legal_content.dart`

**Changes**
1. `LegalContent`: static constants for privacy policy (accurately describes SQLCipher, zero servers, font CDN caveat, export behaviour), terms, and medical disclaimer.
2. `PrivacyPolicyView` and `TermsView`: branded header, scrollable body, close button.
3. Medical disclaimer: `"Safe Bloom predictions are estimates. Not a substitute for medical advice."` — dismissible on first prediction view, permanently accessible from Settings.
4. Onboarding Step 1: tappable "Terms" and "Privacy Policy" links.

**Done when** Legal screens accessible from Settings and onboarding. Text accurately reflects implementation.

---

### P1-10 · Save onboarding goal + fix option mismatch

**Files touched**
- `lib/features/tracking/domain/entities/user_profile.dart`
- `lib/features/tracking/data/datasources/database_helper.dart`
- `lib/features/onboarding/presentation/views/onboarding_view.dart`

**Changes**
1. Add `preferredGoal` (`String?`) to `UserProfile`. DB migration (version 3).
2. Fix default: `'Track Cycle & Symptoms'` → `'🌸 Track Cycle & Symptoms'` to match option strings.
3. Save selected goal on onboarding complete.

**Depends on** P0-7 (same migration)

**Done when** Onboarding goal survives restart.

---

## P2 — Production preparation

---

### P2-1 · Bundle fonts locally

**What**
`google_fonts` makes HTTP requests to `fonts.gstatic.com`, leaking device IP to Google.

**Changes**
1. Download OFL font files: Cormorant Garamond (Regular, Medium, SemiBold, Italic) and Montserrat (Regular, Medium, SemiBold, Bold) into `assets/fonts/`.
2. Declare in `pubspec.yaml` under `flutter.fonts`.
3. Replace `GoogleFonts.cormorantGaramond(...)` / `GoogleFonts.montserrat(...)` in `app_typography.dart` with `TextStyle(fontFamily: '...')`.
4. Remove `google_fonts` from dependencies.

**Done when** Correct fonts render with zero network access. No `fonts.gstatic.com` requests.

---

### P2-2 · Production application ID

**Changes**
- Android `build.gradle.kts`: `applicationId = "com.safebloom.app"` (or chosen ID).
- iOS: set Bundle Identifier in Xcode project.

---

### P2-3 · Release signing

- Android: generate release keystore, configure `signingConfigs.release`.
- iOS: distribution certificate + provisioning profile in Xcode.

---

### P2-4 · iOS App Privacy Manifest

**New files**
- `ios/Runner/PrivacyInfo.xcprivacy`

Declare: `NSPrivacyTracking: false`, no collected data types, required API types for `flutter_secure_storage` and `sqflite`.

---

### P2-5 · Splash screen

Configure branded splash (Safe Bloom logo on `AppColors.lightBackground`) using `flutter_native_splash` or native configuration. No white flash on launch.

---

### P2-6 · Fix portrait/landscape inconsistency

Remove landscape orientations from `ios/Runner/Info.plist` to match the `setPreferredOrientations([portraitUp, portraitDown])` call in `main.dart`.

---

## P3 — Quality and architecture

---

### P3-1 · Extract cycle-grouping utility

**New files**
- `lib/core/utils/cycle_group_utils.dart`

```dart
class CycleGroupUtils {
  static List<List<PeriodEntry>> groupIntoCycles(
    List<PeriodEntry> entries, {int gapDays = 2}) { ... }
}
```

Replace 4 copy-pasted implementations in: `tracking_repository.dart`, `cycle_calculator.dart`, `cycle_charts_widget.dart`, `pdf_report_generator.dart`.

---

### P3-2 · Extract month-name utility

Add `SafeBloomDateUtils.monthAbbr(int month)` (P0-5 file). Remove 4 private `_getMonthName` copies.

---

### P3-3 · Reduce tab-switch DB reads

In `home_shell_view.dart`: introduce a dirty flag. Only call `refresh()` when data has changed since the tab was last active.

---

### P3-4 · Optimise calendar phase calculation

Pre-compute `_predictedDates` once in `CalendarView.refresh()`. Do not regenerate the full `Set<DateTime>` per cell per paint.

---

### P3-5 · CycleCalculator unit tests (≥25 cases)

**New files** — `test/cycle_calculator_test.dart`

Cover: `getCurrentCycleDay`, `getCyclePhase`, `getDaysUntilNextPeriod`, `calculateAveragesFromEntries`, `getPredictedPeriodDates`, `groupIntoCycles`. Include: leap year, month boundary, empty list, single cycle, irregular gaps.

---

### P3-6 · DatabaseHelper tests

**New files** — `test/database_helper_test.dart`

Cover: insert, read, update, delete for all tables; wipe; key handling; same-ID conflict resolution.

---

### P3-7 · Export/import round-trip tests

**New files** — `test/backup_test.dart`

Cover: encrypted bytes not plain JSON, correct password decrypts, wrong password throws, schema validation, full round-trip (export → import → verify records).

---

### P3-8 · Integration test: critical user journey

**New files** — `integration_test/app_test.dart`

Full journey per PRD §23: install → onboard → log → add symptoms → calendar → edit → delete → export → import → notifications → lock/unlock.

---

### P3-9 · Extend onboarding date picker

Change `firstDate` from 90 days back to 548 days (~18 months) back.

---

### P3-10 · Resolve ad gate

**Option A (recommended):** Delete `ad_gate_dialog.dart`. Show Daily Action Plan content directly. No gate.

**Option B:** Convert to clearly-labeled static sponsorship with real URL, no countdown, no SDK.

Product owner decision required. Option A is safer for the privacy promise.

---

## DB Migration Plan

| Migration | Version | Change |
|---|---|---|
| P0-7 | → 2 | Recreate `user_profile` without `is_cloud_backup_enabled` |
| P1-10 | → 3 | `ALTER TABLE user_profile ADD COLUMN preferred_goal TEXT` |

---

## New Packages Summary

| Package | Purpose | Task |
|---|---|---|
| `encrypt: ^5.0.3` | AES-256-GCM backup encryption | P1-3 |
| `share_plus: ^10.0.0` | Platform share sheet | P1-3 |
| `path_provider: ^2.1.3` | Temp file path | P1-3 |
| `file_picker: ^8.1.2` | Import file selection | P1-4 |
| `flutter_local_notifications: ^18.0.0` | Local notifications | P1-5 |
| `timezone: ^0.9.4` | TZ-aware scheduling | P1-5 |
| `flutter_native_splash: ^2.4.1` | Splash screen | P2-5 |

**Removed:** `google_fonts` (P2-1)

---

## Dependency Graph

```
P0-5 (dates) ──────────────────────────────────────────┐
P0-4 (IDs) ──────────────────┐                         │
P0-1 (symptom del) ──┐       │                         │
                     ↓       ↓                         ↓
P0-7 (toggles) ──→ P1-2 ←── P1-1 (period edit) ←── P1-6 (history)
P0-2 (export) ───→ P1-3 (enc export) ──→ P1-4 (import)
P0-3 (end period) → P1-5 (notifications)
P1-3+P1-4+P1-5+P1-9 ──────────────────────────────→ P1-8 (settings)
P3-1 (grouping) ───────────────────────────────────→ P1-6, P1-7, P3-5
P2-2 (bundle ID) ──────────────────────────────────→ P2-3 (signing)
```

---

## MVP Success Criteria

| # | PRD §28 Criterion | Task |
|---|---|---|
| 1 | Install and launch | Existing + P2-5 |
| 2 | Complete onboarding | Existing + P1-10 |
| 3 | Log a period | Existing |
| 4 | Correct a period | P1-1 |
| 5 | Delete a period | P1-1 |
| 6 | Log symptoms with intensity and notes | P1-2 + existing notes |
| 7 | Edit/delete symptoms | P1-2 |
| 8 | View cycle on calendar | Existing |
| 9 | Understand current phase | Existing |
| 10 | View predicted dates | Existing |
| 11 | Receive reminders | P1-5 |
| 12 | View historical statistics | P1-6, P1-7 |
| 13 | Export encrypted to file | P1-3 |
| 14 | Import successfully | P1-4 |
| 15 | Lock the app | Existing |
| 16 | Erase all data | Existing |
| 17 | Use offline | Existing + P2-1 |
| 18 | Understand predictions are estimates | P1-9 |
| 19 | Understand data protection | P1-9 |
| 20 | Every setting works | P0-7, P1-8 |
