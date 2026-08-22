import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';

void main() {
  group('AppMode and Goal Mapping Tests', () {
    final baseProfile = UserProfile(
      lastPeriodStart: DateTime(2026, 8, 1),
      avgCycleLength: 28,
      avgPeriodLength: 5,
    );

    test('Defaults to AppMode.trackCycle when preferredGoal is null', () {
      final profile = baseProfile.copyWith(preferredGoal: null);
      expect(profile.appMode, equals(AppMode.trackCycle));
    });

    test('Correctly maps Track Cycle identifiers', () {
      final identifiers = [
        'trackCycle',
        'track_cycle',
        '🌸 Track Cycle & Symptoms',
        'Track Cycle & Symptoms',
        'Track Cycle',
        'Track Period & Ovulation',
        'Track Period',
        '🔒 Private & Anonymous Health Journal',
        '⚡ Manage PMS & Energy Levels',
      ];

      for (final id in identifiers) {
        final profile = baseProfile.copyWith(preferredGoal: id);
        expect(profile.appMode, equals(AppMode.trackCycle), reason: 'Failed for $id');
      }
    });

    test('Correctly maps Try to Conceive (TTC) identifiers', () {
      final identifiers = [
        'ttc',
        'get_pregnant',
        '👶 Conceive / Track Ovulation',
        'Conceive / Track Ovulation',
        'Conceive',
        'Try to Conceive (TTC)',
        'Try to Conceive',
        'TTC (Conception)',
        'TTC',
      ];

      for (final id in identifiers) {
        final profile = baseProfile.copyWith(preferredGoal: id);
        expect(profile.appMode, equals(AppMode.ttc), reason: 'Failed for $id');
      }
    });

    test('Correctly maps Pregnancy identifiers', () {
      final identifiers = [
        'pregnancy',
        'track_pregnancy',
        '🤰 Track Pregnancy',
        'Track Pregnancy',
        'Pregnancy',
      ];

      for (final id in identifiers) {
        final profile = baseProfile.copyWith(preferredGoal: id);
        expect(profile.appMode, equals(AppMode.pregnancy), reason: 'Failed for $id');
      }
    });

    test('Switching between all three modes persists and preserves state', () {
      var profile = baseProfile.copyWith(preferredGoal: AppMode.trackCycle.name);
      expect(profile.appMode, equals(AppMode.trackCycle));

      profile = profile.copyWith(preferredGoal: AppMode.ttc.name);
      expect(profile.appMode, equals(AppMode.ttc));

      profile = profile.copyWith(preferredGoal: AppMode.pregnancy.name);
      expect(profile.appMode, equals(AppMode.pregnancy));

      // Revert back
      profile = profile.copyWith(preferredGoal: AppMode.trackCycle.name);
      expect(profile.appMode, equals(AppMode.trackCycle));
    });

    test('Serialization to and from map preserves enum string representation', () {
      for (final mode in AppMode.values) {
        final profile = baseProfile.copyWith(preferredGoal: mode.name);
        final map = profile.toMap();
        final restored = UserProfile.fromMap(map);

        expect(restored.preferredGoal, equals(mode.name));
        expect(restored.appMode, equals(mode));
      }
    });
  });
}
