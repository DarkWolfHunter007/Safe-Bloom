import 'dart:math';

final Random _secureRandom = Random.secure();

/// Generates a collision-resistant unique ID combining timestamp and secure random bits.
String generateUniqueId([String prefix = '']) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomNum = _secureRandom.nextInt(999999);
  return prefix.isNotEmpty ? '${prefix}_${timestamp}_$randomNum' : '${timestamp}_$randomNum';
}

class IdGenerator {
  static String newId([String prefix = '']) => generateUniqueId(prefix);
}
