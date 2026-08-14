import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/pdf_report_generator.dart';

void main() {
  group('PdfReportGenerator', () {
    test('generateObGynReport creates a valid non-empty PDF Uint8List', () async {
      final now = DateTime(2026, 8, 15);
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      final periodEntries = [
        PeriodEntry(
          id: 'p1',
          timestamp: DateTime(2026, 8, 1),
          flow: FlowLevel.heavy,
        ),
        PeriodEntry(
          id: 'p2',
          timestamp: DateTime(2026, 8, 2),
          flow: FlowLevel.medium,
        ),
        PeriodEntry(
          id: 'p3',
          timestamp: DateTime(2026, 8, 3),
          flow: FlowLevel.light,
        ),
        PeriodEntry(
          id: 'p4',
          timestamp: DateTime(2026, 7, 4),
          flow: FlowLevel.heavy,
        ),
        PeriodEntry(
          id: 'p5',
          timestamp: DateTime(2026, 7, 5),
          flow: FlowLevel.medium,
        ),
      ];

      final symptomEntries = [
        SymptomEntry(
          id: 's1',
          timestamp: DateTime(2026, 8, 1),
          category: SymptomCategory.pain,
          type: 'Cramps',
          intensity: 4,
          notes: 'Severe abdominal pain',
        ),
        SymptomEntry(
          id: 's2',
          timestamp: DateTime(2026, 8, 2),
          category: SymptomCategory.mood,
          type: 'Irritability',
          intensity: 3,
        ),
        SymptomEntry(
          id: 's3',
          timestamp: DateTime(2026, 7, 4),
          category: SymptomCategory.pain,
          type: 'Cramps',
          intensity: 5,
        ),
      ];

      final pdfBytes = await PdfReportGenerator.generateObGynReport(
        profile: profile,
        periodEntries: periodEntries,
        symptomEntries: symptomEntries,
        now: now,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF header magic bytes %PDF-
      expect(pdfBytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('generateObGynReport handles empty period and symptom lists gracefully', () async {
      final now = DateTime(2026, 8, 15);
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      final pdfBytes = await PdfReportGenerator.generateObGynReport(
        profile: profile,
        periodEntries: [],
        symptomEntries: [],
        now: now,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });
  });
}
