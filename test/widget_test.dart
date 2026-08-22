import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/theme/app_theme.dart';
import 'package:safe_bloom/features/onboarding/presentation/views/onboarding_view.dart';

void main() {
  testWidgets('App root smoke test: renders OnboardingView with full theme and privacy options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingView(),
      ),
    );
    await tester.pump();

    expect(find.byType(OnboardingView), findsOneWidget);
    expect(find.text('Welcome to Safe Bloom'), findsOneWidget);
    expect(find.text('Your Cycle. Your Privacy. Your Power.'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_start_fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_restore_vault')), findsOneWidget);
    expect(find.text('256-Bit AES Hardware Encrypted'), findsOneWidget);
  });
}
