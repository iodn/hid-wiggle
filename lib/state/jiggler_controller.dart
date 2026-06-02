import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/jiggle_config.dart';
import '../core/platform/gadget_channel.dart';
import '../core/platform/gadget_providers.dart';
import '../core/services/movement_patterns.dart';
import 'app_settings_controller.dart';
import 'scheduler_enforcement_provider.dart';

final jigglerControllerProvider = Provider<JigglerController>((ref) {
  final ctrl = JigglerController._(ref);
  ref.onDispose(ctrl.dispose);
  ctrl._bind();
  return ctrl;
});

class JigglerController {
  static const int _minTickMs = 80;
  static const int _hidMin = -127;
  static const int _hidMax = 127;
  static const int _warmupDelayMs = 350;
  static const int _maxBackoffMs = 5000;
  static const int _maxConsecutiveFailures = 25;

  final Ref _ref;
  final Random _rng = Random();

  Timer? _timer;
  bool _disposed = false;

  GadgetStatus _status = GadgetStatus.defaults();
  JiggleConfig _cfg = JiggleConfig.defaults();

  late MovementPattern _pattern;
  String _patternId = 'micro';

  int _consecutiveFailures = 0;
  DateTime? _lastActivatedAt;

  ProviderSubscription<SchedulerEnforcement>? _enforcementSub;

  JigglerController._(this._ref) {
    _pattern = MovementPatternFactory.create(_patternId, _rng);
  }

  void _bind() {
    _ref.listen<AsyncValue<GadgetStatus>>(
      gadgetStatusProvider,
      (prev, next) {
        final s = next.asData?.value;
        if (s == null) return;

        final prevState = _status.state;
        _status = s;

        if (_status.state == 'ACTIVE') {
          if (prevState != 'ACTIVE') {
            _consecutiveFailures = 0;
            _lastActivatedAt = DateTime.now();
            _ref.read(jigglerActivatedAtProvider.notifier).state = _lastActivatedAt;

            _enforcementSub ??= _ref.listen<SchedulerEnforcement>(
              schedulerEnforcementProvider,
              (p, n) {},
              fireImmediately: true,
            );

            _ensureRunning(reschedule: true, warmup: true);
            return;
          }

          _ensureRunning();
        } else {
          _consecutiveFailures = 0;
          _lastActivatedAt = null;
          _ref.read(jigglerActivatedAtProvider.notifier).state = null;

          _enforcementSub?.close();
          _enforcementSub = null;

          _stopTimer();
        }
      },
      fireImmediately: true,
    );

    _ref.listen(
      appSettingsControllerProvider,
      (prev, next) {
        final settings = next.asData?.value;
        if (settings == null) return;

        _cfg = settings.jiggle;

        if (_cfg.patternId != _patternId) {
          _patternId = _cfg.patternId;
          _pattern = MovementPatternFactory.create(_patternId, _rng);
        }

        if (_status.state == 'ACTIVE') {
          _ensureRunning(reschedule: true);
        }
      },
      fireImmediately: true,
    );
  }

  void _ensureRunning({bool reschedule = false, bool warmup = false}) {
    if (_disposed) return;
    if (_timer != null && !reschedule) return;

    _stopTimer();

    if (warmup) {
      _scheduleNextTick(overrideDelayMs: _warmupDelayMs);
    } else {
      _scheduleNextTick();
    }
  }

  void _scheduleNextTick({int? overrideDelayMs, PatternStep? lastStep}) {
    if (_disposed) return;
    if (_status.state != 'ACTIVE') return;

    final int delayMs = overrideDelayMs ?? _computeNextDelayMs(lastStep);
    _timer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_tick());
    });
  }

  int _computeNextDelayMs(PatternStep? lastStep) {
    final baseMs = _cfg.intervalMs.clamp(_minTickMs, 60000);
    final mult = (lastStep?.intervalMultiplier.isFinite == true && lastStep!.intervalMultiplier > 0)
        ? lastStep.intervalMultiplier
        : 1.0;

    final jitter = _cfg.jitter.clamp(0.0, 1.0);
    final jr = jitter.clamp(0.0, 0.85);
    final jitterFactor = 1.0 + ((-jr) + _rng.nextDouble() * (2 * jr));

    var nextMs = max(_minTickMs, (baseMs * mult * jitterFactor).round());

    final activatedAt = _lastActivatedAt;
    if (activatedAt != null) {
      final since = DateTime.now().difference(activatedAt).inMilliseconds;
      if (since >= 0 && since < _warmupDelayMs) {
        nextMs = max(nextMs, 120);
      }
    }

    return nextMs;
  }

  int _backoffDelayMs(int failures) {
    final base = 250.0 * pow(1.6, max(0, failures - 1));
    final jitter = 0.85 + _rng.nextDouble() * 0.30;
    return min(_maxBackoffMs, max(250, (base * jitter).round()));
  }

  Future<void> _tick() async {
    if (_disposed) return;

    if (_status.state != 'ACTIVE') {
      _stopTimer();
      return;
    }

    final enforcement = _ref.read(schedulerEnforcementProvider);
    final ch = _ref.read(gadgetChannelProvider);

    if (enforcement.autoStopTriggered) {
      try {
        await ch.deactivate();
      } catch (_) {}
      _stopTimer();
      return;
    }

    if (enforcement.shouldPause) {
      final d = enforcement.nextWakeDelay ?? const Duration(seconds: 2);
      final ms = d.inMilliseconds.clamp(_minTickMs, 60000);
      _scheduleNextTick(overrideDelayMs: ms);
      return;
    }

    final step = _pattern.next(_cfg);

    try {
      await _sendMouseMoveChunked(ch, dx: step.dx, dy: step.dy);
      _consecutiveFailures = 0;
      _scheduleNextTick(lastStep: step);
    } catch (_) {
      _consecutiveFailures++;
      final delay = _backoffDelayMs(_consecutiveFailures);
      final effectiveDelay = (_consecutiveFailures >= _maxConsecutiveFailures) ? max(delay, 2500) : delay;
      _scheduleNextTick(overrideDelayMs: effectiveDelay);
    }
  }

  Future<void> _sendMouseMoveChunked(
    GadgetChannel ch, {
    required int dx,
    required int dy,
  }) async {
    var rx = dx;
    var ry = dy;

    if (rx == 0 && ry == 0) {
      await ch.testMouseMove(dx: 1, dy: 0, wheel: 0, buttons: 0);
      return;
    }

    while (rx != 0 || ry != 0) {
      final cx = rx.clamp(_hidMin, _hidMax);
      final cy = ry.clamp(_hidMin, _hidMax);

      await ch.testMouseMove(dx: cx, dy: cy, wheel: 0, buttons: 0);

      rx -= cx;
      ry -= cy;

      if (rx.abs() > 100000 || ry.abs() > 100000) break;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _enforcementSub?.close();
    _enforcementSub = null;
    _stopTimer();
  }
}
