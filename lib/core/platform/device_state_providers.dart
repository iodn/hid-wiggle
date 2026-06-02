import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_state_channel.dart';

final deviceStateChannelProvider = Provider<DeviceStateChannel>((ref) {
  return const DeviceStateChannel();
});

final _deviceStatePollingProvider = StreamProvider<DeviceState>((ref) {
  final channel = ref.watch(deviceStateChannelProvider);
  final controller = StreamController<DeviceState>.broadcast();

  Timer? timer;

  void poll() async {
    if (controller.isClosed) return;
    try {
      final state = await channel.getDeviceState();
      if (!controller.isClosed) {
        controller.add(state);
      }
    } catch (_) {}
  }

  poll();
  timer = Timer.periodic(const Duration(seconds: 2), (_) => poll());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

final deviceStateProvider = Provider<DeviceState>((ref) {
  final async = ref.watch(_deviceStatePollingProvider);
  return async.asData?.value ??
      const DeviceState(screenOn: true, charging: false, batteryPercent: 100);
});
