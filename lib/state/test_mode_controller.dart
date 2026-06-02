import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class TestLogEntry {
  final DateTime timestamp;
  final String message;

  const TestLogEntry({required this.timestamp, required this.message});
}

final testModeControllerProvider =
    NotifierProvider<TestModeController, List<TestLogEntry>>(TestModeController.new);

class TestModeController extends Notifier<List<TestLogEntry>> {
  @override
  List<TestLogEntry> build() => const [];

  void log(String message) {
    state = [
      TestLogEntry(timestamp: DateTime.now(), message: message),
      ...state,
    ].take(200).toList(growable: false);
  }

  void clear() {
    state = const [];
  }
}
