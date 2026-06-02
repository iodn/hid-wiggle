import 'package:flutter/foundation.dart';

@immutable
class HidGadgetTunables {
  final Object vendorId;
  final Object productId;

  final String manufacturer;
  final String product;
  final String serialNumber;

  final int maxPowerMa;

  const HidGadgetTunables({
    required this.vendorId,
    required this.productId,
    required this.manufacturer,
    required this.product,
    required this.serialNumber,
    required this.maxPowerMa,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'vendorId': vendorId,
        'productId': productId,
        'manufacturer': manufacturer,
        'product': product,
        'serialNumber': serialNumber,
        'maxPowerMa': maxPowerMa,
      };
}

@immutable
class HidGadgetProfile {
  static const String stableMouseId = 'hidwiggle_mouse';

  final String id;
  final String name;
  final String roleType;

  final HidGadgetTunables tunables;

  const HidGadgetProfile({
    required this.id,
    required this.name,
    required this.roleType,
    required this.tunables,
  });

  factory HidGadgetProfile.mouseBaseline({
    String id = HidGadgetProfile.stableMouseId,
    String name = 'HIDWiggle Mouse',
    required Object vendorId,
    required Object productId,
    required String manufacturer,
    required String product,
    required String serialNumber,
    required int maxPowerMa,
  }) {
    final sn = serialNumber.trim().isEmpty ? 'HIDWiggle:${id}' : serialNumber.trim();
    return HidGadgetProfile(
      id: id,
      name: name,
      roleType: 'mouse',
      tunables: HidGadgetTunables(
        vendorId: vendorId,
        productId: productId,
        manufacturer: manufacturer.trim().isEmpty ? 'KaijinLab' : manufacturer.trim(),
        product: product.trim().isEmpty ? 'HIDWiggle' : product.trim(),
        serialNumber: sn,
        maxPowerMa: maxPowerMa,
      ),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'roleType': roleType,
        'tunables': tunables.toMap(),
      };
}
