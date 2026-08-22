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

    // Step 0: Welcome & Privacy Screen -> Click 'Start Fresh'
    expect(find.byKey(const ValueKey('onboarding_start_fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_restore_vault')), findsOneWidget);
    expect(find.text('256-Bit AES Hardware Encrypted'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_start_fresh')));
    await tester.pumpAndSettle();

    // Step 1: Last Period Start Date Screen
    expect(find.text('When did your last period start?'), findsOneWidget);
    expect(find.text('No Date Selected'), findsOneWidget);

    // Try tapping CONTINUE without selecting a date
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    // Should remain on Step 1 and display validation SnackBar
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

    // Now tap CONTINUE -> Should successfully advance to Step 2 (Cycle Duration)
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

    // Step 0: Start Fresh -> Click 'Start Fresh'
    await tester.tap(find.byKey(const ValueKey('onboarding_start_fresh')));
    await tester.pumpAndSettle();

    // Step 1: Period Start Date Screen -> Verify Skip option
    expect(find.text('Not sure? Skip with default (14 days ago)'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);

    // Tap 'Not sure? Skip with default'
    await tester.tap(find.text('Not sure? Skip with default (14 days ago)'));
    await tester.pumpAndSettle();

    // Advances to Cycle Duration step
    expect(find.text('How long is your typical cycle?'), findsOneWidget);
  });
}
