# Safe Bloom — Implementation State Report

```
AUDIT DATE:         2026-08-13
FLUTTER VERSION:    >=3.44.0 (from pubspec.lock sdk constraint)
DART VERSION:       >=3.12.0 <4.0.0 (from pubspec.lock)
GIT BRANCH:         main
GIT COMMIT:         5d9c261 "Initial commit: Safe Bloom application"
BUILD STATUS:       Debug build runs. Release build uses debug signing keys (NOT production-ready).
```

---

## 1. Executive Summary

Safe Bloom is a Flutter-based (iOS + Android) period and menstrual cycle tracking application built around the promise of **"Your data. Your cloud. Zero servers."** The codebase represents a **working prototype** that has achieved meaningful implementation of its core privacy and tracking architecture but has critical gaps before it is ready for production release on either app store.

**What actually works:**
- SQLCipher-encrypted local database with a random key stored in the platform Keystore/Keychain via `flutter_secure_storage`
- Period entry logging (flow level + symptoms) with real persistence
- Cycle calculation engine using actual historical period data
- Calendar view showing logged and predicted period days, color-coded by cycle phase
- Today/Home view with live cycle day, phase detection, water tracking, and quick symptoms
- Biometric / PIN lock via `local_auth`
- Data wipe (full SQLCipher DB deletion + key deletion)
- OB-GYN medical PDF report generation
- JSON data export (to clipboard — NOT a file)
- Onboarding flow with last-period-date picker and cycle/period length sliders
- 4 hardcoded educational articles in the Insights screen
- Cycle trend line chart and symptom frequency bar chart backed by real DB data

**What is fake, incomplete, or missing:**
- The "ad gate" dialog (`AdGateDialog`) is a **static, hardcoded sponsor card** (labeled "SPONSORED BY SEED") with a 5-second countdown — there is **NO actual advertising SDK** integrated.
- `_anonymousMode` and `_cloudBackup` settings toggles change in-memory state only and are **not persisted** anywhere.
- "Zero-Knowledge Backup" toggle claims "Encrypted cloud backups only accessible by your device key" — there is **no cloud backup implementation** of any kind.
- The JSON export lands on the clipboard only — not a file, no import capability.
- No notifications system whatsoever.
- No dark theme (the getter `darkTheme` just returns `lightTheme`).
- No symptom editing or deletion. Symptoms can only be added.
- Period entries cannot be edited or selectively deleted.
- No period editing UI at all.
- The onboarding `_selectedGoal` is collected but **never saved** to the database.
- `isCloudBackupEnabled` field in `UserProfile` is hardcoded to `true` everywhere.
- No import functionality.
- README.md is the Flutter default template.
- Application ID is the placeholder `com.example.safe_bloom`.
- Release signing uses debug keys.

**Privacy verdict:** The core architecture is genuinely privacy-first. No network library is called from Dart code, no Firebase or analytics SDK exists, no tracking identifiers are collected. The database is encrypted with SQLCipher using a key stored in the platform secure enclave. `google_fonts` fetches fonts from Google's CDN at runtime on first launch — this constitutes one data-leaving-the-device event: an HTTP request to Google that reveals the device's IP address.

---

## 2. Project Structure

```
Safe-Bloom/
├── pubspec.yaml                    # Project manifest — 10 direct dependencies, no ads/analytics
├── pubspec.lock                    # Locked versions (Flutter >=3.44.0, Dart >=3.12.0)
├── analysis_options.yaml           # flutter_lints strict config — used
├── README.md                       # DEFAULT Flutter template — not updated
├── .metadata                       # Flutter tool metadata, revision 058e0af2...
├── .gitignore                      # Standard Flutter gitignore
│
├── assets/
│   └── images/
│       └── safe-bloom-logo.png     # 403 KB app logo — only image asset
│
├── lib/
│   ├── main.dart                   # App entry, startup router, biometric check
│   ├── core/
│   │   └── theme/
│   │       ├── app_colors.dart     # Color constants — COMPLETE, used throughout
│   │       ├── app_spacing.dart    # Spacing constants — COMPLETE, used throughout
│   │       ├── app_theme.dart      # ThemeData — light only; darkTheme returns lightTheme
│   │       └── app_typography.dart # Google Fonts wrappers (Cormorant Garamond, Montserrat)
│   └── features/
│       ├── tracking/
│       │   ├── data/
│       │   │   ├── datasources/
│       │   │   │   └── database_helper.dart   # SQLCipher singleton, all CRUD ops
│       │   │   └── repositories/
│       │   │       └── tracking_repository.dart # Repo facade, export, wipe
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   ├── period_entry.dart      # PeriodEntry model + FlowLevel enum
│       │   │   │   ├── symptom_entry.dart     # SymptomEntry model + SymptomCategory enum
│       │   │   │   └── user_profile.dart      # UserProfile model
│       │   │   └── services/
│       │   │       ├── cycle_calculator.dart  # All cycle math — COMPLETE
│       │   │       └── pdf_report_generator.dart # OB-GYN PDF generator — COMPLETE
│       │   └── presentation/
│       │       ├── views/
│       │       │   ├── home_shell_view.dart   # Bottom nav shell (4 tabs)
│       │       │   ├── today_view.dart        # Home/Today screen — main dashboard
│       │       │   └── calendar_view.dart     # Calendar with phase coloring
│       │       └── widgets/
│       │           └── period_logger_sheet.dart # Modal bottom sheet for logging
│       ├── insights/
│       │   └── presentation/
│       │       ├── views/
│       │       │   └── insights_view.dart     # Hardcoded 4 articles + charts
│       │       └── widgets/
│       │           ├── cycle_charts_widget.dart # Real fl_chart charts from DB data
│       │           └── ad_gate_dialog.dart    # Fake sponsor countdown dialog (NO real ad)
│       ├── onboarding/
│       │   └── presentation/views/
│       │       └── onboarding_view.dart       # 4-step onboarding — goal not saved
│       ├── security/
│       │   ├── data/services/
│       │   │   └── biometric_auth_service.dart # local_auth wrapper — COMPLETE
│       │   └── presentation/views/
│       │       └── biometric_lock_screen.dart  # Lock screen UI — COMPLETE
│       └── settings/
│           └── presentation/views/
│               └── settings_view.dart         # Settings UI — some toggles not persisted
│
├── test/
│   ├── widget_test.dart                       # 1 smoke test
│   ├── biometric_lock_screen_test.dart        # 1 widget render test
│   ├── cycle_charts_widget_test.dart          # 2 widget render tests
│   └── pdf_report_generator_test.dart         # 2 unit tests for PDF generation
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts                   # applicationId = "com.example.safe_bloom" ⚠
│   │   └── src/main/
│   │       └── AndroidManifest.xml            # USE_BIOMETRIC permission + URL intents
└── ios/
    └── Runner/
        ├── Info.plist                         # NSFaceIDUsageDescription set — COMPLETE
        └── AppDelegate.swift                  # Standard Flutter AppDelegate
```

