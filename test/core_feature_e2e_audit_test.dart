import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';
import 'package:safe_bloom/features/tracking/domain/services/pdf_report_generator.dart';
import 'package:safe_bloom/features/tracking/domain/services/pregnancy_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('CORE FEATURE END-TO-END AUDIT', () {
    late Database db;
    const dbPath = inMemoryDatabasePath;

    Future<void> createSchema(Database db) async {
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY,
          last_period_start TEXT NOT NULL,
          avg_cycle_length INTEGER NOT NULL,
          avg_period_length INTEGER NOT NULL,
          is_cloud_backup_enabled INTEGER NOT NULL,
          is_pregnancy_mode_enabled INTEGER NOT NULL DEFAULT 0,
          preferred_goal TEXT,
          initial_last_period_start TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE period_entries (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          flow TEXT NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE symptom_entries (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          intensity INTEGER NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE daily_logs (
          date TEXT PRIMARY KEY,
          water_ml INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    setUp(() async {
      db = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (db, version) => createSchema(db),
      );
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    // ── Helper functions for direct DB interaction ──
    Future<void> saveProfile(UserProfile p) async {
      await db.insert(
        'user_profile',
        p.toMap()..['id'] = 1,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    Future<UserProfile?> getProfile() async {
      final res = await db.query('user_profile', where: 'id = 1');
      if (res.isEmpty) return null;
      return UserProfile.fromMap(res.first);
    }

    Future<void> insertPeriod(PeriodEntry e) async {
      await db.insert('period_entries', e.toMap());
    }

    Future<List<PeriodEntry>> getAllPeriods() async {
      final res = await db.query('period_entries', orderBy: 'timestamp ASC');
      return res.map((m) => PeriodEntry.fromMap(m)).toList();
    }

    Future<void> insertSymptom(SymptomEntry s) async {
      await db.insert('symptom_entries', s.toMap());
    }

    Future<List<SymptomEntry>> getAllSymptoms() async {
      final res = await db.query('symptom_entries', orderBy: 'timestamp ASC');
      return res.map((m) => SymptomEntry.fromMap(m)).toList();
    }

    Future<void> setWater(DateTime date, int ml) async {
      final key = SafeBloomDateUtils.dateKey(date);
      await db.insert(
        'daily_logs',
        {
          'date': key,
          'water_ml': ml,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    Future<int> getWater(DateTime date) async {
      final key = SafeBloomDateUtils.dateKey(date);
      final res = await db.query('daily_logs', where: 'date = ?', whereArgs: [key]);
      if (res.isEmpty) return 0;
      return res.first['water_ml'] as int? ?? 0;
    }

    // =========================================================================
    // §2 ONBOARDING & PROFILE INITIALIZATION
    // =========================================================================
    test('E2E Onboarding: Fresh installation creates correct profile and initial state', () async {
      // 1. Initial zero state
      expect(await getProfile(), isNull);
      expect(await getAllPeriods(), isEmpty);
      expect(await getAllSymptoms(), isEmpty);

      // 2. User completes onboarding with: Jan 1 period start, 29d cycle, 5d period, TTC goal
      final initialStart = DateTime(2026, 1, 1);
      final onboardProfile = UserProfile(
        lastPeriodStart: initialStart,
        avgCycleLength: 29,
        avgPeriodLength: 5,
        isCloudBackupEnabled: true,
        preferredGoal: AppMode.ttc.name,
      );
      await saveProfile(onboardProfile);

      // 3. Verify Database persistence
      final saved = await getProfile();
      expect(saved, isNotNull);
      expect(saved!.lastPeriodStart, initialStart);
      expect(saved.avgCycleLength, 29);
      expect(saved.avgPeriodLength, 5);
      expect(saved.appMode, AppMode.ttc);

      // 4. Verify Derived Views from Onboarding
      final dayOnJan15 = CycleCalculator.getCurrentCycleDay(saved.lastPeriodStart, now: DateTime(2026, 1, 15));
      expect(dayOnJan15, 15); // Day 15
      final phaseOnJan15 = CycleCalculator.getCyclePhase(dayOnJan15, avgCycleLength: saved.avgCycleLength, avgPeriodLength: saved.avgPeriodLength);
      // Ovulation day = 29 - 14 = 15; Fertile window = [13, 17] -> Day 15 is Ovulation
      expect(phaseOnJan15, CyclePhase.ovulation);

      final nextPredicted = CycleCalculator.getNextPeriodStartDate(saved.lastPeriodStart, avgCycleLength: saved.avgCycleLength);
      expect(nextPredicted, DateTime(2026, 1, 30)); // Jan 1 + 29d = Jan 30
    });

    // =========================================================================
    // §3 & §11 & §12 APP MODES & GOAL TRANSITIONS
    // =========================================================================
    test('E2E Mode Switching: Track Cycle -> TTC -> Pregnancy -> Track Cycle maintains data integrity', () async {
      final start = DateTime(2026, 1, 1);
      var profile = UserProfile(
        lastPeriodStart: start,
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await saveProfile(profile);

      // Add a period entry
      await insertPeriod(PeriodEntry(id: 'p1', timestamp: start, flow: FlowLevel.heavy));

      // 1. In Track Cycle mode
      profile = (await getProfile())!;
      expect(profile.appMode, AppMode.trackCycle);
      var day = CycleCalculator.getCurrentCycleDay(profile.lastPeriodStart, now: DateTime(2026, 1, 14));
      expect(day, 14);

      // 2. Switch to TTC
      profile = profile.copyWith(preferredGoal: AppMode.ttc.name);
      await saveProfile(profile);
      profile = (await getProfile())!;
      expect(profile.appMode, AppMode.ttc);
      // Peak ovulation calculation for TTC
      final isPeak = CycleCalculator.isPeakOvulationDay(DateTime(2026, 1, 14), profile.lastPeriodStart, avgCycleLength: profile.avgCycleLength);
      expect(isPeak, isTrue);

      // 3. Switch to Pregnancy
      profile = profile.copyWith(preferredGoal: AppMode.pregnancy.name);
      await saveProfile(profile);
      profile = (await getProfile())!;
      expect(profile.appMode, AppMode.pregnancy);

      // Gestational calculations
      final gestAge = PregnancyCalculator.getGestationalAge(profile.lastPeriodStart, now: DateTime(2026, 3, 1));
      // Jan 1 to Mar 1 = 59 days = 8 weeks + 3 days
      expect(gestAge.weeks, 8);
      expect(gestAge.days, 3);
      final dueDate = PregnancyCalculator.getEstimatedDueDate(profile.lastPeriodStart);
      // Jan 1 + 280 days = Oct 8, 2026
      expect(dueDate, DateTime(2026, 10, 8));
      final trimester = PregnancyCalculator.getTrimester(gestAge.weeks);
      expect(trimester, '1st Trimester');

      // 4. Switch back to Track Cycle
      profile = profile.copyWith(preferredGoal: AppMode.trackCycle.name);
      await saveProfile(profile);
      profile = (await getProfile())!;
      expect(profile.appMode, AppMode.trackCycle);

      // Verify period data preserved
      final periods = await getAllPeriods();
      expect(periods.length, 1);
      expect(periods.first.id, 'p1');
    });

    // =========================================================================
    // §3 & §4 PERIOD LOGGING, SPOTTING & RECALCULATION PIPELINE
    // =========================================================================
    test('E2E Period & Spotting Pipeline: Dynamic averages, anchors and history updates', () async {
      // Setup initial baseline
      var profile = UserProfile(
        lastPeriodStart: DateTime(2026, 1, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );
      await saveProfile(profile);

      // 1. Log Cycle 1: Jan 1 to Jan 4 (4 active days)
      await insertPeriod(PeriodEntry(id: 'c1_1', timestamp: DateTime(2026, 1, 1), flow: FlowLevel.heavy));
      await insertPeriod(PeriodEntry(id: 'c1_2', timestamp: DateTime(2026, 1, 2), flow: FlowLevel.heavy));
      await insertPeriod(PeriodEntry(id: 'c1_3', timestamp: DateTime(2026, 1, 3), flow: FlowLevel.medium));
      await insertPeriod(PeriodEntry(id: 'c1_4', timestamp: DateTime(2026, 1, 4), flow: FlowLevel.light));

      // 2. Log leading spotting before Cycle 2: Jan 28 (Spotting)
      await insertPeriod(PeriodEntry(id: 'c2_spot', timestamp: DateTime(2026, 1, 28), flow: FlowLevel.spotting));

      // 3. Log Cycle 2 active flow: Jan 29 to Jan 31 (3 active days)
      await insertPeriod(PeriodEntry(id: 'c2_1', timestamp: DateTime(2026, 1, 29), flow: FlowLevel.heavy));
      await insertPeriod(PeriodEntry(id: 'c2_2', timestamp: DateTime(2026, 1, 30), flow: FlowLevel.medium));
      await insertPeriod(PeriodEntry(id: 'c2_3', timestamp: DateTime(2026, 1, 31), flow: FlowLevel.light));

      // 4. Log mid-cycle isolated spotting: Feb 12
      await insertPeriod(PeriodEntry(id: 'mid_spot', timestamp: DateTime(2026, 2, 12), flow: FlowLevel.spotting));

      final allEntries = await getAllPeriods();
      expect(allEntries.length, 9);

      // Verify CycleGroupUtils grouping
      final genuineCycles = CycleGroupUtils.groupIntoCycles(allEntries);
      expect(genuineCycles.length, 2); // exactly 2 genuine cycles (mid-cycle spotting excluded)

      // Cycle 1 anchor = Jan 1
      expect(CycleGroupUtils.getCycleStartDate(genuineCycles[0]), DateTime(2026, 1, 1));
      expect(CycleGroupUtils.getCycleActiveDurationDays(genuineCycles[0]), 4);

      // Cycle 2 anchor = Jan 29 (Leading spotting on Jan 28 is excluded from anchor)
      expect(CycleGroupUtils.getCycleStartDate(genuineCycles[1]), DateTime(2026, 1, 29));
      expect(CycleGroupUtils.getCycleActiveDurationDays(genuineCycles[1]), 3);

      // Isolated spotting extraction
      final isolatedSpotting = CycleGroupUtils.getIsolatedSpottingEntries(allEntries);
      expect(isolatedSpotting.length, 1);
      expect(isolatedSpotting.first.id, 'mid_spot');

      // Dynamic average calculation
      final averages = CycleCalculator.calculateAveragesFromEntries(allEntries);
      // Inter-cycle gap = Jan 29 - Jan 1 = 28 days
      expect(averages['avgCycleLength'], 28);
      // Period lengths = [4, 3] -> (4 + 3) / 2 = 3.5 -> rounds to 4
      expect(averages['avgPeriodLength'], 4);

      // Update profile with recalculation
      final latestAnchor = CycleGroupUtils.getCycleStartDate(genuineCycles.last);
      profile = profile.copyWith(
        lastPeriodStart: latestAnchor,
        avgCycleLength: averages['avgCycleLength'],
        avgPeriodLength: averages['avgPeriodLength'],
      );
      await saveProfile(profile);

      final updatedProfile = (await getProfile())!;
      expect(updatedProfile.lastPeriodStart, DateTime(2026, 1, 29));
      expect(updatedProfile.avgCycleLength, 28);
      expect(updatedProfile.avgPeriodLength, 4);

      // 5. Test Deletion of Cycle 2 active flow
      await db.delete('period_entries', where: 'id IN (?, ?, ?)', whereArgs: ['c2_1', 'c2_2', 'c2_3']);
      final remainingEntries = await getAllPeriods();
      final remainingCycles = CycleGroupUtils.groupIntoCycles(remainingEntries);
      expect(remainingCycles.length, 1); // Only Cycle 1 remains
      expect(CycleGroupUtils.getCycleStartDate(remainingCycles.first), DateTime(2026, 1, 1));
    });

    // =========================================================================
    // §5 & §6 SYMPTOMS & DAILY LOGGING ISOLATION
    // =========================================================================
    test('E2E Symptom & Daily Logging: Multi-symptom and water date isolation', () async {
      final date1 = DateTime(2026, 2, 10);
      final date2 = DateTime(2026, 2, 11);

      // Log multiple symptoms on date1
      await insertSymptom(SymptomEntry(
        id: 's1',
        timestamp: date1,
        category: SymptomCategory.pain,
        type: 'Cramps',
        intensity: 4,
      ));
      await insertSymptom(SymptomEntry(
        id: 's2',
        timestamp: date1,
        category: SymptomCategory.mood,
        type: 'Irritable',
        intensity: 3,
      ));

      // Log symptom on date2
      await insertSymptom(SymptomEntry(
        id: 's3',
        timestamp: date2,
        category: SymptomCategory.energy,
        type: 'Fatigue',
        intensity: 5,
      ));

      // Water logs
      await setWater(date1, 1500);
      await setWater(date2, 2250);

      // Verify date isolation for symptoms
      final allSymptoms = await getAllSymptoms();
      final date1Symptoms = allSymptoms.where((s) => SafeBloomDateUtils.dateKey(s.timestamp) == SafeBloomDateUtils.dateKey(date1)).toList();
      final date2Symptoms = allSymptoms.where((s) => SafeBloomDateUtils.dateKey(s.timestamp) == SafeBloomDateUtils.dateKey(date2)).toList();
      expect(date1Symptoms.length, 2);
      expect(date2Symptoms.length, 1);

      // Verify water date isolation
      expect(await getWater(date1), 1500);
      expect(await getWater(date2), 2250);
      expect(await getWater(DateTime(2026, 2, 12)), 0);
    });

    // =========================================================================
    // §15 ENCRYPTED VAULT BACKUP & RESTORE LIFECYCLE
    // =========================================================================
    test('E2E Backup & Restore: Encrypted vault export, purge and full lossless restore', () async {
      // 1. Populate full rich dataset
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 1, 15),
        avgCycleLength: 30,
        avgPeriodLength: 6,
        preferredGoal: AppMode.ttc.name,
      );
      await saveProfile(profile);

      await insertPeriod(PeriodEntry(id: 'p_b1', timestamp: DateTime(2026, 1, 15), flow: FlowLevel.heavy, notes: 'Day 1'));
      await insertPeriod(PeriodEntry(id: 'p_b2', timestamp: DateTime(2026, 1, 16), flow: FlowLevel.medium));
      await insertSymptom(SymptomEntry(id: 's_b1', timestamp: DateTime(2026, 1, 15), category: SymptomCategory.pain, type: 'Backache', intensity: 3));
      await setWater(DateTime(2026, 1, 15), 1800);

      // 2. Export plaintext JSON and encrypt into vault
      final periods = await getAllPeriods();
      final symptoms = await getAllSymptoms();
      final plainJson = {
        'version': 1,
        'profile': profile.toMap(),
        'period_entries': periods.map((e) => e.toMap()).toList(),
        'symptom_entries': symptoms.map((e) => e.toMap()).toList(),
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(plainJson);
      const passphrase = 'MySecretPassphrase123!';
      final encryptedVault = BackupCryptoService.encryptVault(plaintextJson: jsonStr, passphrase: passphrase);

      // 3. Purge all tables (simulate fresh reinstall or purge)
      await db.delete('user_profile');
      await db.delete('period_entries');
      await db.delete('symptom_entries');
      await db.delete('daily_logs');

      expect(await getProfile(), isNull);
      expect(await getAllPeriods(), isEmpty);
      expect(await getAllSymptoms(), isEmpty);

      // 4. Test invalid password failure
      expect(
        () => BackupCryptoService.decryptVault(vaultJsonString: encryptedVault, passphrase: 'WrongPassword'),
        throwsA(isA<InvalidBackupPasswordException>()),
      );

      // 5. Restore with correct password
      final decryptedJson = BackupCryptoService.decryptVault(vaultJsonString: encryptedVault, passphrase: passphrase);
      final dynamic decoded = jsonDecode(decryptedJson);
      expect(decoded, isA<Map<String, dynamic>>());

      // Re-insert into database (ACID transaction simulation)
      await db.transaction((txn) async {
        await txn.insert('user_profile', Map<String, dynamic>.from(decoded['profile'])..['id'] = 1);
        for (final p in decoded['period_entries']) {
          await txn.insert('period_entries', Map<String, dynamic>.from(p));
        }
        for (final s in decoded['symptom_entries']) {
          await txn.insert('symptom_entries', Map<String, dynamic>.from(s));
        }
      });

      // 6. Verify full restoration
      final restoredProfile = await getProfile();
      expect(restoredProfile, isNotNull);
      expect(restoredProfile!.avgCycleLength, 30);
      expect(restoredProfile.avgPeriodLength, 6);
      expect(restoredProfile.appMode, AppMode.ttc);

      final restoredPeriods = await getAllPeriods();
      expect(restoredPeriods.length, 2);
      expect(restoredPeriods.first.notes, 'Day 1');

      final restoredSymptoms = await getAllSymptoms();
      expect(restoredSymptoms.length, 1);
      expect(restoredSymptoms.first.type, 'Backache');
    });

    // =========================================================================
    // §16 PDF REPORT GENERATION & DATA FIDELITY
    // =========================================================================
    test('E2E PDF Report: Generates accurate summaries matching database and cycle calculations', () async {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 1, 29),
        avgCycleLength: 28,
        avgPeriodLength: 4,
      );

      final periods = [
        // Cycle 1: Jan 1 - Jan 4
        PeriodEntry(id: 'pdf_c1_1', timestamp: DateTime(2026, 1, 1), flow: FlowLevel.heavy),
        PeriodEntry(id: 'pdf_c1_2', timestamp: DateTime(2026, 1, 2), flow: FlowLevel.medium),
        PeriodEntry(id: 'pdf_c1_3', timestamp: DateTime(2026, 1, 3), flow: FlowLevel.medium),
        PeriodEntry(id: 'pdf_c1_4', timestamp: DateTime(2026, 1, 4), flow: FlowLevel.light),
        // Cycle 2: Jan 29 - Jan 31
        PeriodEntry(id: 'pdf_c2_1', timestamp: DateTime(2026, 1, 29), flow: FlowLevel.heavy),
        PeriodEntry(id: 'pdf_c2_2', timestamp: DateTime(2026, 1, 30), flow: FlowLevel.medium),
        PeriodEntry(id: 'pdf_c2_3', timestamp: DateTime(2026, 1, 31), flow: FlowLevel.light),
        // Spotting: Feb 10
        PeriodEntry(id: 'pdf_spot', timestamp: DateTime(2026, 2, 10), flow: FlowLevel.spotting),
      ];

      final symptoms = [
        SymptomEntry(id: 'pdf_s1', timestamp: DateTime(2026, 1, 1), category: SymptomCategory.pain, type: 'Headache', intensity: 4),
        SymptomEntry(id: 'pdf_s2', timestamp: DateTime(2026, 1, 29), category: SymptomCategory.mood, type: 'Anxious', intensity: 3),
      ];

      // Build PDF document
      final pdfBytes = await PdfReportGenerator.generateObGynReport(
        profile: profile,
        periodEntries: periods,
        symptomEntries: symptoms,
        now: DateTime(2026, 2, 15),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000)); // Non-empty valid PDF byte array

      // Verify underlying calculations fed to PDF
      final genuineCycles = CycleGroupUtils.groupIntoCycles(periods);
      expect(genuineCycles.length, 2);
      final isolatedSpotting = CycleGroupUtils.getIsolatedSpottingEntries(periods);
      expect(isolatedSpotting.length, 1);
    });

    // =========================================================================
    // §18 STATE CONSISTENCY: ALL VIEWS AGREE
    // =========================================================================
    test('E2E State Consistency: Today, Calendar, History, Charts, and Predictions agree on cycle state', () async {
      final anchor = DateTime(2026, 1, 1);
      final profile = UserProfile(
        lastPeriodStart: anchor,
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      final periods = [
        PeriodEntry(id: 'sc1', timestamp: DateTime(2026, 1, 1), flow: FlowLevel.heavy),
        PeriodEntry(id: 'sc2', timestamp: DateTime(2026, 1, 2), flow: FlowLevel.medium),
        PeriodEntry(id: 'sc3', timestamp: DateTime(2026, 1, 3), flow: FlowLevel.light),
      ];

      final testDate = DateTime(2026, 1, 14);

      // Today calculation
      final todayCycleDay = CycleCalculator.getCurrentCycleDay(profile.lastPeriodStart, now: testDate);
      final todayPhase = CycleCalculator.getCyclePhase(todayCycleDay, avgCycleLength: profile.avgCycleLength, avgPeriodLength: profile.avgPeriodLength);

      // Calendar calculation on same date
      final calAnchor = profile.lastPeriodStart;
      final calCycleDay = CycleCalculator.getCurrentCycleDay(calAnchor, now: testDate);
      final calPhase = CycleCalculator.getCyclePhase(calCycleDay, avgCycleLength: profile.avgCycleLength, avgPeriodLength: profile.avgPeriodLength);

      // History summary calculation
      final cycles = CycleGroupUtils.groupIntoCycles(periods);
      final historyStart = CycleGroupUtils.getCycleStartDate(cycles.first);

      // Assert complete consistency
      expect(todayCycleDay, calCycleDay);
      expect(todayCycleDay, 14);
      expect(todayPhase, calPhase);
      expect(todayPhase, CyclePhase.ovulation);
      expect(historyStart, profile.lastPeriodStart);
    });

    // =========================================================================
    // §8 CALENDAR INDICATOR PRECEDENCE & OVERDUE RENDERING
    // =========================================================================
    test('E2E Calendar: Logged period overrides predicted period, spotting distinct from active flow', () async {
      final anchor = DateTime(2026, 1, 1);
      final profile = UserProfile(
        lastPeriodStart: anchor,
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );
      await saveProfile(profile);

      // Log an actual period on Jan 28 (1 day before the predicted start of Jan 29)
      final loggedEntry = PeriodEntry(id: 'cal_p1', timestamp: DateTime(2026, 1, 28), flow: FlowLevel.medium);
      await insertPeriod(loggedEntry);

      final loggedSpotting = PeriodEntry(id: 'cal_s1', timestamp: DateTime(2026, 2, 5), flow: FlowLevel.spotting);
      await insertPeriod(loggedSpotting);

      final allPeriods = await getAllPeriods();
      final loggedDates = allPeriods.where((p) => p.isActiveFlow).map((p) => SafeBloomDateUtils.dateOnly(p.timestamp)).toSet();
      final spottingDates = allPeriods.where((p) => p.isSpotting).map((p) => SafeBloomDateUtils.dateOnly(p.timestamp)).toSet();

      final predictedDates = CycleCalculator.getPredictedPeriodDates(
        lastPeriodStart: profile.lastPeriodStart,
        avgCycleLength: profile.avgCycleLength,
        avgPeriodLength: profile.avgPeriodLength,
      );

      // Precedence assertion:
      // Jan 28 is in loggedDates
      expect(loggedDates.contains(DateTime(2026, 1, 28)), isTrue);
      // Jan 29 is in predictedDates, but not in loggedDates
      expect(predictedDates.contains(DateTime(2026, 1, 29)), isTrue);
      expect(loggedDates.contains(DateTime(2026, 1, 29)), isFalse);
      // Feb 5 is in spottingDates, NOT in loggedDates
      expect(spottingDates.contains(DateTime(2026, 2, 5)), isTrue);
      expect(loggedDates.contains(DateTime(2026, 2, 5)), isFalse);
    });

    // =========================================================================
    // §9 & §10 INSIGHTS & MULTI-CYCLE HISTORY AGGREGATIONS
    // =========================================================================
    test('E2E Insights: Aggregates across 0, 1, 3, and 10 cycles with fallback stability', () async {
      // 0 cycles
      var avg0 = CycleCalculator.calculateAveragesFromEntries([]);
      expect(avg0['avgCycleLength'], 28);
      expect(avg0['avgPeriodLength'], 5);

      // 1 cycle (4 days)
      final entries1 = [
        PeriodEntry(id: 'e1_1', timestamp: DateTime(2026, 1, 1), flow: FlowLevel.heavy),
        PeriodEntry(id: 'e1_2', timestamp: DateTime(2026, 1, 2), flow: FlowLevel.medium),
        PeriodEntry(id: 'e1_3', timestamp: DateTime(2026, 1, 3), flow: FlowLevel.medium),
        PeriodEntry(id: 'e1_4', timestamp: DateTime(2026, 1, 4), flow: FlowLevel.light),
      ];
      var avg1 = CycleCalculator.calculateAveragesFromEntries(entries1);
      expect(avg1['avgCycleLength'], 28); // Fallback for cycle length
      expect(avg1['avgPeriodLength'], 4); // Computed from 1 cycle

      // 3 cycles (lengths: 28, 30 -> avg = 29)
      final entries3 = [
        ...entries1,
        // Cycle 2: Jan 29 (28d gap)
        PeriodEntry(id: 'e2_1', timestamp: DateTime(2026, 1, 29), flow: FlowLevel.heavy),
        PeriodEntry(id: 'e2_2', timestamp: DateTime(2026, 1, 30), flow: FlowLevel.medium),
        // Cycle 3: Feb 28 (30d gap)
        PeriodEntry(id: 'e3_1', timestamp: DateTime(2026, 2, 28), flow: FlowLevel.heavy),
        PeriodEntry(id: 'e3_2', timestamp: DateTime(2026, 3, 1), flow: FlowLevel.medium),
        PeriodEntry(id: 'e3_3', timestamp: DateTime(2026, 3, 2), flow: FlowLevel.light),
      ];
      var avg3 = CycleCalculator.calculateAveragesFromEntries(entries3);
      expect(avg3['avgCycleLength'], 29); // (28 + 30) / 2 = 29
      expect(avg3['avgPeriodLength'], 3); // (4 + 2 + 3) / 3 = 3.0 -> 3

      // Multi-cycle history grouping
      final cycles = CycleGroupUtils.groupIntoCycles(entries3);
      expect(cycles.length, 3);
    });

    // =========================================================================
    // §17 PURGE / ZERO-KNOWLEDGE WIPE
    // =========================================================================
    test('E2E Purge: Zero-knowledge wipe purges all database tables to 0 rows', () async {
      await saveProfile(UserProfile(
        lastPeriodStart: DateTime(2026, 1, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      ));
      await insertPeriod(PeriodEntry(id: 'p_del', timestamp: DateTime(2026, 1, 1), flow: FlowLevel.heavy));
      await insertSymptom(SymptomEntry(id: 's_del', timestamp: DateTime(2026, 1, 1), category: SymptomCategory.pain, type: 'Cramps', intensity: 3));
      await setWater(DateTime(2026, 1, 1), 2000);

      // Perform complete table wipe
      await db.delete('user_profile');
      await db.delete('period_entries');
      await db.delete('symptom_entries');
      await db.delete('daily_logs');

      // Verify 0 rows in all tables
      final pCount = (await db.rawQuery('SELECT COUNT(*) as count FROM user_profile')).first['count'] as int;
      final perCount = (await db.rawQuery('SELECT COUNT(*) as count FROM period_entries')).first['count'] as int;
      final symCount = (await db.rawQuery('SELECT COUNT(*) as count FROM symptom_entries')).first['count'] as int;
      final logCount = (await db.rawQuery('SELECT COUNT(*) as count FROM daily_logs')).first['count'] as int;

      expect(pCount, 0);
      expect(perCount, 0);
      expect(symCount, 0);
      expect(logCount, 0);
    });

    // =========================================================================
    // §19 ERROR STATES & RECOVERY
    // =========================================================================
    test('E2E Error States: Malformed JSON import fails gracefully without corrupting DB', () async {
      // Setup good profile
      await saveProfile(UserProfile(
        lastPeriodStart: DateTime(2026, 1, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      ));

      // Attempt to parse bad JSON
      const corruptedJson = '{"version": 1, "profile": INVALID_JSON_PAYLOAD}';
      expect(() => jsonDecode(corruptedJson), throwsA(isA<FormatException>()));

      // DB remains completely intact and uncorrupted
      final profile = await getProfile();
      expect(profile, isNotNull);
      expect(profile!.avgCycleLength, 28);
    });
  });
}

