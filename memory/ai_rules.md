# AI Coding Rules & Standing Instructions — Safe Bloom (Flutter Edition)

## Core Philosophy: Ponytail Protocol
You are working on **Safe Bloom** in **Flutter (Dart)**. Enforce the Ponytail ladder:

1. **Does this need to exist at all?** (YAGNI — challenge speculative abstractions).
2. **Already in this codebase?** (Reuse existing Dart models, widgets, theme tokens, and services).
3. **Stdlib / Core Dart does it?** (Use `dart:core`, `dart:convert`, `dart:async`).
4. **Native platform feature covers it?** (Use `sqflite_sqlcipher`, `flutter_secure_storage`).
5. **Already-installed dependency solves it?** (Avoid bloated external packages).
6. **Can it be one line?** (Keep Dart widgets and logic concise).
7. **Only then:** write minimal working implementation.

---

## 1. Installed Flutter Skills & Architectural Guidelines (MANDATORY)

When building or reviewing any Flutter/Dart code in this repository, ALWAYS apply these specialized Flutter rules:

### A. Feature-First Clean Architecture
- **Layer Isolation:**
  - `Presentation Layer`: Widgets, UI screens, state controllers. Listens to domain layer and renders state.
  - `Domain Layer`: Pure Dart only (Entities, Use Cases, Repository interfaces). ZERO Flutter or UI framework imports allowed.
  - `Data Layer`: Data sources (`sqflite_sqlcipher`, `flutter_secure_storage`), repository implementations, and raw SQL/DTO mappers.
- **Dependency Direction:** Dependencies must ALWAYS point inward: `Presentation → Domain ← Data`.

### B. UI/UX Guidelines — Zero Hardcoded UI
- **Strict Tokenization:** NEVER hardcode raw hex colors (`Color(0xFF...)`), font sizes, padding numbers, or static dimensions inside widgets. All visual attributes MUST be pulled from:
  - `AppColors` (`lib/core/theme/app_colors.dart`)
  - `AppTypography` (`lib/core/theme/app_typography.dart`)
  - `AppSpacing` (`lib/core/theme/app_spacing.dart`)
  - `Theme.of(context)`
- **Dumb Views:** Widgets render UI state only — no database queries, network requests, or complex cycle calculations inside `build()` methods.
- **Responsive Layouts:** Use `LayoutBuilder`, `MediaQuery`, or flexible/expanded widgets to prevent pixel overflow bugs across screen sizes.

### C. State Management & Data Access
- **State Separation:** Use simple, functional reactive state management (`ChangeNotifier` / `ValueNotifier` or lightweight Riverpod).
- **SQLCipher Data Abstraction:** Access `sqflite_sqlcipher` strictly through data sources in `lib/features/<feature>/data/`. Never invoke raw database methods inside widgets.

---

## 2. Zero-Server System Boundaries (Non-Negotiable)

- **NO External Analytics Packages:** No Firebase Analytics, Mixpanel, Sentry, Amplitude.
- **NO Third-Party Ad SDKs:** No AdMob, Unity Ads, AppLovin. Ads are direct-sold static images configured via remote JSON.
- **NO Custom Auth Servers:** No Supabase Auth, Firebase Auth, Auth0. Zero server accounts.
- **NO HealthKit / Health Connect (MVP):** Exclude health framework permissions to ensure zero review rejections.
- **Allowed Network Contacts ONLY:**
  1. Google Play Billing & Apple App Store StoreKit (`in_app_purchase`)
  2. Google Drive REST API & iCloud Drive (`googleapis`, `extension_google_sign_in`)
  3. GitHub Pages `ads.json` (`*.github.io`)
  4. Static sponsor image CDN (`*.s3.amazonaws.com` or verified sponsor domain)

---

## 3. Technical Standards & Patterns

- **Language & Framework:** Dart 3.x, Flutter 3.x.
- **Database:** `sqflite_sqlcipher` with 256-bit AES encryption password saved in `flutter_secure_storage`.
- **Ad Gate Offline & Fallback:**
  - Fail-Open strategy: If network request fails or `active: false`, unlock insight immediately.
  - Cache sponsor images to local device storage.
- **Testing:**
  - `test/` unit tests for `CycleEngine` calculation logic.
  - Interactive Web Simulator (`preview/index.html`) for UI preview on Windows.

---

## 4. Workflow & Tracking Rules

1. **`memory/track.json` is the Primary Source of Truth:**
   - Read `memory/track.json` before modifying source files.
   - Run a sync check at session start.
   - Update line counts, status, and `changes_made` in `track.json` after editing code.
2. **Keep Explanations Terse:**
   - Code first, then concise notes: `[code] → skipped: [X], add when [Y].`