**Important missing directories:**
- No `integration_test/`
- No `l10n/` — no localization
- No `lib/core/router/` — no dedicated routing file
- No `lib/core/services/` — services embedded in features
- No `lib/core/constants/`

---

## 3. Technology Stack

### Direct Dependencies

| Package | Locked Version | Purpose | Actually Used? | Status |
|---|---|---|---|---|
| `sqflite_sqlcipher` | 3.4.0 | Encrypted SQLite database | ✅ Yes | FUNCTIONAL |
| `flutter_secure_storage` | 9.2.4 | Platform Keystore/Keychain key storage | ✅ Yes | FUNCTIONAL |
| `google_fonts` | 6.3.3 | Cormorant Garamond + Montserrat fonts | ✅ Yes | Makes HTTP requests to Google CDN |
| `intl` | 0.19.0 | Date formatting | ✅ Yes | FUNCTIONAL |
| `path` | 1.9.1 | DB file path joining | ✅ Yes | FUNCTIONAL |
| `local_auth` | 2.3.0 | Biometric / PIN authentication | ✅ Yes | FUNCTIONAL |
| `fl_chart` | 0.70.2 | Line chart + bar chart | ✅ Yes | FUNCTIONAL |
| `pdf` | 3.13.0 | PDF generation | ✅ Yes | FUNCTIONAL |
| `printing` | 5.15.0 | PDF preview + print/share | ✅ Yes | FUNCTIONAL |
| `url_launcher` | 6.3.2 | Launch external URLs | ✅ Yes (easter egg) | FUNCTIONAL |

### What is NOT present (privacy audit):

- ❌ No Firebase (no google-services.json, no firebase_core, no crashlytics)
- ❌ No AdMob / Google Mobile Ads SDK
- ❌ No analytics SDK (no Firebase Analytics, no Mixpanel, no Amplitude)
- ❌ No Supabase, Parse, or any BaaS
- ❌ No crash reporting (no Sentry, no Crashlytics)
- ❌ No push notification SDK
- ❌ No `http` or `dio` called from Dart source code
- ❌ No advertising identifiers (`IDFA`, `GAID`) accessed anywhere

---

## 4. Application Architecture

**Feature-first layered architecture:**
- `lib/features/<feature>/data/` → data sources, repositories
- `lib/features/<feature>/domain/` → entities, services
- `lib/features/<feature>/presentation/` → views, widgets

**State management:** None — vanilla `StatefulWidget + setState()` throughout. Every screen instantiates its own `TrackingRepository`.

**Dependency injection:** None. All singletons accessed directly: `DatabaseHelper.instance`, `BiometricAuthService.instance`.

**Data Flow:**
```
UI (StatefulWidget)
  → TrackingRepository
    → DatabaseHelper.instance
      → sqflite_sqlcipher → safebloom_encrypted.db

Key management:
  DatabaseHelper → flutter_secure_storage → iOS Keychain / Android Keystore
```

---

## 5. Data Models

### PeriodEntry

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | `String` | No | `millisecondsSinceEpoch.toString()` — not UUID |
| `timestamp` | `DateTime` | No | Local time, no timezone handling |
| `flow` | `FlowLevel` | No | `spotting / light / medium / heavy` |
| `notes` | `String?` | Yes | Rarely populated from UI |

### SymptomEntry

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | `String` | No | millisecondsSinceEpoch |
| `timestamp` | `DateTime` | No | Local time |
| `category` | `SymptomCategory` | No | 8 categories |
| `type` | `String` | No | Free-text symptom name |
| `intensity` | `int` | No | **Always 3 (hardcoded) — no UI picker** |
| `notes` | `String?` | Yes | **Always null — no UI input** |

All symptoms from quick-log and logger sheet use `SymptomCategory.custom`.

### UserProfile

| Field | Type | Notes |
|---|---|---|
| `lastPeriodStart` | `DateTime` | Updated on each period entry add |
| `avgCycleLength` | `int` | Default 28; recalculated dynamically |
| `avgPeriodLength` | `int` | Default 5; recalculated dynamically |
| `isCloudBackupEnabled` | `bool` | **Hardcoded `true` everywhere; toggle is in-memory only** |
| `createdAt` | `DateTime` | Set on profile creation |

### DailyLog (DB table only, no Dart class)
`daily_logs(date_str PK, water_ml, mood, notes)` — `mood` and `notes` columns exist in schema but are **never read or written from Dart code**.

**Missing models:** Cycle, Sleep, Exercise, BBT, Weight, Medication, Birth control, Pregnancy test, Cervical mucus, Custom symptom definitions.

---

## 6. Period Tracking

| Feature | Status | Evidence |
|---|---|---|
| Start period (today) | **PARTIAL** | Creates one entry; doesn't create subsequent days |
| End period (today) | **MOCKED** | Shows SnackBar only — **no DB write** |
| Log period for today (full form) | **COMPLETE** | `PeriodLoggerSheet` → `addPeriodEntry()` — persisted |
| Log period for historical date | **PARTIAL** | Calendar double-tap works but UX not surfaced |
| Edit period entry | **MISSING** | No edit UI |
| Delete single period entry | **PARTIAL** | DB method exists; no UI to trigger it |
| Delete all data | **COMPLETE** | "PURGE ALL MY DATA NOW" in Settings |
| Period history view | **MISSING** | No dedicated list/history screen |
| Flow level logging | **COMPLETE** | 4 levels, selectable from home and logger sheet |
| Period start ID generation | **FRAGILE** | millisecondsSinceEpoch-based — collision risk in tight loops |

**Cycle grouping:** Two entries are grouped as one cycle if ≤ 2 days apart. This algorithm is **copy-pasted into 4 files**: `tracking_repository.dart`, `cycle_calculator.dart`, `cycle_charts_widget.dart`, `pdf_report_generator.dart`.

---

## 7. Cycle Calculation Engine

File: `lib/features/tracking/domain/services/cycle_calculator.dart`

**Current cycle day:** `(today - lastPeriodStart).inDays + 1` — minimum 1, local time only.

**Cycle phase:** Inputs: cycleDay, avgCycleLength, avgPeriodLength.
- Ovulation = `avgCycleLength - 14` (hardcoded 14-day luteal assumption)
- Menstrual: cycleDay ≤ avgPeriodLength
- Follicular: cycleDay < ovulationDay - 2
- Ovulation: cycleDay ≤ ovulationDay + 2
- Luteal: everything else
- cycleDay normalized via `((rawDay - 1) % avgCycleLength) + 1`

**Average calculation:** Groups entries by ≤2-day gap. Avg period = mean group size. Avg cycle = mean of inter-start gaps. Requires ≥2 distinct cycles, else falls back to 28/5. Clamped: cycle `[20,45]`, period `[2,10]`.

