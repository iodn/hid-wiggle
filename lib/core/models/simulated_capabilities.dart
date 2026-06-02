class SimulatedCapabilities {
  final bool rootAvailable;
  final bool hidSupported;

  const SimulatedCapabilities({
    required this.rootAvailable,
    required this.hidSupported,
  });

  factory SimulatedCapabilities.defaults() => const SimulatedCapabilities(
        rootAvailable: false,
        hidSupported: false,
      );

  SimulatedCapabilities copyWith({
    bool? rootAvailable,
    bool? hidSupported,
  }) {
    return SimulatedCapabilities(
      rootAvailable: rootAvailable ?? this.rootAvailable,
      hidSupported: hidSupported ?? this.hidSupported,
    );
  }

  Map<String, dynamic> toJson() => {
        'rootAvailable': rootAvailable,
        'hidSupported': hidSupported,
      };

  factory SimulatedCapabilities.fromJson(Map<String, dynamic> json) {
    return SimulatedCapabilities(
      rootAvailable: json['rootAvailable'] is bool ? json['rootAvailable'] as bool : false,
      hidSupported: json['hidSupported'] is bool ? json['hidSupported'] as bool : false,
    );
  }
}
