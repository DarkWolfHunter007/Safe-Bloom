import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/security/presentation/views/biometric_lock_screen.dart';

void main() {
  testWidgets('BiometricLockScreen renders UI elements correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BiometricLockScreen(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify brand titles and text
    expect(find.text('Safe Bloom'), findsOneWidget);
    expect(find.text('YOUR CYCLE. YOUR PRIVACY. YOUR POWER.'), findsOneWidget);
    expect(find.text('App Secured'), findsOneWidget);

    // Verify logo image
    expect(find.byType(Image), findsOneWidget);

    // Verify unlock button presence
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
