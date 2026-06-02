import 'dart:async';
import 'package:flutter/services.dart';

class DeviceState {
  final bool screenOn;
  final bool charging;
  final int batteryPercent;

  const DeviceState({
    required this.screenOn,
    required this.charging,
    required this.batteryPercent,
  });

  factory DeviceState.fromMap(Map<String, dynamic> map) {
    return DeviceState(
      screenOn: map['screenOn'] == true,
      charging: map['charging'] == true,
      batteryPercent: (map['batteryPercent'] as num?)?.toInt() ?? 100,
    );
  }

  bool get batteryLow => batteryPercent < 20;
}

class DeviceStateChannel {
  static const MethodChannel _methods =
      MethodChannel('org.kaijinlab.hid_wiggle/device_state');

  const DeviceStateChannel();

  Future<DeviceState> getDeviceState() async {
    try {
      final result = await _methods.invokeMethod<Map<dynamic, dynamic>>('getDeviceState');
      final map = result == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(result);
      return DeviceState.fromMap(map);
    } catch (e) {
      return const DeviceState(screenOn: true, charging: false, batteryPercent: 100);
    }
  }
}
