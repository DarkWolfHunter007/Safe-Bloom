enum FlowLevel { spotting, light, medium, heavy }

class PeriodEntry {
  final String id;
  final DateTime timestamp;
  final FlowLevel flow;
  final String? notes;

  PeriodEntry({
    required this.id,
    required this.timestamp,
    required this.flow,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'flow': flow.name,
      'notes': notes,
    };
  }

  factory PeriodEntry.fromMap(Map<String, dynamic> map) {
    return PeriodEntry(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      flow: FlowLevel.values.firstWhere((e) => e.name == map['flow']),
      notes: map['notes'],
    );
  }
}
