import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/app_settings.dart';
import '../core/models/jiggle_config.dart';
import '../core/models/schedule_settings.dart';
import '../core/models/usb_identity_settings.dart';
import '../core/services/preferences_repository.dart';

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
        AppSettingsController.new);

class AppSettingsController extends AsyncNotifier<AppSettings> {
  late PreferencesRepository _repo;

  static const int _minStableIntervalMs = 80;
  static const int _maxAmplitudePx = 1920;

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    _repo = PreferencesRepository(prefs);

    final loaded = await _repo.loadSettings();
    final initial = loaded ?? AppSettings.defaults();
    final normalized = _normalize(initial);

    // CRITICAL FIX:
    // On first install (loaded == null), persist defaults immediately so any
    // platform-side code relying on stored settings sees a valid config.
    final shouldPersist = loaded == null || _isDifferent(initial, normalized);
    if (shouldPersist) {
      await _repo.saveSettings(normalized);
    }

    return normalized;
  }

  static double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

  AppSettings _normalize(AppSettings s) {
    final j = s.jiggle;
    final nextJ = JiggleConfig(
      patternId: j.patternId.trim().isEmpty
          ? JiggleConfig.defaults().patternId
          : j.patternId,
      intervalMs: j.intervalMs.clamp(_minStableIntervalMs, 60000),
      amplitudePx: j.amplitudePx.clamp(1, _maxAmplitudePx),
      jitter: _clamp01(j.jitter),
      randomness: _clamp01(j.randomness),
      humanLike: _clamp01(j.humanLike),
    );
    return s.copyWith(jiggle: nextJ);
  }

  bool _isDifferent(AppSettings a, AppSettings b) {
    final aj = a.jiggle;
    final bj = b.jiggle;

    return aj.patternId != bj.patternId ||
        aj.intervalMs != bj.intervalMs ||
        aj.amplitudePx != bj.amplitudePx ||
        aj.jitter != bj.jitter ||
        aj.randomness != bj.randomness ||
        aj.humanLike != bj.humanLike ||
        a.themeMode != b.themeMode ||
        a.scheduler.autoStopMinutes != b.scheduler.autoStopMinutes ||
        a.scheduler.pauseWhenBatteryLow != b.scheduler.pauseWhenBatteryLow ||
        a.scheduler.pauseWhenCharging != b.scheduler.pauseWhenCharging ||
        a.scheduler.pauseWhenScreenOff != b.scheduler.pauseWhenScreenOff ||
        a.scheduler.windows.length != b.scheduler.windows.length ||
        a.usbIdentity.vidPidLabel != b.usbIdentity.vidPidLabel;
  }

  Future<void> _set(AppSettings next) async {
    state = AsyncData(next);
    await _repo.saveSettings(next);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final cur = state.value ?? AppSettings.defaults();
    await _set(cur.copyWith(themeMode: mode));
  }

  Future<void> updateJiggle(JiggleConfig next) async {
    final cur = state.value ?? AppSettings.defaults();
    // Normalize ensures amplitude and interval bounds are enforced.
    await _set(cur.copyWith(jiggle: _normalize(cur.copyWith(jiggle: next)).jiggle));
  }

  Future<void> updateScheduler(ScheduleSettings next) async {
    final cur = state.value ?? AppSettings.defaults();
    await _set(cur.copyWith(scheduler: next));
  }

  Future<void> updateUsbIdentity(UsbIdentitySettings next) async {
    final cur = state.value ?? AppSettings.defaults();
    await _set(cur.copyWith(usbIdentity: next));
  }

  Future<void> resetToDefaults() async {
    await _set(_normalize(AppSettings.defaults()));
  }
}
