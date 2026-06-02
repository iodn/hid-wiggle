import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/gadget_providers.dart';

@immutable
class DeviceCapabilities {
  final bool rootAvailable;
  final bool hidSupported;
  const DeviceCapabilities({
    required this.rootAvailable,
    required this.hidSupported,
  });
}

final deviceCapabilitiesProvider = Provider<DeviceCapabilities>((ref) {
  final statusAsync = ref.watch(gadgetStatusProvider);
  final status = statusAsync.asData?.value;

  return DeviceCapabilities(
    rootAvailable: status?.rootAvailable ?? false,
    hidSupported: status?.supportAvailable ?? false,
  );
});
