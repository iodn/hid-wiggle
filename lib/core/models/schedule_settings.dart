import 'time_window.dart';

class ScheduleSettings {
  final List<TimeWindow> windows;
  final int autoStopMinutes;
  final bool pauseWhenScreenOff;
  final bool pauseWhenCharging;
  final bool pauseWhenBatteryLow;

  const ScheduleSettings({
    required this.windows,
    required this.autoStopMinutes,
    required this.pauseWhenScreenOff,
    required this.pauseWhenCharging,
    required this.pauseWhenBatteryLow,
  });

  factory ScheduleSettings.defaults() => ScheduleSettings(
        windows: const [
          TimeWindow(
            id: 'weekday_9_18',
            days: [1, 2, 3, 4, 5],
            startMinutes: 9 * 60,
            endMinutes: 18 * 60,
          ),
        ],
        autoStopMinutes: 0,
        pauseWhenScreenOff: true,
        pauseWhenCharging: false,
        pauseWhenBatteryLow: true,
      );

  ScheduleSettings copyWith({
    List<TimeWindow>? windows,
    int? autoStopMinutes,
    bool? pauseWhenScreenOff,
    bool? pauseWhenCharging,
    bool? pauseWhenBatteryLow,
  }) {
    return ScheduleSettings(
      windows: windows ?? this.windows,
      autoStopMinutes: autoStopMinutes ?? this.autoStopMinutes,
      pauseWhenScreenOff: pauseWhenScreenOff ?? this.pauseWhenScreenOff,
      pauseWhenCharging: pauseWhenCharging ?? this.pauseWhenCharging,
      pauseWhenBatteryLow: pauseWhenBatteryLow ?? this.pauseWhenBatteryLow,
    );
  }

  Map<String, dynamic> toJson() => {
        'windows': windows.map((w) => w.toJson()).toList(),
        'autoStopMinutes': autoStopMinutes,
        'pauseWhenScreenOff': pauseWhenScreenOff,
        'pauseWhenCharging': pauseWhenCharging,
        'pauseWhenBatteryLow': pauseWhenBatteryLow,
      };

  factory ScheduleSettings.fromJson(Map<String, dynamic> json) {
    final rawWindows = json['windows'];
    final windows = <TimeWindow>[];
    if (rawWindows is List) {
      for (final w in rawWindows) {
        if (w is Map<String, dynamic>) {
          windows.add(TimeWindow.fromJson(w));
        } else if (w is Map) {
          windows.add(TimeWindow.fromJson(Map<String, dynamic>.from(w)));
        }
      }
    }
    return ScheduleSettings(
      windows: windows.isEmpty ? ScheduleSettings.defaults().windows : windows,
      autoStopMinutes: (json['autoStopMinutes'] as num?)?.toInt() ?? 0,
      pauseWhenScreenOff: json['pauseWhenScreenOff'] is bool
          ? json['pauseWhenScreenOff'] as bool
          : true,
      pauseWhenCharging:
          json['pauseWhenCharging'] is bool ? json['pauseWhenCharging'] as bool : false,
      pauseWhenBatteryLow: json['pauseWhenBatteryLow'] is bool
          ? json['pauseWhenBatteryLow'] as bool
          : true,
    );
  }
}
