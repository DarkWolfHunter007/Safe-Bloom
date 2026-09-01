import 'dart:math';

final _random = Random.secure();

/// Generates a cryptographically secure 128-bit random unique ID.
String generateUniqueId([String prefix = '']) {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return prefix.isNotEmpty ? '${prefix}_$hex' : hex;
}

class IdGenerator {
  static String newId([String prefix = '']) => generateUniqueId(prefix);
}
