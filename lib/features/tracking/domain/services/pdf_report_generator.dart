import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../entities/period_entry.dart';
import '../entities/symptom_entry.dart';
import '../entities/user_profile.dart';
import 'cycle_calculator.dart';

class CycleHistorySummary {
  final int cycleNumber;
  final DateTime startDate;
  final DateTime endDate;
  final int periodDurationDays;
  final int? cycleLengthDays;
  final FlowLevel maxFlow;
  final List<String> notes;

  CycleHistorySummary({
    required this.cycleNumber,
    required this.startDate,
    required this.endDate,
    required this.periodDurationDays,
    this.cycleLengthDays,
    required this.maxFlow,
    required this.notes,
  });
}

class SymptomFrequencySummary {
  final String type;
  final SymptomCategory category;
  final int count;
  final double avgIntensity;
  final List<String> notes;

  SymptomFrequencySummary({
    required this.type,
    required this.category,
    required this.count,
    required this.avgIntensity,
    required this.notes,
  });
}

class PdfReportGenerator {
  // Theme Colors for PDF
  static const _primaryColor = PdfColor.fromInt(0xFF3D1E36);
  static const _accentColor = PdfColor.fromInt(0xFFE85D75);
  static const _textMainColor = PdfColor.fromInt(0xFF2B1627);
  static const _textMutedColor = PdfColor.fromInt(0xFF786273);
  static const _cardBgColor = PdfColor.fromInt(0xFFFFF6F8);
  static const _borderLineColor = PdfColor.fromInt(0xFFF4E1EC);

