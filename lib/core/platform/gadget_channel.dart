import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef GadgetDiagnostics = Map<String, dynamic>;

@immutable
class GadgetStatus {
  final bool rootAvailable;
  final bool supportAvailable;
  final List<String> udcList;
  final String state; // "IDLE" | "ACTIVATING" | "ACTIVE" | "ERROR" (Kotlin string)
  final String? activeProfileId;
  final String? message;

  const GadgetStatus({
    required this.rootAvailable,
    required this.supportAvailable,
    required this.udcList,
    required this.state,
    required this.activeProfileId,
    required this.message,
  });

  factory GadgetStatus.defaults() => const GadgetStatus(
        rootAvailable: false,
        supportAvailable: false,
        udcList: <String>[],
        state: 'IDLE',
        activeProfileId: null,
        message: null,
      );

  factory GadgetStatus.fromMap(Map<String, dynamic> map) {
    bool asBool(dynamic v, {required bool fallback}) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
      }
      return fallback;
    }

    String asString(dynamic v, {required String fallback}) {
      final s = v?.toString();
      if (s == null) return fallback;
      final t = s.trim();
      return t.isEmpty ? fallback : t;
    }

    String? asNullableString(dynamic v) {
      final s = v?.toString();
      if (s == null) return null;
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    List<String> asStringList(dynamic v) {
      if (v is List) {
        return List<String>.unmodifiable(
          v.map((e) => e?.toString() ?? '').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      }
      return const <String>[];
    }

    return GadgetStatus(
      rootAvailable: asBool(map['rootAvailable'], fallback: false),
      supportAvailable: asBool(map['supportAvailable'], fallback: false),
      udcList: asStringList(map['udcList']),
      state: asString(map['state'], fallback: 'IDLE'),
      activeProfileId: asNullableString(map['activeProfileId']),
      message: asNullableString(map['message']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'rootAvailable': rootAvailable,
        'supportAvailable': supportAvailable,
        'udcList': udcList,
        'state': state,
        'activeProfileId': activeProfileId,
        'message': message,
      };

  @override
  String toString() => 'GadgetStatus(${toMap()})';
}

@immutable
class GadgetFailure implements Exception {
  final String code;
  final String message;
  final Object? details;
  final StackTrace? stackTrace;

  const GadgetFailure({
    required this.code,
    required this.message,
    this.details,
    this.stackTrace,
  });

  factory GadgetFailure.fromPlatformException(PlatformException e, StackTrace st) {
    return GadgetFailure(
      code: e.code,
      message: e.message?.trim().isNotEmpty == true ? e.message!.trim() : 'Platform error',
      details: e.details,
      stackTrace: st,
    );
  }

  factory GadgetFailure.fromMissingPlugin(MissingPluginException e, StackTrace st) {
    return GadgetFailure(
      code: 'MISSING_PLUGIN',
      message: e.message?.trim().isNotEmpty == true ? e.message!.trim() : 'Missing platform plugin',
      details: null,
      stackTrace: st,
    );
  }

  factory GadgetFailure.unknown(Object e, StackTrace st) {
    return GadgetFailure(
      code: 'UNKNOWN',
      message: e.toString(),
      details: null,
      stackTrace: st,
    );
  }

  @override
  String toString() => 'GadgetFailure(code=$code, message=$message, details=$details)';
}

class GadgetChannel {
  static const MethodChannel _methods = MethodChannel('org.kaijinlab.hid_wiggle/gadget');
  static const EventChannel _status = EventChannel('org.kaijinlab.hid_wiggle/gadget_status');
  static const EventChannel _logs = EventChannel('org.kaijinlab.hid_wiggle/gadget_logs');

  const GadgetChannel();

  Future<bool> checkRoot() async {
    final v = await _invoke<dynamic>('checkRoot');
    return v == true;
  }

  Future<bool> checkSupport() async {
    final v = await _invoke<dynamic>('checkSupport');
    return v == true;
  }

  Future<List<String>> listUdcs() async {
    final v = await _invoke<dynamic>('listUdcs');
    if (v is List) {
      return List<String>.unmodifiable(
        v.map((e) => e?.toString() ?? '').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    return const <String>[];
  }

  Future<GadgetStatus> getStatus() async {
    final v = await _invoke<dynamic>('getStatus');
    final map = _asMap(v);
    return GadgetStatus.fromMap(map);
  }

  Future<GadgetDiagnostics> getDiagnostics() async {
    final v = await _invoke<dynamic>('getDiagnostics');
    return _asMap(v);
  }

  Future<void> activateProfile(Map<String, dynamic> profile) async {
    await _invoke<void>('activateProfile', profile);
  }

  Future<void> deactivate() async {
    await _invoke<void>('deactivate');
  }

  Future<void> panicStop() async {
    await _invoke<void>('panicStop');
  }

  Future<void> testMouseMove({
    int dx = 0,
    int dy = 0,
    int wheel = 0,
    int buttons = 0,
  }) async {
    await _invoke<void>('testMouseMove', <String, dynamic>{
      'dx': dx,
      'dy': dy,
      'wheel': wheel,
      'buttons': buttons,
    });
  }

  Future<void> testKeyboardKey(String label) async {
    await _invoke<void>('testKeyboardKey', <String, dynamic>{
      'label': label,
    });
  }

  Future<void> testCtrlAltDel() async {
    await _invoke<void>('testCtrlAltDel');
  }

  Stream<GadgetStatus> watchStatus() {
    return _status.receiveBroadcastStream().map((event) {
      final map = _asMap(event);
      return GadgetStatus.fromMap(map);
    });
  }

  Stream<String> watchLogs() {
    return _logs.receiveBroadcastStream().map((event) {
      final s = event?.toString();
      return (s ?? '').trimRight();
    });
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<T> _invoke<T>(String method, [Object? arguments]) async {
    try {
      final result = await _methods.invokeMethod<T>(method, arguments);
      return result as T;
    } on PlatformException catch (e, st) {
      throw GadgetFailure.fromPlatformException(e, st);
    } on MissingPluginException catch (e, st) {
      throw GadgetFailure.fromMissingPlugin(e, st);
    } catch (e, st) {
      throw GadgetFailure.unknown(e, st);
    }
  }
}
