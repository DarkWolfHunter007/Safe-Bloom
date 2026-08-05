enum SymptomCategory { pain, mood, energy, sleep, skin, intimate, exercise, custom }

class SymptomEntry {
  final String id;
  final DateTime timestamp;
  final SymptomCategory category;
  final String type;
  final int intensity;
  final String? notes;

  SymptomEntry({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.type,
    this.intensity = 3,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'category': category.name,
      'type': type,
      'intensity': intensity,
      'notes': notes,
    };
  }

  factory SymptomEntry.fromMap(Map<String, dynamic> map) {
    return SymptomEntry(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      category: SymptomCategory.values.firstWhere((e) => e.name == map['category']),
      type: map['type'],
      intensity: map['intensity'],
      notes: map['notes'],
    );
  }
}
