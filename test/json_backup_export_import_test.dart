import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';

void main() {
  group('JSON Backup Export & Import Unit Tests', () {
    test('Encodes and decodes complete JSON backup payload accurately', () {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 6, 1),
        avgCycleLength: 29,
        avgPeriodLength: 6,
      );

      final periodEntries = [
        PeriodEntry(id: 'p1', timestamp: DateTime(2026, 6, 1), flow: FlowLevel.heavy, notes: 'Day 1'),
        PeriodEntry(id: 'p2', timestamp: DateTime(2026, 6, 2), flow: FlowLevel.medium, notes: 'Day 2'),
      ];

      final symptomEntries = [
        SymptomEntry(
          id: 's1',
          timestamp: DateTime(2026, 6, 1),
          category: SymptomCategory.pain,
          type: 'Cramps',
          intensity: 3,
        ),
      ];

      final exportPayload = {
        'profile': profile.toMap(),
        'period_entries': periodEntries.map((e) => e.toMap()).toList(),
        'symptom_entries': symptomEntries.map((e) => e.toMap()).toList(),
        'exported_at': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(exportPayload);

      // Verify decoding
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      expect(decoded.containsKey('profile'), isTrue);
      expect(decoded.containsKey('period_entries'), isTrue);
      expect(decoded.containsKey('symptom_entries'), isTrue);

      final restoredProfile = UserProfile.fromMap(Map<String, dynamic>.from(decoded['profile']));
      expect(restoredProfile.avgCycleLength, 29);
      expect(restoredProfile.avgPeriodLength, 6);

      final List periodList = decoded['period_entries'];
      expect(periodList.length, 2);

      final restoredPeriod1 = PeriodEntry.fromMap(Map<String, dynamic>.from(periodList[0]));
      expect(restoredPeriod1.flow, FlowLevel.heavy);

      final List symptomList = decoded['symptom_entries'];
      expect(symptomList.length, 1);

      final restoredSymptom1 = SymptomEntry.fromMap(Map<String, dynamic>.from(symptomList[0]));
      expect(restoredSymptom1.type, 'Cramps');
      expect(restoredSymptom1.intensity, 3);
    });
  });
}