**What it is NOT:** No statistical modeling, no variance prediction, no AI — pure arithmetic.

---

## 8. Calendar

| Feature | Status | Notes |
|---|---|---|
| Month grid | **COMPLETE** | Custom `GridView.builder`, 7 cols, proper weekday offset |
| Month navigation | **COMPLETE** | Prev/next buttons |
| Today indicator | **MISSING** | No specific highlight for today |
| Logged period days | **COMPLETE** | Coral fill |
| Predicted period days | **COMPLETE** | 50% alpha coral |
| Phase coloring | **COMPLETE** | 4 colors for 4 phases |
| Phase legend | **COMPLETE** | Horizontal scrolling row |
| Symptom dot indicator | **COMPLETE** | Dot on days with symptoms |
| Day selection + detail card | **COMPLETE** | Shows phase, cycleDay, fertility, symptoms |
| Log entry for selected date | **COMPLETE** | Button in detail panel + double-tap |
| Future date logging | **PARTIAL** | No restriction — future dates can be logged |

---

## 9. Home / Dashboard

File: `lib/features/tracking/presentation/views/today_view.dart`

| Component | Data Source | Dynamic? | Status |
|---|---|---|---|
| Phase badge | DB profile | Yes | COMPLETE |
| Circular cycle dial | DB profile | Yes | COMPLETE |
| "Day X / Period in Y days" | Computed | Yes | COMPLETE |
| "Fertility: High/Low" | Phase-based | Yes | PARTIAL (binary only) |
| "MARK PERIOD STARTED/ENDED TODAY" | Computed | Yes | PARTIAL — end does nothing persistent |
| Flow intensity chips | DB (today's entry) | Yes | COMPLETE |
| "LOG ALL SYMPTOMS & NOTES" | N/A | N/A | COMPLETE — opens sheet |
| Water intake bar + counter | DB (daily_logs) | Yes | COMPLETE |
| Quick mood/body chips | DB (today's symptoms) | Yes | COMPLETE |
| "Daily Action Plan" | Static hardcoded text | No | MOCKED — fake ad, static content |
| Developer easter egg (8-tap shield) | N/A | N/A | COMPLETE — opens GitHub URL |

---

## 10. Logging System

| Log Type | Persisted? | Can Edit? | Can Delete? | Notes |
|---|---|---|---|---|
| Period (flow level) | ✅ Yes | ❌ No | ❌ No UI | SQLCipher encrypted |
| Symptoms (all types) | ✅ Yes | ❌ No | ❌ No UI | `intensity` hardcoded 3, `notes` always null |
| Water intake | ✅ Yes | Via +/- | ❌ No | daily_logs table |
| Mood (quick chips) | ✅ Add only | ❌ No | ❌ **Bug: removal is in-memory only** | No DB delete called |
| Sleep | ❌ Missing | — | — | — |
| Exercise | ❌ Missing | — | — | — |
| Medication | ❌ Missing | — | — | — |
| BBT / Weight / etc. | ❌ Missing | — | — | — |

> ⚠️ **Bug:** `_toggleQuickSymptom` in `today_view.dart:206-222` removes symptoms from local state only. No `deleteSymptomEntry` method exists in `DatabaseHelper`.

---

## 11. Storage & Database

**Engine:** SQLCipher via `sqflite_sqlcipher: 3.4.0`
**File:** `safebloom_encrypted.db` in platform databases directory

**Schema:**
```sql
period_entries(id TEXT PK, timestamp TEXT, flow TEXT, notes TEXT)
symptom_entries(id TEXT PK, timestamp TEXT, category TEXT, type TEXT, intensity INT, notes TEXT)
daily_logs(date_str TEXT PK, water_ml INT, mood TEXT, notes TEXT)
user_profile(id INT PK DEFAULT 1, last_period_start TEXT, avg_cycle_length INT,
             avg_period_length INT, is_cloud_backup_enabled INT, created_at TEXT)
```

**What is stored where:**

| Data | Location | Encrypted? |
|---|---|---|
| Period entries | SQLCipher DB | ✅ AES-256 |
| Symptom entries | SQLCipher DB | ✅ AES-256 |
| Water intake | SQLCipher DB | ✅ AES-256 |
| User profile | SQLCipher DB | ✅ AES-256 |
| DB encryption key | flutter_secure_storage → Keychain/Keystore | ✅ Platform |
| Biometric lock toggle | flutter_secure_storage | ✅ Platform |
| Anonymous mode | **In-memory only** | — |
| Cloud backup toggle | **In-memory only** | — |
| Onboarding goal | **Never saved** | — |

**SharedPreferences:** Not used anywhere.

---

## 12. Encryption & Key Management

**Key generation:**
```
_getOrCreateEncryptionPassword() in database_helper.dart:34-44
→ Random.secure() generates 32 bytes
→ base64UrlEncode → ~43-char base64 string
→ flutter_secure_storage.write(key: 'safebloom_db_key', ...)
```

**SQLCipher:** AES-256 CBC, HMAC-SHA512 per page, PBKDF2 key derivation (SQLCipher 4.x defaults). The UI claim of "256-Bit AES" is technically accurate.

**What is GENUINE:**
1. SQLCipher AES-256 encryption of entire DB file
2. Random key via `Random.secure()`
3. Key stored in platform secure enclave (Keychain/Keystore)
4. Key deleted on wipe (`_secureStorage.delete(key: 'safebloom_db_key')`)

**Issues:**
- `exportEncryptedUserDataJson` returns **plaintext JSON** — the "Encrypted" label is false
- Clipboard exposure: any clipboard-reading app can access the exported plaintext health data
- No key rotation mechanism
- Water intake (`daily_logs`) not included in the JSON export

---

## 13. Zero-Server / Privacy Audit

**Network calls from Dart code:** Zero. No HTTP, no WebSocket, no gRPC from any Dart source file.

**Network calls from packages:**

| Package | Network Activity | Risk |
|---|---|---|
| `google_fonts` | Fetches fonts from `fonts.gstatic.com` on first launch | ⚠️ Reveals device IP to Google |
| `url_launcher` | Opens `https://github.com/DarkWolfHunter007` in browser (easter egg) | Safe — user-initiated |
| `printing` | Platform print dialogs — may use cloud print | Platform-dependent |
| All others | No network | ✅ Safe |

**No Firebase configuration found:** No `google-services.json`, no `GoogleService-Info.plist`, no Firebase packages.

**Privacy verdict:** Core architecture is genuinely privacy-first. One structural conflict: `google_fonts` CDN requests contradict the absolute "your data never leaves your device" promise.

---

## 14. Advertising Audit

`lib/features/insights/presentation/widgets/ad_gate_dialog.dart` — 129 lines

**What it is:** A static card showing "SPONSORED BY SEED" with a 5-second countdown timer. After countdown, user closes it to "unlock" the Daily Action Plan.

**What it is NOT:**
- ❌ No ad network SDK
- ❌ No AdMob App ID in either manifest
- ❌ No impression/click/conversion tracking
- ❌ No IDFA/GAID access
- ❌ No ATT framework integration
- ❌ No GDPR consent

**Note:** "LEARN MORE AT SEED.COM ↗" is a text label — it has no tap handler and launches no URL.

**Privacy conflict:** The fake ad gate is architecturally honest (no data leaks). If a real ad SDK were integrated in the future, it would fundamentally violate the zero-data-selling promise.

---

## 15. Consent & Permissions

**Privacy policy screen:** Does not exist.

**Consent mechanisms:** None. No cookie banner, no analytics consent, no GDPR flow, no ATT prompt.

**Android permissions (AndroidManifest.xml):**
| Permission | Necessary? |
|---|---|
| `USE_BIOMETRIC` | ✅ Yes — local_auth |
| `VIEW` intent (https/http) | ✅ Yes — url_launcher |
| `PROCESS_TEXT` | ✅ Yes — Flutter engine |
| `INTERNET` | **Not declared** — google_fonts may require it implicitly |
| `POST_NOTIFICATIONS` | **Missing** — needed for Android 13+ notifications |
| `RECEIVE_BOOT_COMPLETED` | **Missing** — needed for notification rescheduling |

**iOS permissions (Info.plist):**
| Key | Status |
|---|---|
| `NSFaceIDUsageDescription` | ✅ Present — "Authenticate to access Safe Bloom period and health data" |
| `NSUserNotificationsUsageDescription` | ❌ Missing |
| HealthKit usage descriptions | ❌ Missing (not needed currently) |

---

## 16. Notifications

**Status: MISSING — Not implemented at all.**

No notification package in `pubspec.yaml`. No scheduling logic. No notification preferences. No reminder UI.

What would be needed: `flutter_local_notifications`, `timezone` package, `POST_NOTIFICATIONS` + `RECEIVE_BOOT_COMPLETED` permissions on Android, background modes on iOS.

---

## 17. Settings

| Setting | Persisted | Changes Behavior |
|---|---|---|
| Anonymous Mode toggle | ❌ In-memory only | ❌ No effect |
| Biometric / PIN Lock toggle | ✅ flutter_secure_storage | ✅ Yes |
| Zero-Knowledge Backup toggle | ❌ In-memory only | ❌ No effect (no backup exists) |
| OB-GYN PDF Report | N/A | ✅ Opens PDF preview |
| Export Encrypted Backup (JSON) | N/A | ✅ Copies **plaintext** JSON to clipboard |
| Purge All My Data | N/A | ✅ Wipes DB + key + navigates to onboarding |
| Notifications | ❌ Absent | — |
| Theme | ❌ Absent | — |
| About / Version | ❌ Absent | — |
| Privacy Policy | ❌ Absent | — |

---

## 18. Security Features

| Feature | Status |
|---|---|
| Biometric / PIN lock | ✅ COMPLETE — `BiometricAuthService` + `BiometricLockScreen` |
| App lock on background | ✅ COMPLETE — `didChangeAppLifecycleState` in `main.dart:76-85` |
| SQLCipher database encryption | ✅ COMPLETE — AES-256, random key in Keystore |
| Key in platform secure enclave | ✅ COMPLETE — `flutter_secure_storage` |
| Full data wipe | ✅ COMPLETE — DB file + key deleted |
| Screenshot prevention | ❌ MISSING — No `FLAG_SECURE` (Android), no app switcher blur (iOS) |
| App switcher privacy | ❌ MISSING |
| Clipboard auto-clear | ❌ MISSING — JSON export never cleared |
| Hardcoded secrets | ✅ NONE — No API keys or passwords hardcoded |
| Custom in-app PIN | ❌ MISSING — Only platform biometric/PIN |

---

## 19. Data Export / Import

**Export:**
| Feature | Status | Notes |
|---|---|---|
| JSON export | **PARTIAL** | Plaintext, clipboard only, mislabeled "encrypted", excludes water data |
| PDF medical report | **COMPLETE** | Full OB-GYN PDF via platform print/share |
| File export to filesystem | **MISSING** | — |

**Import:** **MISSING** — No import capability, no file picker, no parsing logic.

**Backup/Restore:** **MISSING** — No backup mechanism despite the Settings toggle claiming otherwise.

---

## 20. Onboarding

4-step flow in `lib/features/onboarding/presentation/views/onboarding_view.dart`:

| Step | Data Collected | Saved? |
|---|---|---|
| 1: Welcome + Privacy Guarantees | None | N/A |
| 2: Last Period Date (picker — last 90 days only) | `_selectedLastPeriod` | ✅ → `UserProfile.lastPeriodStart` |
| 3: Cycle & Period Length sliders (cycle: 20-45d, period: 2-10d) | `_avgCycleLength`, `_avgPeriodLength` | ✅ → `UserProfile` |
| 4: Primary Goal (4 options) | `_selectedGoal` | ❌ — discarded |

On completion: creates `UserProfile`, seeds `avgPeriodLength` period entries at `FlowLevel.medium` (hardcoded), navigates to `HomeShellView`.

**UI Bug:** Default `_selectedGoal = 'Track Cycle & Symptoms'` but options include emoji prefix `'🌸 Track Cycle & Symptoms'` — no option is highlighted on initial render of step 4.

---

## 21. Navigation

```
AppStartupWrapper
├── [no profile]      → OnboardingView → HomeShellView
├── [biometric lock]  → BiometricLockScreen → HomeShellView
└── [has profile]     → HomeShellView
                           ├── Tab 0: TodayView
                           │   ├── modal: PeriodLoggerSheet
                           │   └── dialog: AdGateDialog
                           ├── Tab 1: CalendarView
                           │   └── modal: PeriodLoggerSheet
                           ├── Tab 2: InsightsView
                           │   └── embedded: CycleChartsWidget
                           │   └── modal: Article detail (bottom sheet)
                           └── Tab 3: SettingsView
                               ├── push: PDF preview
                               ├── dialog: JSON export
                               └── dialog: Wipe confirmation
```

**Method:** No GoRouter, no named routes. `Navigator.of(context).push/pushReplacement/pushAndRemoveUntil`, `showModalBottomSheet`, `showDialog`, `IndexedStack` + `BottomNavigationBar`.

---

## 22. UI Screen Analysis

| File | Lines | All Data Real? | Mocked/Hardcoded |
|---|---|---|---|
| `today_view.dart` | 761 | Yes (main data) | "Daily Action Plan" content; water goal hardcoded to 8 glasses |
| `calendar_view.dart` | 419 | Yes | None |
| `home_shell_view.dart` | 85 | N/A | None |
| `settings_view.dart` | 847 | Yes | Anonymous Mode + Cloud Backup toggles not persisted |
| `onboarding_view.dart` | 397 | N/A | Goal discarded; date picker limited to 90 days back |
| `insights_view.dart` | 237 | Yes (charts) | 4 articles are hardcoded Dart constants |
| `cycle_charts_widget.dart` | 768 | Yes when data exists | Hardcoded sample symptoms when no data logged |
| `biometric_lock_screen.dart` | 249 | N/A | None — fully functional |
| `period_logger_sheet.dart` | 173 | N/A | Pre-selects "⚡ Cramps" always; no notes/intensity UI |
| `ad_gate_dialog.dart` | 129 | N/A | Entirely static/hardcoded — no ad SDK |

---

## 23. Insights & Statistics

**Cycle Trend Line Chart (real data):**
- 6 monthly data points; real values when ≥2 cycles logged
- Falls back to profile average for months with no inter-cycle data
- Regularity: Regular (≤1.5d variation), Slight Variance (≤3.5d), Irregular (>3.5d)

**Symptom Frequency Bar Chart (real data):**
- Top 6 symptoms by count when any symptoms logged
- Falls back to **6 hardcoded fake entries** (Cramps:8, Fatigue:6, etc.) when no data — labeled "Sample symptom distribution" in footer

**Missing insights:** No cycle history list, no shortest/longest cycle display, no symptom-to-phase correlation, no mood trends.

---

## 24. Health Content

4 articles hardcoded as Dart constants in `insights_view.dart:19-52`:

1. "Optimizing High-Intensity Workouts in Ovulation" (Fitness, 3 min)
2. "Hormone Balancing Diet & Antioxidants" (Nutrition, 4 min)
3. "Managing PMS & Luteal Phase Sleep Quality" (Mind & Sleep, 5 min)
4. "Iron Replenishment During Your Period" (Nutrition, 2 min)

**No medical disclaimer displayed anywhere.** Phase sync is cosmetic — articles always shown regardless of actual phase.

---

## 25. Testing

| File | Tests | Covers | Real DB? |
|---|---|---|---|
| `widget_test.dart` | 1 | App renders loading spinner | No |
| `biometric_lock_screen_test.dart` | 1 | Lock screen UI text/buttons render | No (mocked platform) |
| `cycle_charts_widget_test.dart` | 2 | Widget exists; InsightsView header text | No (DB calls fail) |
| `pdf_report_generator_test.dart` | 2 | PDF generation with test data + empty data | No DB needed |

**Zero tests for:** `CycleCalculator` (critical business logic), `DatabaseHelper`, `TrackingRepository`, onboarding flow, period CRUD, biometric flow, data wipe, export.

> ⚠️ The `CycleCalculator` — which drives all predictions, phase labels, and dashboard data — has **zero unit tests.**

---

## 26. Error Handling

| Scenario | Handled? |
|---|---|
| DB init failure | ❌ No — throws uncaught |
| Encryption key generation failure | ❌ No |
| Corrupt DB / wrong key | ❌ No recovery path |
| Biometric PlatformException | ✅ Yes — caught in `BiometricAuthService` |
| Biometric not supported | ✅ Yes — `isDeviceSupported()` checked before enabling |
| No profile on startup | ✅ Yes — routes to onboarding |
| Empty chart data | ✅ Yes — falls back to sample data with label |
| Null profile in repository | ✅ Partial — `getUserProfile()` returns a default |
| PDF generation failure | ❌ No — uncaught |
| Invalid date strings from DB | ❌ No — `DateTime.parse()` would throw |

---

## 27. Performance Concerns

1. **DB reads on every tab switch:** `CalendarView.refresh()` and `CycleChartsWidget.refresh()` called every tab switch, not only on data changes.
2. **Cycle grouping algorithm runs 1–4× per data load** across 4 separate copy-pasted implementations.
3. **Calendar recomputes `getPredictedPeriodDates()`** (generating a `Set<DateTime>`) for every day cell on every `setState`.
4. **No debouncing on water intake:** Each +250ml tap triggers a DB write.
5. **`IndexedStack` keeps all 4 tabs alive** simultaneously.

---

## 28. Android Build Status

| Item | Value | Status |
|---|---|---|
| `applicationId` | `com.example.safe_bloom` | ⚠️ PLACEHOLDER |
| `minSdk` | `flutter.minSdkVersion` (Flutter default ~21) | Unknown explicit value |
| `versionCode` / `versionName` | 1 / "1.0.0" | Set |
| Release signing | Debug keys | ⚠️ NOT production-ready |
| ProGuard/R8 | Not configured | ⚠️ Missing |
| `android:allowBackup` | Not set (defaults true) | ⚠️ Health data may be in ADB/cloud backups |

---

## 29. iOS Build Status

| Item | Value | Status |
|---|---|---|
| `NSFaceIDUsageDescription` | Present | ✅ |
| Bundle identifier | Template `$(PRODUCT_BUNDLE_IDENTIFIER)` | ⚠️ Not set |
| App Privacy Manifest (`PrivacyInfo.xcprivacy`) | **Missing** | ❌ Required since March 2024 |
| Release signing | Not configured | ❌ |
| Orientation | Info.plist allows landscape; `main.dart` locks portrait | ⚠️ Inconsistency |

---

## 30. Secrets Audit

After reviewing all Dart source files: **No hardcoded secrets found.**

- No API keys
- No hardcoded DB passwords
- No Firebase configuration
- No AdMob IDs
- No third-party service credentials

DB encryption key is correctly generated at runtime and stored in platform secure storage.

---

## 31. Code Quality

**Dead code:**
- `daily_logs.mood` and `.notes` columns — never read/written
- `UserProfile.isCloudBackupEnabled` — never respected; always `true`
- `AppTheme.darkTheme` — returns `lightTheme`

**Duplicated code (4 copies each):**
- Cycle grouping algorithm (≤2-day gap grouping): `tracking_repository.dart`, `cycle_calculator.dart`, `cycle_charts_widget.dart`, `pdf_report_generator.dart`
- `_getMonthName()` method: `period_logger_sheet.dart`, `calendar_view.dart`, `settings_view.dart`, `onboarding_view.dart`

**Bugs:**
- Quick-symptom removal doesn't touch DB
- Onboarding goal default doesn't match any option string
- "MARK PERIOD ENDED" is a no-op SnackBar
- JSON export labeled "Encrypted" but is plaintext

---

## 32. Implementation Status Matrix

| Feature | Status | What Works | What's Missing |
|---|---|---|---|
| Onboarding | **PARTIAL** | 4-step flow, date/cycle/period saved, period seeded | Goal not saved; no consent; 90-day date limit |
| Period logging (today) | **PARTIAL** | Flow + symptoms persisted | "End period" does nothing |
| Period logging (historical) | **PARTIAL** | Calendar double-tap works | UX not surfaced |
| Period editing | **MISSING** | — | No UI |
| Period deletion (single) | **MISSING** | DB method exists | No UI |
| Cycle calculation | **COMPLETE** | Phase, cycleDay, predictions, averages | Timezone, hardcoded luteal |
| Period prediction | **COMPLETE** | Predicted dates on calendar | Limited irregular handling |
| Ovulation prediction | **PARTIAL** | cycleLength - 14 | Not personalized |
| Calendar | **COMPLETE** | Month grid, phase colors, symptom dots, logging | No today highlight |
| Symptoms logging | **PARTIAL** | Add persisted | No delete, no edit, no intensity/notes UI |
| Water intake | **COMPLETE** | Logged, persisted | No history |
| Insights / Charts | **PARTIAL** | Real fl_chart charts from DB, 4 articles | No history list; placeholder data for new users |
| Local storage | **COMPLETE** | SQLCipher DB, full CRUD | — |
| Encryption | **COMPLETE** | AES-256 SQLCipher, key in Keystore | Export is not encrypted |
| Biometric lock | **COMPLETE** | Face ID / fingerprint / PIN, re-locks on background | — |
| Notifications | **MISSING** | — | Not started |
| Settings (functional) | **PARTIAL** | Biometric, PDF, JSON export, wipe | Anonymous Mode + Cloud Backup not persisted |
| Data export (JSON) | **PARTIAL** | Plaintext JSON to clipboard | Not encrypted, no file, no water data |
| Data export (PDF) | **COMPLETE** | OB-GYN medical PDF | — |
| Data import | **MISSING** | — | Not started |
| Full data deletion | **COMPLETE** | Wipe including key | No selective deletion |
| Privacy policy screen | **MISSING** | — | Not started |
| Consent | **MISSING** | — | Not started |
| Advertising (real) | **MISSING** | Fake static card only | No real ad SDK |
| Analytics | **N/A — None** | ✅ No analytics (good) | — |
| Zero-server architecture | **COMPLETE** | No server, no account, no cloud | google_fonts CDN side channel |
| Android build | **PARTIAL** | Debug works | Placeholder ID, debug signing, no ProGuard |
| iOS build | **PARTIAL** | Debug works | No privacy manifest, no signing |
| Testing | **PARTIAL** | 6 tests across 4 files | No CycleCalculator tests, no DB tests |

---

## 33. Data Flow Maps

### USER LOGS PERIOD

```
TodayView._openLoggerSheet()
  → showModalBottomSheet → PeriodLoggerSheet
  → User selects FlowLevel + symptoms, taps "SAVE ENCRYPTED LOG"
  → widget.onSave(flow, symptoms) callback fires

Back in TodayView:
  → PeriodEntry(id: now.millisecondsSinceEpoch.toString(), timestamp: now, flow: flow)
  → TrackingRepository.addPeriodEntry(entry)
      → DatabaseHelper.insertPeriodEntry(entry)
          → db.insert('period_entries', entry.toMap(), ConflictAlgorithm.replace)
          → [SQLCipher writes to safebloom_encrypted.db]
      → DatabaseHelper.getAllPeriodEntries() [reads all back]
      → CycleCalculator.calculateAveragesFromEntries(allEntries)
      → DatabaseHelper.saveUserProfile(updatedProfile)
  For each symptom:
  → SymptomEntry(id, timestamp, category: custom, type, intensity: 3)
  → TrackingRepository.addSymptomEntry(entry)
      → DatabaseHelper.insertSymptomEntry(entry)
  → TodayView._loadData() [re-reads all, triggers setState]
```

### USER OPENS APP

```
main() → SafeBloomApp → AppStartupWrapper.initState()
  → _checkAppStatus()
  → DatabaseHelper.instance.getUserProfile()
      → _getOrCreateEncryptionPassword()
          → FlutterSecureStorage.read('safebloom_db_key')
          → [if null: Random.secure() → 32 bytes → base64 → write]
      → openDatabase(path, password: key, version: 1, onCreate: _createDB)
      → db.query('user_profile', where: 'id = 1')
  → BiometricAuthService.isBiometricLockEnabled()
      → FlutterSecureStorage.read('biometric_lock_enabled')
  → setState({ _hasProfile, _isBiometricLockEnabled, ... })
  → if !_hasProfile → OnboardingView
  → if _isBiometricLockEnabled && !_isAuthenticated → BiometricLockScreen
  → else → HomeShellView
```

### USER OPENS INSIGHTS

```
HomeShellView._onTabTapped(2)
  → _chartsKey.currentState?.refresh()
      → TrackingRepository.getUserProfile() + .getPeriodEntries() + .getAllSymptoms()
      → _processCycleTrends(periodEntries, profile)
          → CycleCalculator.calculateAveragesFromEntries(entries)
          → Group entries into cycles (<=2-day gap)
          → Build 6-month timeline with real/estimated data
      → _processSymptomFrequencies(symptomEntries)
          → Count occurrences by type (or use hardcoded sample if empty)
      → setState({ _isLoading: false, _trendPoints, _symptomFrequencies, ... })
```

---

## 34. Privacy Data Flow

| Data | Created Where | Stored Where | Encrypted? | Leaves Device? |
|---|---|---|---|---|
| Period dates | TodayView, CalendarView, OnboardingView | SQLCipher DB | ✅ AES-256 | ❌ No |
| Flow level | Same | SQLCipher DB | ✅ AES-256 | ❌ No |
| Cycle averages | TrackingRepository.addPeriodEntry() | SQLCipher DB (user_profile) | ✅ AES-256 | ❌ No |
| Symptoms | TodayView, PeriodLoggerSheet, CalendarView | SQLCipher DB | ✅ AES-256 | ❌ No |
| Water intake | TodayView._addWaterGlass | SQLCipher DB (daily_logs) | ✅ AES-256 | ❌ No |
| User profile | OnboardingView._completeOnboarding | SQLCipher DB | ✅ AES-256 | ❌ No |
| DB encryption key | DatabaseHelper._getOrCreateEncryptionPassword | flutter_secure_storage | ✅ Platform | ❌ No |
| Biometric setting | BiometricAuthService.setBiometricLockEnabled | flutter_secure_storage | ✅ Platform | ❌ No |
| Onboarding goal | OnboardingView | **Never saved** | — | ❌ No |
| Anonymous mode | SettingsView | **In-memory only** | — | ❌ No |
| JSON export | SettingsView._exportDataJson | Clipboard (plaintext) | ❌ NO | Accessible to clipboard apps |
| Device IP | Implicit via google_fonts | Google CDN | — | ✅ YES → Google |
| Analytics data | **Not collected** | — | — | — |
| Advertising IDs | **Not accessed** | — | — | — |

---

## 35. Hardcoded / Mocked Functionality

1. **"MARK PERIOD ENDED TODAY" does nothing** — shows SnackBar only, no DB write.
2. **Ad gate is a static card** — "SPONSORED BY SEED" with no ad SDK, no tracking.
3. **"LEARN MORE AT SEED.COM" is not tappable** — text label, no GestureDetector.
4. **Quick-symptom removal doesn't delete from DB** — only removes from local list.
5. **Symptom intensity is always 3** — hardcoded in all callers, no UI picker.
6. **Symptom notes are always null** — no UI input.
7. **Period notes from logger sheet are not user-entered** — null or hardcoded "Logged from Calendar View".
8. **"Anonymous Mode" toggle has no effect** — in-memory, changes no behavior.
9. **"Zero-Knowledge Backup" toggle has no effect** — no cloud backup exists.
10. **"Zero Data Selling Guarantee — Your intimate data never leaves your device"** — not completely true; Google Fonts CDN contacted.
11. **JSON export labeled "Encrypted Backup"** — plaintext JSON.
12. **"Daily Action Plan" is hardcoded phase text** — 4 fixed strings from `CycleCalculator.getPhaseDescription()`.
13. **Educational articles are 4 hardcoded Dart constants** — not from any CMS.
14. **Onboarding goal selection is discarded** — never saved or used.
15. **Dark theme returns light theme** — `AppTheme.darkTheme` returns `lightTheme`.
16. **`_waterGoal = 8` is hardcoded** — not user-configurable.
17. **Seeded period entries use `FlowLevel.medium`** hardcoded — regardless of user input.
18. **Onboarding date picker limited to last 90 days** — users with older last period cannot enter it.

---

## 36. Bugs & Risks

### P0 — Security / Data Loss / Release Blockers

| # | Problem | File | Fix Direction |
|---|---|---|---|
| P0-1 | JSON export is plaintext, labeled "Encrypted Backup" | `settings_view.dart`, `tracking_repository.dart` | Encrypt payload or rename to "Plaintext Backup" |
| P0-2 | Application ID is `com.example.safe_bloom` | `android/app/build.gradle.kts` | Set real reverse-domain ID |
| P0-3 | Release build uses debug signing keys | `android/app/build.gradle.kts:32` | Configure release keystore |
| P0-4 | No iOS App Privacy manifest | iOS project | Create `PrivacyInfo.xcprivacy` |
| P0-5 | Quick-symptom "deletion" doesn't touch DB | `today_view.dart:207-210` | Add `deleteSymptomEntry` to `DatabaseHelper` |

### P1 — Major Functionality Broken

| # | Problem | File | Fix Direction |
|---|---|---|---|
| P1-1 | "MARK PERIOD ENDED TODAY" does nothing | `today_view.dart:121-128` | Implement end-period logic |
| P1-2 | No screenshot / screen recorder prevention | `main.dart` | Add `FLAG_SECURE` (Android), obscure window (iOS) |
| P1-3 | No period editing UI | All views | Add edit flow |
| P1-4 | No individual period/symptom deletion | All views | Add delete UI |
| P1-5 | No data import | — | Implement JSON import |

### P2 — Important But Non-Blocking

| # | Problem | File | Fix Direction |
|---|---|---|---|
| P2-1 | Anonymous Mode + Cloud Backup not persisted | `settings_view.dart` | Persist to UserProfile or secure storage |
| P2-2 | Onboarding goal never saved | `onboarding_view.dart` | Add `preferredGoal` to UserProfile |
| P2-3 | Cycle grouping code duplicated 4× | 4 files | Extract to `CycleGroupingUtil` |
| P2-4 | `_getMonthName()` duplicated 4× | 4 files | Move to core utils |
| P2-5 | `google_fonts` makes CDN requests | `app_typography.dart` | Bundle fonts locally in assets |
| P2-6 | Onboarding date picker limited to 90 days | `onboarding_view.dart:230` | Extend to 180 days |
| P2-7 | No "today" highlight on calendar | `calendar_view.dart` | Add today indicator |
| P2-8 | Onboarding goal default doesn't match any option | `onboarding_view.dart:25-31` | Match default string to emoji-prefixed options |

### P3 — Minor / Cleanup

| # | Problem | Fix Direction |
|---|---|---|
| P3-1 | README.md is Flutter default template | Write actual project README |
| P3-2 | Period logger pre-selects "⚡ Cramps" | Start with empty selection |
| P3-3 | "LEARN MORE AT SEED.COM" not tappable | Add url_launcher call |
| P3-4 | `daily_logs.mood` and `.notes` never used | Remove or implement |
| P3-5 | `isCloudBackupEnabled` always `true` | Wire to actual setting |
| P3-6 | No period history/list view | Add history screen |
| P3-7 | Water intake excluded from JSON export | Include daily_logs |
| P3-8 | Dark theme returns light theme | Implement dark theme |

---

## 37. Missing Features

### A. Required for MVP

1. Period editing UI
2. Individual period and symptom deletion UI
3. "End period" functionality that persists
4. Notifications / reminders
5. File-based data export (not clipboard) + share sheet
6. Data import / restore
7. Privacy policy screen + medical disclaimer

### B. Required Before App Store Release

8. Real application ID
9. Release signing (Android keystore, iOS certificates)
10. iOS App Privacy manifest
11. Splash screen
12. Screenshot prevention (FLAG_SECURE on Android)
13. Consent screen / privacy acknowledgment
14. Terms of Service screen

### C. Important But Can Come Later

15. Bundle google_fonts locally (eliminate CDN dependency)
16. Symptom intensity picker (1-5)
17. Notes field on symptoms and period entries
18. Cycle/period history list view
19. Dark mode
20. Unit tests for CycleCalculator (highest-value test target)

### D. Nice-to-Have

21. Custom symptom creation
22. BBT / cervical mucus / sex tracking
23. Localization / multi-language
24. Home screen widget
25. Weight tracking

---

## 38. Architectural Conflicts

### Conflict 1: "Zero Servers" vs. Google Fonts CDN
**Claim:** "Zero servers. Your data never leaves your device."
**Reality:** `google_fonts` makes HTTP requests to `fonts.gstatic.com` (Google CDN) on first launch.
**Fix:** Bundle Cormorant Garamond + Montserrat as local font assets.

### Conflict 2: "100% Privacy" vs. Plaintext Clipboard Export
**Claim:** "Your intimate data never leaves your device."
**Reality:** JSON export copies complete health history as **plaintext** to system clipboard.
**Severity:** HIGH — direct privacy violation for the app's stated goals.

### Conflict 3: "Zero-Knowledge Backup" vs. No Backup Implementation
**Claim:** "Encrypted cloud backups only accessible by your device key" (Settings toggle).
**Reality:** No cloud backup exists. Toggle does nothing.
**Severity:** HIGH — misleading feature claim.

### Conflict 4: Privacy Promise vs. Real Ad SDK (Hypothetical)
If a real ad SDK (AdMob, AppLovin, etc.) were added to make the ad gate functional, it would collect device identifiers and behavioral signals from a period-tracking context — a **critical** violation of the zero-data-selling promise. This architectural decision must be resolved before any real ad integration.

---

## 39. Project Health Scores

| Dimension | Score | Key Reasons |
|---|---|---|
| **Architecture** | 72/100 | Clean layering, good feature separation. Deducted: no state management, duplicated business logic in 4 files, no DI |
| **Functionality** | 55/100 | Core logging, cycle calc, calendar, biometric lock solid. Deducted: non-functional "end period", missing edit/delete, no notifications, fake ad gate |
| **Privacy** | 75/100 | No Firebase, no analytics, no ad SDK, encrypted local DB. Deducted: google_fonts CDN, plaintext clipboard export mislabeled as encrypted |
| **Security** | 68/100 | SQLCipher real, biometric real, key in Keystore real, wipe real. Deducted: no screenshot prevention, plaintext clipboard export |
| **Data Integrity** | 60/100 | DB CRUD works, averages recalculated. Deducted: quick-symptom deletion bug, no period editing, millisecond IDs |
| **UI Implementation** | 70/100 | Clean design system, consistent theming. Deducted: fake ad, non-functional buttons, missing today-highlight, onboarding goal bug |
| **Testing** | 18/100 | 6 tests, zero covering CycleCalculator, zero DB/storage tests, zero integration tests |
| **Performance** | 65/100 | Lightweight architecture. Deducted: DB reads every tab switch, duplicated grouping algo, calendar recomputes per-cell |
| **Android Readiness** | 25/100 | Debug builds work. Placeholder app ID, debug signing, no ProGuard, no backup rules |
| **iOS Readiness** | 20/100 | Debug builds work. No privacy manifest (REQUIRED), no signing, orientation inconsistency |
| **App Store Readiness** | 15/100 | Cannot submit: no privacy manifest, no real bundle ID, no signing, no privacy policy, no medical disclaimer |
| **Google Play Readiness** | 20/100 | Cannot submit: placeholder ID, debug signing, no privacy policy |

---

## 40. Top 20 Next Actions (Prioritized)

| Priority | Action | Files | Why |
|---|---|---|---|
| P0 | Fix plaintext clipboard export mislabeled "Encrypted" | `settings_view.dart`, `tracking_repository.dart` | Active privacy deception |
| P0 | Fix quick-symptom DB deletion bug | `today_view.dart`, `database_helper.dart` | Data integrity: DB out of sync with UI |
| P0 | Change Application ID from `com.example.safe_bloom` | `android/app/build.gradle.kts` | Cannot release to any app store |
| P0 | Configure release signing (Android + iOS) | `build.gradle.kts`, Xcode | Cannot release to any app store |
| P0 | Create iOS App Privacy manifest (`PrivacyInfo.xcprivacy`) | `ios/Runner/` | Required for App Store since March 2024 |
| P0 | Add screenshot prevention | `main.dart`, platform files | Health data must not appear in screenshots |
| P1 | Implement "End Period" button functionality | `today_view.dart` | Most prominent button on home screen is a no-op |
| P1 | Add period editing UI | New `edit_period_view.dart`, `calendar_view.dart` | Users cannot correct entries |
| P1 | Add individual period/symptom deletion UI | `calendar_view.dart`, `database_helper.dart` | Only full data wipe available currently |
| P1 | Implement notifications / reminders | `pubspec.yaml`, new `notification_service.dart` | Table stakes for a period tracking app |
| P1 | Add Privacy Policy + Terms of Service screens | New views, `settings_view.dart` | Legal requirement for app store review |
| P1 | File-based export via share sheet (replace clipboard) | `settings_view.dart`, `tracking_repository.dart` | Clipboard is not a backup; other apps can read it |
| P1 | Implement data import | `settings_view.dart`, `tracking_repository.dart` | Export without import is useless for backup |
| P2 | Bundle google_fonts locally | `pubspec.yaml`, `app_typography.dart`, `assets/fonts/` | Eliminates the Google CDN call |
| P2 | Persist Anonymous Mode and Cloud Backup settings | `settings_view.dart`, `user_profile.dart` | Settings that don't persist are deceptive |
| P2 | Save onboarding goal to UserProfile | `onboarding_view.dart`, `user_profile.dart` | Data collected but discarded |
| P2 | Extract cycle grouping to single utility | New `core/utils/cycle_grouping.dart` | Algorithm duplicated 4×; one bug = four bugs |
| P2 | Add CycleCalculator unit tests | New `test/cycle_calculator_test.dart` | Zero tests on the most critical business logic |
| P3 | Add today highlight on calendar | `calendar_view.dart` | Standard calendar UX |
| P3 | Configure Android backup rules (`android:allowBackup="false"`) | `AndroidManifest.xml` | SQLCipher DB + key both potentially backed up |

---

## One-Paragraph Handoff

Safe Bloom is a Flutter 3.44+ / Dart 3.12+ period and menstrual health tracking app with a genuine privacy-first architecture: all user data (period entries, symptoms, water intake, user profile) is stored in a SQLCipher-encrypted SQLite database (`safebloom_encrypted.db`) using a 32-byte random key stored in the platform Keystore/Keychain via `flutter_secure_storage`, with no Firebase, no analytics, no ad SDKs, no accounts, and no server anywhere in the dependency tree. The codebase follows a feature-first layered architecture with vanilla `StatefulWidget + setState` state management and no DI framework. The core tracking engine (`CycleCalculator`) is a pure static service computing cycle day, phase (menstrual/follicular/ovulation/luteal using a hardcoded 14-day luteal assumption), next period date, and predicted dates from the user's profile; when ≥2 distinct period cycles are logged, averages are dynamically recalculated. The app has 4 main screens: Today (home dashboard with real cycle dial, water tracker, quick symptom chips, and a fake 5-second static sponsor ad gate), Calendar (custom phase-colored grid with symptom dot indicators), Insights (real `fl_chart` charts from DB data, 4 hardcoded educational articles), and Settings (functional biometric lock and data wipe, but non-persisted Anonymous Mode and Cloud Backup toggles). Critical bugs: the "Mark Period Ended" button is a no-op SnackBar; quick-symptom removal doesn't write to the DB; the JSON export is plaintext but labeled "Encrypted"; the onboarding goal is collected but never saved; `google_fonts` makes HTTP calls to Google's CDN contradicting the "never leaves device" promise. The app cannot be released to either app store: application ID is `com.example.safe_bloom`, release signing uses debug keys, no iOS privacy manifest exists, no privacy policy screen, no medical disclaimer, no notifications, no period editing or deletion UI, and no data import. The single most impactful first action is fixing the plaintext-export-labeled-encrypted bug, followed by implementing the "end period" button, adding screenshot prevention, and resolving the `applicationId` and signing blockers.
