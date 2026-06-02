import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/jiggle_config.dart';
import '../../core/services/movement_patterns.dart';

class MovementPreview extends StatefulWidget {
  final JiggleConfig config;
  final double height;

  const MovementPreview({
    super.key,
    required this.config,
    this.height = 180,
  });

  @override
  State<MovementPreview> createState() => _MovementPreviewState();
}

class _MovementPreviewState extends State<MovementPreview>
    with SingleTickerProviderStateMixin {
  final Random _rng = Random(1337);

  late MovementPattern _pattern;
  late JiggleConfig _cfg;

  final List<Offset> _points = <Offset>[];
  Offset _pos = Offset.zero;

  late final AnimationController _ticker;
  Duration _lastElapsed = Duration.zero;
  double _accumMs = 0;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config;
    _pattern = MovementPatternFactory.create(_cfg.patternId, _rng);
    _reset();

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 365),
    )..addListener(_onFrame);

    _ticker.repeat();
  }

  @override
  void didUpdateWidget(covariant MovementPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed = oldWidget.config.patternId != widget.config.patternId ||
        oldWidget.config.intervalMs != widget.config.intervalMs ||
        oldWidget.config.amplitudePx != widget.config.amplitudePx ||
        oldWidget.config.jitter != widget.config.jitter ||
        oldWidget.config.randomness != widget.config.randomness ||
        oldWidget.config.humanLike != widget.config.humanLike;

    if (changed) {
      _cfg = widget.config;
      _pattern = MovementPatternFactory.create(_cfg.patternId, _rng);
      _reset();
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onFrame);
    _ticker.dispose();
    super.dispose();
  }

  void _reset() {
    _points.clear();
    _pos = Offset.zero;
    _points.add(_pos);
    _accumMs = 0;
    _lastElapsed = Duration.zero;
  }

  void _onFrame() {
    final elapsed = _ticker.lastElapsedDuration ?? Duration.zero;
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;

    if (dt.isNaN || dt.isInfinite) return;
    dt = dt.clamp(0, 50).toDouble();

    final stepHz = _previewStepHz(_cfg.patternId);
    final stepEveryMs = 1000.0 / stepHz;

    _accumMs += dt;

    var produced = 0;
    while (_accumMs >= stepEveryMs && produced < 16) {
      _accumMs -= stepEveryMs;

      final step = _pattern.next(_cfg);
      _pos = _pos.translate(step.dx.toDouble(), step.dy.toDouble());
      _points.add(_pos);

      final maxPoints = 220;
      if (_points.length > maxPoints) {
        _points.removeRange(0, _points.length - maxPoints);
      }

      produced++;
    }

    if (produced > 0 && mounted) {
      setState(() {});
    }
  }

  double _previewStepHz(String id) {
    switch (id) {
      case 'micro':
        return 70;
      case 'random_drift':
        return 75;
      case 'square':
        return 62;
      case 'figure8':
        return 95;
      case 'pulse':
        return 80;
      default:
        return 70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MovementPainter(points: _points, scheme: scheme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MovementPainter extends CustomPainter {
  final List<Offset> points;
  final ColorScheme scheme;

  _MovementPainter({
    required this.points,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..color = scheme.onSurfaceVariant.withOpacity(0.22);

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );

    if (points.length < 2) return;

    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);

    final minX = xs.reduce(min);
    final maxX = xs.reduce(max);
    final minY = ys.reduce(min);
    final maxY = ys.reduce(max);

    final midX = (minX + maxX) / 2.0;
    final midY = (minY + maxY) / 2.0;

    final spanX = max(1.0, (maxX - minX).abs());
    final spanY = max(1.0, (maxY - minY).abs());
    final span = max(spanX, spanY);

    final pad = 14.0;
    final usableW = max(1.0, size.width - pad * 2);
    final usableH = max(1.0, size.height - pad * 2);
    final scale = min(usableW, usableH) / span;

    final scaled = <Offset>[
      for (final p in points)
        center + Offset((p.dx - midX) * scale, (p.dy - midY) * scale),
    ];

    final clipRect = Rect.fromLTWH(pad, pad, usableW, usableH);
    canvas.save();
    canvas.clipRect(clipRect);

    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = scheme.primary.withOpacity(0.28);

    for (var i = 1; i < scaled.length; i++) {
      final t = i / (scaled.length - 1);
      final a = (0.10 + 0.55 * t).clamp(0.0, 0.65);
      trailPaint.color = scheme.primary.withOpacity(a);
      canvas.drawLine(scaled[i - 1], scaled[i], trailPaint);
    }

    final head = scaled.last;

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = scheme.primary.withOpacity(0.20);

    final dot = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = scheme.primary.withOpacity(0.95);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true
      ..color = scheme.onSurface.withOpacity(0.35);

    canvas.drawCircle(head, 12.0, glow);
    canvas.drawCircle(head, 5.8, dot);
    canvas.drawCircle(head, 5.8, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MovementPainter oldDelegate) {
    return true;
  }
}
