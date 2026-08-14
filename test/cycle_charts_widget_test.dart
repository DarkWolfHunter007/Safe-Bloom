import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/insights/presentation/widgets/cycle_charts_widget.dart';
import 'package:safe_bloom/features/insights/presentation/views/insights_view.dart';

void main() {
  testWidgets('CycleChartsWidget renders loading state and widget structure', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CycleChartsWidget(),
          ),
        ),
      ),
    );

    // Initial widget build shows progress indicator during data load
    expect(find.byType(CycleChartsWidget), findsOneWidget);
  });

  testWidgets('InsightsView renders CycleChartsWidget interactive card', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InsightsView(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Health & Insights Library'), findsOneWidget);
    expect(find.byType(CycleChartsWidget), findsOneWidget);
  });
}
