import 'package:flutter/foundation.dart';

@immutable
class UsbIdentitySettings {
  final String vendorId;
  final String productId;
  final String manufacturer;
  final String product;
  final String serialNumber;
  final int maxPowerMa;

  const UsbIdentitySettings({
    required this.vendorId,
    required this.productId,
    required this.manufacturer,
    required this.product,
    required this.serialNumber,
    required this.maxPowerMa,
  });

  factory UsbIdentitySettings.defaults() => const UsbIdentitySettings(
        vendorId: '0x1d6b',
        productId: '0x0104',
        manufacturer: 'KaijinLab',
        product: 'HIDWiggle',
        serialNumber: '12345',
        maxPowerMa: 250,
      );

  UsbIdentitySettings copyWith({
    String? vendorId,
    String? productId,
    String? manufacturer,
    String? product,
    String? serialNumber,
    int? maxPowerMa,
  }) {
    return UsbIdentitySettings(
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      manufacturer: manufacturer ?? this.manufacturer,
      product: product ?? this.product,
      serialNumber: serialNumber ?? this.serialNumber,
      maxPowerMa: maxPowerMa ?? this.maxPowerMa,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'vendorId': vendorId,
        'productId': productId,
        'manufacturer': manufacturer,
        'product': product,
        'serialNumber': serialNumber,
        'maxPowerMa': maxPowerMa,
      };

  factory UsbIdentitySettings.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v, String fallback) {
      final s = v?.toString();
      if (s == null) return fallback;
      final t = s.trim();
      return t.isEmpty ? fallback : t;
    }

    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) return fallback;
      final parsed = tryParseHexOrDec(s);
      return parsed ?? fallback;
    }

    return UsbIdentitySettings(
      vendorId: asString(
          json['vendorId'], UsbIdentitySettings.defaults().vendorId),
      productId: asString(
          json['productId'], UsbIdentitySettings.defaults().productId),
      manufacturer: asString(
          json['manufacturer'], UsbIdentitySettings.defaults().manufacturer),
      product:
          asString(json['product'], UsbIdentitySettings.defaults().product),
      serialNumber: asString(json['serialNumber'],
          UsbIdentitySettings.defaults().serialNumber),
      maxPowerMa:
          asInt(json['maxPowerMa'], UsbIdentitySettings.defaults().maxPowerMa),
    );
  }

  String get vidPidLabel {
    final vid = tryParseHexOrDec(vendorId);
    final pid = tryParseHexOrDec(productId);
    if (vid == null || pid == null) {
      return '${vendorId.trim()}:${productId.trim()}';
    }
    return '${toHex4(vid)}:${toHex4(pid)}';
  }

  static String toHex4(int v) {
    final x = v & 0xFFFF;
    return '0x${x.toRadixString(16).padLeft(4, '0')}';
  }

  static int? tryParseHexOrDec(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('0x') || s.startsWith('0X')) {
      final body = s.substring(2);
      return int.tryParse(body, radix: 16);
    }
    final hasHexAlpha = RegExp(r'[a-fA-F]').hasMatch(s);
    if (hasHexAlpha) return int.tryParse(s, radix: 16);
    return int.tryParse(s, radix: 10);
  }
}

extension UsbIdentitySettingsExtension on UsbIdentitySettings {
  int? tryParseHexOrDec(String raw) =>
      UsbIdentitySettings.tryParseHexOrDec(raw);
}
