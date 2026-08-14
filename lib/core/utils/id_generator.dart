import 'dart:math';

class IdGenerator {
  static final _random = Random.secure();

  /// Generates a collision-resistant unique ID combining timestamp and secure random bits.
  static String newId([String prefix = '']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = _random.nextInt(999999);
    return prefix.isNotEmpty
        ? '${prefix}_${timestamp}_$randomNum'
        : '${timestamp}_$randomNum';
  }
}
