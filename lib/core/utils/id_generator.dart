import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID v4 unique ID with an optional prefix.
/// UUID v4 provides 122 bits of randomness — collision-safe even at high write rates.
String generateUniqueId([String prefix = '']) {
  final id = _uuid.v4();
  return prefix.isNotEmpty ? '${prefix}_$id' : id;
}

class IdGenerator {
  static String newId([String prefix = '']) => generateUniqueId(prefix);
}
