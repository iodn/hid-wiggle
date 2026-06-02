import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_tokens.dart';
import '../../core/models/jiggle_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../state/app_settings_controller.dart';
import 'movement_preview.dart';
import 'pattern_catalog.dart';

class PatternDetailPage extends ConsumerStatefulWidget {
  final String patternId;
  const PatternDetailPage({super.key, required this.patternId});

  @override
  ConsumerState<PatternDetailPage> createState() => _PatternDetailPageState();
}

class _PatternDetailPageState extends ConsumerState<PatternDetailPage> {
  static const int _maxAmplitudePx = 1920;

  late int _intervalMs;
  late int _amplitudePx;
  late double _jitter;
  late double _randomness;
  late double _humanLike;

  bool _initialized = false;
  bool _autoAppliedDefaults = false;

  void _loadFrom(JiggleConfig cfg) {
    _intervalMs = cfg.intervalMs;
    _amplitudePx = cfg.amplitudePx;
    _jitter = cfg.jitter.clamp(0.0, 1.0);
    _randomness = cfg.randomness.clamp(0.0, 1.0);
    _humanLike = cfg.humanLike.clamp(0.0, 1.0);
    _initialized = true;
  }

  Future<void> _persist() async {
    final current = ref.read(appSettingsControllerProvider).asData?.value;
    final base = current?.jiggle ?? PatternCatalog.defaultsFor(widget.patternId);

    final next = base.copyWith(
      patternId: widget.patternId,
      intervalMs: _intervalMs,
      amplitudePx: _amplitudePx,
      jitter: _jitter,
      randomness: _randomness,
      humanLike: _humanLike,
    );

    await ref.read(appSettingsControllerProvider.notifier).updateJiggle(next);
  }

  Future<void> _applyDefaultsNow() async {
    final defaults = PatternCatalog.defaultsFor(widget.patternId);
    _loadFrom(defaults);
    await ref.read(appSettingsControllerProvider.notifier).updateJiggle(defaults);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final currentCfg = settings?.jiggle;
    final pattern = PatternCatalog.byId(widget.patternId);

    if (!_autoAppliedDefaults) {
      final needsApply = currentCfg == null || currentCfg.patternId != widget.patternId;
      if (needsApply) {
        _autoAppliedDefaults = true;
        scheduleMicrotask(() async {
          await _applyDefaultsNow();
        });
      } else {
        _autoAppliedDefaults = true;
      }
    }

    final cfgForUi =
        (ref.watch(appSettingsControllerProvider).asData?.value?.jiggle ??
                PatternCatalog.defaultsFor(widget.patternId))
            .copyWith(patternId: widget.patternId);

    if (!_initialized) {
      if (cfgForUi.patternId == widget.patternId) {
        _loadFrom(cfgForUi);
      } else {
        _loadFrom(PatternCatalog.defaultsFor(widget.patternId));
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(pattern.name),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            onPressed: () async {
              await _applyDefaultsNow();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: 'Done',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pattern.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  'This mode applies immediately. The preview below matches the live jiggle behavior.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
                    child: MovementPreview(config: cfgForUi, height: 200),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Text(
                  'Preset: ${pattern.preview}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          const SectionHeader(
            title: 'Tuning',
            subtitle:
                'Adjustments are applied immediately (no save button needed). Use Reset to return to the mode preset.',
          ),
          const SizedBox(height: AppTokens.spaceSm),

          // Interval
          _slider(
            context: context,
            title: 'Interval',
            subtitle: 'How often a movement is emitted.',
            valueText: Formatters.intervalFromMs(_intervalMs),
            min: 80,
            max: 30000,
            divisions: null,
            value: _intervalMs.toDouble(),
            onChanged: (v) async {
              setState(() => _intervalMs = v.round());
              await _persist();
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // Amplitude (UPDATED MAX)
          _slider(
            context: context,
            title: 'Amplitude',
            subtitle: 'Magnitude of motion (pixels).',
            valueText: Formatters.px(_amplitudePx),
            min: 1,
            max: _maxAmplitudePx.toDouble(),
            divisions: _maxAmplitudePx - 1, // 1..1920
            value: _amplitudePx.toDouble(),
            onChanged: (v) async {
              setState(() => _amplitudePx = v.round());
              await _persist();
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          _slider(
            context: context,
            title: 'Jitter',
            subtitle: 'Adds timing variance around the interval.',
            valueText: Formatters.percent(_jitter),
            min: 0,
            max: 1,
            divisions: 20,
            value: _jitter,
            onChanged: (v) async {
              setState(() => _jitter = v);
              await _persist();
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          _slider(
            context: context,
            title: 'Randomness',
            subtitle: 'Adds directional and amplitude variance.',
            valueText: Formatters.percent(_randomness),
            min: 0,
            max: 1,
            divisions: 20,
            value: _randomness,
            onChanged: (v) async {
              setState(() => _randomness = v);
              await _persist();
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          _slider(
            context: context,
            title: 'Human-like',
            subtitle: 'Biases patterns toward less mechanical motion.',
            valueText: Formatters.percent(_humanLike),
            min: 0,
            max: 1,
            divisions: 20,
            value: _humanLike,
            onChanged: (v) async {
              setState(() => _humanLike = v);
              await _persist();
            },
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  static Widget _slider({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String valueText,
    required double min,
    required double max,
    int? divisions,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Text(valueText, style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
