import 'dart:math';

import '../models/jiggle_config.dart';

class PatternStep {
  final int dx;
  final int dy;
  final double intervalMultiplier;

  const PatternStep({
    required this.dx,
    required this.dy,
    this.intervalMultiplier = 1.0,
  });
}

abstract class MovementPattern {
  PatternStep next(JiggleConfig cfg);
}

class MovementPatternFactory {
  static MovementPattern create(String patternId, Random rng) {
    switch (patternId) {
      case 'micro':
        return _MicroWiggle(rng);
      case 'random_drift':
        return _RandomDrift(rng);
      case 'square':
        return _Square(rng);
      case 'figure8':
        return _Figure8(rng);
      case 'pulse':
        return _Pulse(rng);
      default:
        return _MicroWiggle(rng);
    }
  }
}

int _effectiveAmpPx(Random rng, JiggleConfig cfg, {double scale = 1.0}) {
  final base = max(1.0, cfg.amplitudePx.toDouble()) * scale;
  final rand = cfg.randomness.clamp(0.0, 1.0);
  final human = cfg.humanLike.clamp(0.0, 1.0);
  final ampVar = base * rand * (rng.nextDouble() * 2 - 1);
  final humanVar = base * 0.18 * human * (rng.nextDouble() * 2 - 1);
  return max(1, (base + ampVar + humanVar).round());
}

int _smallNoise(Random rng, JiggleConfig cfg, int amp) {
  final rand = cfg.randomness.clamp(0.0, 1.0);
  final human = cfg.humanLike.clamp(0.0, 1.0);
  final s = rand * human;
  if (s <= 0) return 0;
  final n = ((rng.nextDouble() * 2 - 1) * (amp * 0.35) * s).round();
  return n;
}

bool _isZero(int dx, int dy) => dx == 0 && dy == 0;

class _MicroWiggle implements MovementPattern {
  final Random _rng;
  int _dir = 1;

  _MicroWiggle(this._rng);

  @override
  PatternStep next(JiggleConfig cfg) {
    final int amp = _effectiveAmpPx(_rng, cfg, scale: 0.78);
    final int dxBase = _dir * amp;
    _dir *= -1;

    final int dy = _smallNoise(_rng, cfg, amp)
        .clamp(-max(1, amp ~/ 2), max(1, amp ~/ 2))
        .toInt();

    return PatternStep(dx: dxBase, dy: dy);
  }
}

class _RandomDrift implements MovementPattern {
  final Random _rng;
  double _vx = 0.0;
  double _vy = 0.0;

  _RandomDrift(this._rng);

  @override
  PatternStep next(JiggleConfig cfg) {
    final double amp = _effectiveAmpPx(_rng, cfg, scale: 1.0).toDouble();
    final rand = cfg.randomness.clamp(0.0, 1.0);
    final human = cfg.humanLike.clamp(0.0, 1.0);

    final inertia = 0.55 + 0.35 * human;
    final steer = 0.40 + 0.90 * rand;

    if (_rng.nextDouble() < (0.18 + 0.22 * rand)) {
      final angle = _rng.nextDouble() * pi * 2;
      _vx += cos(angle) * (amp / 2) * steer;
      _vy += sin(angle) * (amp / 2) * steer;
    } else {
      _vx += (_rng.nextDouble() * 2 - 1) * (amp * 0.15) * steer;
      _vy += (_rng.nextDouble() * 2 - 1) * (amp * 0.15) * steer;
    }

    _vx *= inertia;
    _vy *= inertia;

    _vx = _vx.clamp(-amp, amp);
    _vy = _vy.clamp(-amp, amp);

    int dx = _vx.round();
    int dy = _vy.round();

    dx += _smallNoise(_rng, cfg, amp.round());
    dy += _smallNoise(_rng, cfg, amp.round());

    if (_isZero(dx, dy)) dx = 1;
    return PatternStep(dx: dx, dy: dy);
  }
}

class _Square implements MovementPattern {
  final Random _rng;
  int _i = 0;

  _Square(this._rng);

  @override
  PatternStep next(JiggleConfig cfg) {
    final int amp = _effectiveAmpPx(_rng, cfg, scale: 1.05);
    final int n = _smallNoise(_rng, cfg, amp);

    final int step = _i % 4;
    _i++;

    int dx = 0, dy = 0;
    switch (step) {
      case 0:
        dy = -amp;
        break;
      case 1:
        dx = amp;
        break;
      case 2:
        dy = amp;
        break;
      case 3:
        dx = -amp;
        break;
    }

    final human = cfg.humanLike.clamp(0.0, 1.0);
    final soften = (0.45 + 0.55 * human);
    final int m = (n * soften).round();

    if (dx != 0) dy += m;
    if (dy != 0) dx += m;

    if (_isZero(dx, dy)) dx = 1;
    return PatternStep(dx: dx, dy: dy);
  }
}

class _Figure8 implements MovementPattern {
  final Random _rng;
  double _t = 0.0;

  _Figure8(this._rng);

  @override
  PatternStep next(JiggleConfig cfg) {
    final double amp = _effectiveAmpPx(_rng, cfg, scale: 1.15).toDouble();

    final int dx = (sin(_t) * amp).round();
    final int dy = (sin(2 * _t) * amp * 0.78).round();

    final human = cfg.humanLike.clamp(0.0, 1.0);
    final rand = cfg.randomness.clamp(0.0, 1.0);

    final double baseStep = 0.62 + 0.38 * human;
    final double stepVar = 0.24 * rand * (_rng.nextDouble() * 2 - 1);
    _t += max(0.34, baseStep + stepVar);

    final int outDx = (dx == 0 && dy == 0) ? 1 : dx;
    return PatternStep(dx: outDx, dy: dy);
  }
}

class _Pulse implements MovementPattern {
  final Random _rng;
  int _phase = 0;

  _Pulse(this._rng);

  @override
  PatternStep next(JiggleConfig cfg) {
    const int burstLen = 3;
    const int pauseLen = 5;
    const int cycle = burstLen + pauseLen;

    final int idx = _phase % cycle;
    _phase++;

    if (idx < burstLen) {
      final int amp = _effectiveAmpPx(_rng, cfg, scale: 1.35);
      int dx = (_rng.nextInt(amp * 2 + 1) - amp);
      int dy = (_rng.nextInt(amp * 2 + 1) - amp);
      if (_isZero(dx, dy)) dx = 1;
      return PatternStep(dx: dx, dy: dy, intervalMultiplier: 0.90);
    } else {
      final int tiny = max<int>(1, (cfg.amplitudePx / 3).round());
      final int dir = _rng.nextBool() ? 1 : -1;
      final int dx = dir * tiny;
      return PatternStep(dx: dx, dy: 0, intervalMultiplier: 1.85);
    }
  }
}
