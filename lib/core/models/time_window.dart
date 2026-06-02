class TimeWindow {
  final String id;
  final List<int> days;
  final int startMinutes;
  final int endMinutes;

  const TimeWindow({
    required this.id,
    required this.days,
    required this.startMinutes,
    required this.endMinutes,
  });

  TimeWindow copyWith({
    String? id,
    List<int>? days,
    int? startMinutes,
    int? endMinutes,
  }) {
    return TimeWindow(
      id: id ?? this.id,
      days: days ?? this.days,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'days': days,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final parsedDays = <int>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        final v = (d as num?)?.toInt();
        if (v != null && v >= 1 && v <= 7) parsedDays.add(v);
      }
    }
    return TimeWindow(
      id: (json['id'] as String?) ?? 'window',
      days: parsedDays.isEmpty ? <int>[1, 2, 3, 4, 5] : parsedDays,
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? (9 * 60),
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? (18 * 60),
    );
  }
}
