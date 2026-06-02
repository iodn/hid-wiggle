import 'package:flutter/foundation.dart';

@immutable
class UsbVendor {
  final int vid;
  final String name;

  const UsbVendor({
    required this.vid,
    required this.name,
  });

  factory UsbVendor.fromMap(Map<String, dynamic> map) {
    return UsbVendor(
      vid: map['vid'] as int,
      name: map['name'] as String,
    );
  }

  String get vidHex => '0x${vid.toRadixString(16).padLeft(4, '0')}';
}

@immutable
class UsbProduct {
  final int vid;
  final int pid;
  final String name;
  final String? vendorName;

  const UsbProduct({
    required this.vid,
    required this.pid,
    required this.name,
    this.vendorName,
  });

  factory UsbProduct.fromMap(Map<String, dynamic> map) {
    return UsbProduct(
      vid: map['vid'] as int,
      pid: map['pid'] as int,
      name: map['name'] as String,
      vendorName: map['vendorName'] as String?,
    );
  }

  String get vidHex => '0x${vid.toRadixString(16).padLeft(4, '0')}';
  String get pidHex => '0x${pid.toRadixString(16).padLeft(4, '0')}';
  String get vidPidLabel => '$vidHex:$pidHex';
  String get fullLabel => vendorName != null ? '$vendorName - $name' : name;
}
