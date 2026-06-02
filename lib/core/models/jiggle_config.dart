class JiggleConfig {
  final String patternId;
  final int intervalMs;
  final int amplitudePx;
  final double jitter;
  final double randomness;
  final double humanLike;

  const JiggleConfig({
    required this.patternId,
    required this.intervalMs,
    required this.amplitudePx,
    required this.jitter,
    required this.randomness,
    required this.humanLike,
  });

  factory JiggleConfig.defaults() => const JiggleConfig(
        patternId: 'micro',
        intervalMs: 80,
        amplitudePx: 10,
        jitter: 0.08,
        randomness: 0.12,
        humanLike: 0.60,
      );

  JiggleConfig copyWith({
    String? patternId,
    int? intervalMs,
    int? amplitudePx,
    double? jitter,
    double? randomness,
    double? humanLike,
  }) {
    return JiggleConfig(
      patternId: patternId ?? this.patternId,
      intervalMs: intervalMs ?? this.intervalMs,
      amplitudePx: amplitudePx ?? this.amplitudePx,
      jitter: jitter ?? this.jitter,
      randomness: randomness ?? this.randomness,
      humanLike: humanLike ?? this.humanLike,
    );
  }

  Map<String, dynamic> toJson() => {
        'patternId': patternId,
        'intervalMs': intervalMs,
        'amplitudePx': amplitudePx,
        'jitter': jitter,
        'randomness': randomness,
        'humanLike': humanLike,
      };

  factory JiggleConfig.fromJson(Map<String, dynamic> json) {
    return JiggleConfig(
      patternId: (json['patternId'] as String?) ?? 'micro',
      intervalMs: (json['intervalMs'] as num?)?.toInt() ?? 80,
      amplitudePx: (json['amplitudePx'] as num?)?.toInt() ?? 10,
      jitter: (json['jitter'] as num?)?.toDouble() ?? 0.08,
      randomness: (json['randomness'] as num?)?.toDouble() ?? 0.12,
      humanLike: (json['humanLike'] as num?)?.toDouble() ?? 0.60,
    );
  }
}
