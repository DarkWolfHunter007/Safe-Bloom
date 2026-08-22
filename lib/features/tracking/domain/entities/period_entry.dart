enum FlowLevel { spotting, light, medium, heavy }

extension FlowLevelExtension on FlowLevel {
  bool get isActiveFlow =>
      this == FlowLevel.light || this == FlowLevel.medium || this == FlowLevel.heavy;
  bool get isSpotting => this == FlowLevel.spotting;
}

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

  bool get isActiveFlow => flow.isActiveFlow;
  bool get isSpotting => flow.isSpotting;

  PeriodEntry copyWith({
    String? id,
    DateTime? timestamp,
    FlowLevel? flow,
    String? notes,
  }) {
    return PeriodEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      flow: flow ?? this.flow,
      notes: notes ?? this.notes,
    );
  }

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
