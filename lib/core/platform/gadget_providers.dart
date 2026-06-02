import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gadget_channel.dart';

final gadgetChannelProvider = Provider<GadgetChannel>((ref) {
  return const GadgetChannel();
});

final gadgetStatusStreamProvider = StreamProvider<GadgetStatus>((ref) {
  final ch = ref.watch(gadgetChannelProvider);
  return ch.watchStatus();
});

final gadgetLogsStreamProvider = StreamProvider<String>((ref) {
  final ch = ref.watch(gadgetChannelProvider);
  return ch.watchLogs();
});

final gadgetStatusInitialProvider = FutureProvider<GadgetStatus>((ref) async {
  final ch = ref.watch(gadgetChannelProvider);
  return ch.getStatus();
});

final gadgetStatusProvider = Provider<AsyncValue<GadgetStatus>>((ref) {
  final streamAsync = ref.watch(gadgetStatusStreamProvider);

  return streamAsync.when(
    data: (v) => AsyncData(v),
    loading: () => ref.watch(gadgetStatusInitialProvider),
    error: (err, st) {
      final initial = ref.watch(gadgetStatusInitialProvider);
      return initial.maybeWhen(
        data: (v) => AsyncData(v),
        orElse: () => AsyncError(err, st),
      );
    },
  );
});
