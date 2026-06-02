import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Formatters {
  static String intervalFromMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000.0;
    if (seconds < 60) {
      final s = seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1);
      return '${s}s';
    }
    final d = Duration(milliseconds: ms);
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  static String px(int value) => '${value}px';

  static String percent(double v) => '${(v * 100).round()}%';

  static String dateTimeShort(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final fmt = DateFormat(isToday ? 'HH:mm:ss' : 'MMM d, HH:mm');
    return fmt.format(dt);
  }

  static String timeOfDay(TimeOfDay t) {
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  static TimeOfDay timeOfDayFromMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  static int minutesFromTimeOfDay(TimeOfDay t) => t.hour * 60 + t.minute;
}