  /// Generates a PDF byte array containing an OB-GYN Medical Report.
  static Future<Uint8List> generateObGynReport({
    required UserProfile profile,
    required List<PeriodEntry> periodEntries,
    required List<SymptomEntry> symptomEntries,
    DateTime? now,
  }) async {
    final reportDate = now ?? DateTime.now();
    final cutoffDate = reportDate.subtract(const Duration(days: 180));
    final dateFormat = DateFormat('MMM dd, yyyy');

    // 1. Calculate dynamic averages
    final dynamicAverages = CycleCalculator.calculateAveragesFromEntries(periodEntries);
    final avgCycle = dynamicAverages['avgCycleLength'] ?? profile.avgCycleLength;
    final avgPeriod = dynamicAverages['avgPeriodLength'] ?? profile.avgPeriodLength;

    // 2. Filter 6-month entries
    final sixMonthPeriodEntries = periodEntries
        .where((e) => e.timestamp.isAfter(cutoffDate) || e.timestamp.isAtSameMomentAs(cutoffDate))
        .toList();

    final sixMonthSymptomEntries = symptomEntries
        .where((e) => e.timestamp.isAfter(cutoffDate) || e.timestamp.isAtSameMomentAs(cutoffDate))
        .toList();

    // 3. Process 6-Month Cycle History
    final sortedPeriodEntries = List<PeriodEntry>.from(periodEntries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<List<PeriodEntry>> allCycles = [];
    List<PeriodEntry> currentCycle = [];

    for (final entry in sortedPeriodEntries) {
      if (currentCycle.isEmpty) {
        currentCycle.add(entry);
      } else {
        final prev = currentCycle.last;
        if (entry.timestamp.difference(prev.timestamp).inDays <= 2) {
          currentCycle.add(entry);
        } else {
          allCycles.add(currentCycle);
          currentCycle = [entry];
        }
      }
    }
    if (currentCycle.isNotEmpty) {
      allCycles.add(currentCycle);
    }

    final List<CycleHistorySummary> cycleSummaries = [];
    for (int i = 0; i < allCycles.length; i++) {
      final cycle = allCycles[i];
      final startDate = cycle.first.timestamp;
      final endDate = cycle.last.timestamp;
      
      // Check if cycle overlaps with 6-month window or fallback to all cycles if recent
      if (endDate.isAfter(cutoffDate) || i >= allCycles.length - 6) {
        int? cycleLengthDays;
        if (i > 0) {
          cycleLengthDays = startDate.difference(allCycles[i - 1].first.timestamp).inDays;
        }

        // Determine max flow level and collect non-empty user notes
        FlowLevel maxFlow = FlowLevel.spotting;
        final notesList = <String>[];
        for (final e in cycle) {
          if (e.flow.index > maxFlow.index) {
            maxFlow = e.flow;
          }
          final note = e.notes?.trim() ?? '';
          if (note.isNotEmpty && note != 'Logged from Calendar View' && note != 'Initial onboarding period entry') {
            notesList.add(note);
          }
        }

        cycleSummaries.add(
          CycleHistorySummary(
            cycleNumber: i + 1,
            startDate: startDate,
            endDate: endDate,
            periodDurationDays: cycle.length,
            cycleLengthDays: cycleLengthDays,
            maxFlow: maxFlow,
            notes: notesList.toSet().toList(),
          ),
        );
      }
    }

    // Sort cycle summaries descending by cycle number for report presentation
    cycleSummaries.sort((a, b) => b.cycleNumber.compareTo(a.cycleNumber));

    // 4. Process Flow Statistics (Last 6 Months)
    final flowCounts = {
      FlowLevel.spotting: 0,
      FlowLevel.light: 0,
      FlowLevel.medium: 0,
      FlowLevel.heavy: 0,
    };

    final flowEntriesToAnalyze = sixMonthPeriodEntries.isNotEmpty ? sixMonthPeriodEntries : periodEntries;
    for (final e in flowEntriesToAnalyze) {
      flowCounts[e.flow] = (flowCounts[e.flow] ?? 0) + 1;
    }
    final totalFlowDays = flowEntriesToAnalyze.length;

    // 5. Process Symptom Frequencies (Last 6 Months)
    final Map<String, List<SymptomEntry>> groupedSymptoms = {};
    final symptomEntriesToAnalyze = sixMonthSymptomEntries.isNotEmpty ? sixMonthSymptomEntries : symptomEntries;

    for (final e in symptomEntriesToAnalyze) {
      groupedSymptoms.putIfAbsent(e.type, () => []).add(e);
    }

    final List<SymptomFrequencySummary> symptomSummaries = [];
    groupedSymptoms.forEach((type, entries) {
      final category = entries.first.category;
      final count = entries.length;
      final avgIntensity = entries.fold<double>(0.0, (sum, e) => sum + e.intensity) / count;
      final notes = entries
          .map((e) => e.notes?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();

      symptomSummaries.add(
        SymptomFrequencySummary(
          type: type,
          category: category,
          count: count,
          avgIntensity: avgIntensity,
          notes: notes,
        ),
      );
    });

    symptomSummaries.sort((a, b) => b.count.compareTo(a.count));

    // 6. Build Document
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OB-GYN MEDICAL REPORT',
                        style: const pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      pw.Text(
                        'SafeBloom Menstrual & Reproductive Health Record',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: _accentColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Report Date: ${dateFormat.format(reportDate)}',
                        style: const pw.TextStyle(fontSize: 9, color: _textMutedColor),
                      ),
                      pw.Text(
                        'Confidential Clinical Document',
                        style: const pw.TextStyle(fontSize: 8, color: _textMutedColor, fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: _borderLineColor, thickness: 1),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: _borderLineColor, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SafeBloom - Private & Encrypted Health Summary',
                    style: const pw.TextStyle(fontSize: 8, color: _textMutedColor),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: _textMutedColor),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Patient & Summary Overview Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _cardBgColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _borderLineColor),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatPill('AVG CYCLE LENGTH', '$avgCycle Days', _primaryColor, _textMutedColor),
                  _buildStatPill('AVG PERIOD DURATION', '$avgPeriod Days', _primaryColor, _textMutedColor),
                  _buildStatPill(
                    'LAST PERIOD START',
                    dateFormat.format(profile.lastPeriodStart),
                    _primaryColor,
                    _textMutedColor,
                  ),
                  _buildStatPill(
                    '6-MO FLOW LOGS',
                    '${sixMonthPeriodEntries.length} Days',
                    _primaryColor,
                    _textMutedColor,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Section 1: 6-Month Cycle History
            pw.Text(
              '1. 6-Month Cycle History',
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Summary of recorded menstrual cycles over the past 180 days.',
              style: const pw.TextStyle(fontSize: 9, color: _textMutedColor),
            ),
            pw.SizedBox(height: 8),

            if (cycleSummaries.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderLineColor),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'No period cycles recorded in the last 6 months.',
                  style: const pw.TextStyle(fontSize: 9, color: _textMutedColor, fontStyle: pw.FontStyle.italic),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: _borderLineColor, width: 0.5),
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primaryColor, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: _cardBgColor),
                cellStyle: const pw.TextStyle(fontSize: 8.5, color: _textMainColor),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(45),
                  1: const pw.FlexColumnWidth(1.8),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.4),
                  4: const pw.FlexColumnWidth(1.4),
                  5: const pw.FlexColumnWidth(1.4),
                  6: const pw.FlexColumnWidth(2.5),
                },
                headers: ['Cycle #', 'Start Date', 'End Date', 'Active Days', 'Cycle Length', 'Max Flow', 'Period Notes'],
                data: cycleSummaries.map((c) {
                  final flowName = c.maxFlow.name[0].toUpperCase() + c.maxFlow.name.substring(1);
                  final lengthText = c.cycleLengthDays != null ? '${c.cycleLengthDays} days' : 'N/A';
                  final notesText = c.notes.isNotEmpty ? c.notes.join('; ') : '-';
                  return [
                    'Cycle ${c.cycleNumber}',
                    dateFormat.format(c.startDate),
                    dateFormat.format(c.endDate),
                    '${c.periodDurationDays} days',
                    lengthText,
                    flowName,
                    notesText,
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 16),

            // Section 2: Flow Statistics & Breakdown
            pw.Text(
              '2. Flow Statistics & Distribution',
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Breakdown of recorded period days by flow intensity level.',
              style: const pw.TextStyle(fontSize: 9, color: _textMutedColor),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: _borderLineColor, width: 0.5),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primaryColor, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _cardBgColor),
              cellStyle: const pw.TextStyle(fontSize: 8.5, color: _textMainColor),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Flow Level', 'Total Days Logged', 'Percentage of Flow Days'],
              data: [
                for (final level in FlowLevel.values)
                  [
                    level.name[0].toUpperCase() + level.name.substring(1),
                    '${flowCounts[level] ?? 0} days',
                    totalFlowDays > 0
                        ? '${((flowCounts[level] ?? 0) / totalFlowDays * 100).toStringAsFixed(1)}%'
                        : '0.0%',
                  ],
                [
                  'Total Flow Days Recorded',
                  '$totalFlowDays days',
                  '100.0%',
                ],
              ],
            ),
            pw.SizedBox(height: 16),

            // Section 3: Symptom Frequencies & Severity
            pw.Text(
              '3. Symptom Frequency & Severity Index',
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Reported symptoms grouped by category and average intensity (scale 1 to 5).',
              style: const pw.TextStyle(fontSize: 9, color: _textMutedColor),
            ),
            pw.SizedBox(height: 8),

            if (symptomSummaries.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderLineColor),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'No symptoms logged during this period.',
                  style: const pw.TextStyle(fontSize: 9, color: _textMutedColor, fontStyle: pw.FontStyle.italic),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: _borderLineColor, width: 0.5),
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primaryColor, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: _cardBgColor),
                cellStyle: const pw.TextStyle(fontSize: 8.5, color: _textMainColor),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(3),
                },
                headers: ['Symptom', 'Category', 'Occurrences', 'Avg. Intensity', 'Notes / Annotations'],
                data: symptomSummaries.map((s) {
                  final catName = s.category.name[0].toUpperCase() + s.category.name.substring(1);
                  final notesText = s.notes.isNotEmpty ? s.notes.join('; ') : '-';
                  return [
                    s.type,
                    catName,
                    '${s.count} times',
                    '${s.avgIntensity.toStringAsFixed(1)} / 5',
                    notesText,
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 20),

            // Section 4: Clinical Notes & Physician Remarks
            pw.Text(
              '4. Clinical Notes & Observations',
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              height: 100,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderLineColor, style: pw.BorderStyle.dashed),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Physician Notes / Assessment (Space reserved for OB-GYN clinician review):',
                style: const pw.TextStyle(fontSize: 8.5, color: _textMutedColor, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildStatPill(String label, String value, PdfColor valueColor, PdfColor labelColor) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
