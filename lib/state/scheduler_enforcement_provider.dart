import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/schedule_settings.dart';
import '../core/models/time_window.dart';
import '../core/platform/device_state_providers.dart';
import 'app_settings_controller.dart';

@immutable
class SchedulerDeviceSignals {
  final bool supported;
  final bool screenOff;
  final bool charging;
  final bool batteryLow;

  const SchedulerDeviceSignals({
    required this.supported,
    required this.screenOff,
    required this.charging,
    required this.batteryLow,
  });

  const SchedulerDeviceSignals.unsupported()
      : supported = false,
        screenOff = false,
        charging = false,
        batteryLow = false;
}

final schedulerDeviceSignalsProvider = Provider<SchedulerDeviceSignals>((ref) {
  final deviceState = ref.watch(deviceStateProvider);
  return SchedulerDeviceSignals(
    supported: true,
    screenOff: !deviceState.screenOn,
    charging: deviceState.charging,
    batteryLow: deviceState.batteryLow,
  );
});

class JigglerActivatedAt extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
  void clear() => state = null;
}

final jigglerActivatedAtProvider =
    NotifierProvider<JigglerActivatedAt, DateTime?>(JigglerActivatedAt.new);

@immutable
class SchedulerEnforcement {
  final DateTime now;
  final bool isWithinWindowNow;
  final bool shouldPause;
  final bool autoStopTriggered;
  final Duration? autoStopRemaining;
  final Duration? nextWakeDelay;
  final List<String> reasons;
  final bool hasUnimplementedSignals;

  const SchedulerEnforcement({
    required this.now,
    required this.isWithinWindowNow,
    required this.shouldPause,
    required this.autoStopTriggered,
    required this.autoStopRemaining,
    required this.nextWakeDelay,
    required this.reasons,
    required this.hasUnimplementedSignals,
  });

  static SchedulerEnforcement evaluate({
    required DateTime now,
    required ScheduleSettings settings,
    required DateTime? activatedAt,
    required SchedulerDeviceSignals signals,
  }) {
    final within = _isWithinAnyWindow(now, settings.windows);
    final reasons = <String>[];
    var shouldPause = false;

    if (settings.windows.isNotEmpty && !within) {
      shouldPause = true;
      reasons.add('Outside scheduled window');
    }

    var hasUnimplementedSignals = false;
    if ((settings.pauseWhenScreenOff ||
            settings.pauseWhenCharging ||
            settings.pauseWhenBatteryLow) &&
        !signals.supported) {
      hasUnimplementedSignals = true;
    } else if (signals.supported) {
      if (settings.pauseWhenScreenOff && signals.screenOff) {
        shouldPause = true;
        reasons.add('Screen off');
      }
      if (settings.pauseWhenCharging && signals.charging) {
        shouldPause = true;
        reasons.add('Charging');
      }
      if (settings.pauseWhenBatteryLow && signals.batteryLow) {
        shouldPause = true;
        reasons.add('Battery low');
      }
    }

    final autoStopMinutes = settings.autoStopMinutes;
    Duration? autoStopRemaining;
    var autoStopTriggered = false;

    if (autoStopMinutes > 0 && activatedAt != null) {
      final limit = Duration(minutes: autoStopMinutes);
      final elapsed = now.difference(activatedAt);
      if (elapsed >= limit) {
        autoStopTriggered = true;
        autoStopRemaining = Duration.zero;
        reasons.add('Auto-stop');
      } else if (elapsed.isNegative) {
        autoStopRemaining = limit;
      } else {
        autoStopRemaining = limit - elapsed;
      }
    }

    Duration? nextWakeDelay;
    if (autoStopTriggered) {
      nextWakeDelay = Duration.zero;
    } else if (shouldPause) {
      final candidates = <Duration>[];
      if (settings.windows.isNotEmpty && !within) {
        final nextStart = _nextWindowStart(now, settings.windows);
        if (nextStart != null && nextStart.isAfter(now)) {
          candidates.add(nextStart.difference(now));
        } else {
          candidates.add(const Duration(seconds: 30));
        }
      } else {
        candidates.add(const Duration(seconds: 2));
      }
      if (autoStopRemaining != null) {
        candidates.add(autoStopRemaining);
      }
      candidates.sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
      final chosen = candidates.isEmpty
          ? const Duration(seconds: 2)
          : candidates.first;
      nextWakeDelay = chosen < const Duration(milliseconds: 250)
          ? const Duration(milliseconds: 250)
          : chosen;
    }

    return SchedulerEnforcement(
      now: now,
      isWithinWindowNow: within,
      shouldPause: shouldPause,
      autoStopTriggered: autoStopTriggered,
      autoStopRemaining: autoStopRemaining,
      nextWakeDelay: nextWakeDelay,
      reasons: List<String>.unmodifiable(reasons),
      hasUnimplementedSignals: hasUnimplementedSignals,
    );
  }
}

final _schedulerClockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>.broadcast();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (!controller.isClosed) controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

final schedulerEnforcementProvider = Provider<SchedulerEnforcement>((ref) {
  final settings = ref.watch(appSettingsControllerProvider).asData?.value;
  final scheduler = settings?.scheduler ?? ScheduleSettings.defaults();
  final activatedAt = ref.watch(jigglerActivatedAtProvider);
  final now =
      ref.watch(_schedulerClockProvider).asData?.value ?? DateTime.now();
  final signals = ref.watch(schedulerDeviceSignalsProvider);

  return SchedulerEnforcement.evaluate(
    now: now,
    settings: scheduler,
    activatedAt: activatedAt,
    signals: signals,
  );
});

bool _isWithinAnyWindow(DateTime now, List<TimeWindow> windows) {
  if (windows.isEmpty) return true;

  final nowDay = now.weekday;
  final prevDay = nowDay == 1 ? 7 : nowDay - 1;
  final minute = now.hour * 60 + now.minute;

  for (final w in windows) {
    if (w.days.isEmpty) continue;

    final start = w.startMinutes.clamp(0, 24 * 60);
    final end = w.endMinutes.clamp(0, 24 * 60);

    if (start < end) {
      if (w.days.contains(nowDay) && minute >= start && minute < end) {
        return true;
      }
    } else if (start > end) {
      if (w.days.contains(nowDay) && minute >= start) return true;
      if (w.days.contains(prevDay) && minute < end) return true;
    } else {
      if (w.days.contains(nowDay) && minute == start) return true;
    }
  }
  return false;
}

DateTime? _nextWindowStart(DateTime now, List<TimeWindow> windows) {
  if (windows.isEmpty) return null;

  final base = DateTime(now.year, now.month, now.day);
  DateTime? best;

  for (var offset = 0; offset <= 7; offset++) {
    final dayBase = base.add(Duration(days: offset));
    final wd = dayBase.weekday;
    for (final w in windows) {
      if (w.days.isEmpty) continue;
      if (!w.days.contains(wd)) continue;
      final start = w.startMinutes.clamp(0, 24 * 60);
      final candidate = dayBase.add(Duration(minutes: start));
      if (!candidate.isAfter(now)) continue;
      if (best == null || candidate.isBefore(best)) best = candidate;
    }
  }
  return best;
}
