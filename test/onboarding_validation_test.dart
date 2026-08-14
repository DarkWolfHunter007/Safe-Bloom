import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/onboarding/presentation/views/onboarding_view.dart';

void main() {
  testWidgets('OnboardingView requires mandatory Last Period Start Date selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingView(),
      ),
    );

    // Step 1: Welcome Screen -> Click CONTINUE
    expect(find.text('Welcome to Safe Bloom'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    // Step 2: Last Period Start Date Screen
    expect(find.text('When did your last period start?'), findsOneWidget);
    expect(find.text('No Date Selected'), findsOneWidget);

    // Try tapping CONTINUE without selecting a date
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    // Should remain on Step 2 and display validation SnackBar
    expect(find.text('Please select when your last period started to continue.'), findsOneWidget);
    expect(find.text('When did your last period start?'), findsOneWidget);

    // Wait for SnackBar to dismiss
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Tap SELECT DATE to open date picker dialog
    await tester.tap(find.text('SELECT DATE'));
    await tester.pumpAndSettle();

    // Confirm date picker dialog (OK button)
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Verify date is now selected (no longer "No Date Selected")
    expect(find.text('No Date Selected'), findsNothing);
    expect(find.text('CHANGE DATE'), findsOneWidget);

    // Now tap CONTINUE -> Should successfully advance to Step 3 (Cycle Duration)
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('How long is your typical cycle?'), findsOneWidget);
  });

  testWidgets('OnboardingView allows skipping period start date with default option', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingView(),
      ),
    );

    // Step 1: Welcome Screen -> Click CONTINUE
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    // Verify Skip option is visible on period start step
    expect(find.text('Not sure? Skip with default (14 days ago)'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);

    // Tap 'Not sure? Skip with default'
    await tester.tap(find.text('Not sure? Skip with default (14 days ago)'));
    await tester.pumpAndSettle();

    // Advances to Cycle Duration step
    expect(find.text('How long is your typical cycle?'), findsOneWidget);
  });
}
