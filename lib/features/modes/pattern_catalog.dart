import 'package:flutter/foundation.dart';
import '../../core/models/jiggle_config.dart';

@immutable
class PatternDefinition {
  final String id;
  final String name;
  final String description;
  final String preview;
  final JiggleConfig defaults;

  const PatternDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.preview,
    required this.defaults,
  });
}

class PatternCatalog {
  static const patterns = <PatternDefinition>[
    PatternDefinition(
      id: 'micro',
      name: 'Micro-wiggle',
      description: 'Tiny, rapid nudges that keep your session active with minimal drift.',
      preview: 'Subtle ±5–10px at ~50–60Hz (low drift)',
      defaults: JiggleConfig(
        patternId: 'micro',
        intervalMs: 80,
        amplitudePx: 10, // was 3
        jitter: 0.08,
        randomness: 0.12,
        humanLike: 0.60,
      ),
    ),
    PatternDefinition(
      id: 'random_drift',
      name: 'Random drift',
      description: 'Fast, natural-looking motion with inertia and occasional direction changes.',
      preview: 'Fast random walk with inertia (~55Hz)',
      defaults: JiggleConfig(
        patternId: 'random_drift',
        intervalMs: 80,
        amplitudePx: 7,
        jitter: 0.10,
        randomness: 0.55,
        humanLike: 0.75,
      ),
    ),
    PatternDefinition(
      id: 'square',
      name: 'Square',
      description: 'Quick box path with softened corners so it looks less mechanical.',
      preview: 'Fast square loop (~55Hz)',
      defaults: JiggleConfig(
        patternId: 'square',
        intervalMs: 80,
        amplitudePx: 8,
        jitter: 0.08,
        randomness: 0.25,
        humanLike: 0.60,
      ),
    ),
    PatternDefinition(
      id: 'figure8',
      name: 'Figure-8',
      description: 'Smooth loop pattern that stays obviously “in motion”.',
      preview: 'Continuous ∞ loop (~60Hz)',
      defaults: JiggleConfig(
        patternId: 'figure8',
        intervalMs: 80,
        amplitudePx: 10,
        jitter: 0.06,
        randomness: 0.25,
        humanLike: 0.85,
      ),
    ),
    PatternDefinition(
      id: 'pulse',
      name: 'Pulse',
      description: 'Short bursts of movement followed by micro-pauses (human-ish cadence).',
      preview: 'Burst + micro-pause cadence (~50–55Hz base)',
      defaults: JiggleConfig(
        patternId: 'pulse',
        intervalMs: 80,
        amplitudePx: 10,
        jitter: 0.18,
        randomness: 0.50,
        humanLike: 0.70,
      ),
    ),
  ];

  static PatternDefinition byId(String id) {
    return patterns.firstWhere(
      (p) => p.id == id,
      orElse: () => patterns.first,
    );
  }

  static JiggleConfig defaultsFor(String id) => byId(id).defaults;
}
