import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeBloomApp());
    expect(find.text('Safe Bloom'), findsWidgets);
  });
}
