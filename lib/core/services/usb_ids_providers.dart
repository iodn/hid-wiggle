import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usb_ids_repository.dart';

final usbIdsRepositoryProvider = Provider<UsbIdsRepository>((ref) {
  final repo = UsbIdsRepository();
  ref.onDispose(() => repo.close());
  return repo;
});
