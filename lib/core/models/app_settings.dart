import 'package:flutter/material.dart'; 
import 'jiggle_config.dart'; 
import 'schedule_settings.dart'; 
import 'simulated_capabilities.dart'; 
import 'usb_identity_settings.dart'; 

class AppSettings { 
  final ThemeMode themeMode; 
  final JiggleConfig jiggle; 
  final ScheduleSettings scheduler; 
  final SimulatedCapabilities simulated; 
  final UsbIdentitySettings usbIdentity; 
  
  const AppSettings({ 
    required this.themeMode, 
    required this.jiggle, 
    required this.scheduler, 
    required this.simulated, 
    required this.usbIdentity, 
  }); 

  factory AppSettings.defaults() => AppSettings( 
    themeMode: ThemeMode.system, 
    jiggle: JiggleConfig.defaults(), 
    scheduler: ScheduleSettings.defaults(), 
    simulated: SimulatedCapabilities.defaults(), 
    usbIdentity: UsbIdentitySettings.defaults(), 
  ); 

  AppSettings copyWith({ 
    ThemeMode? themeMode, 
    JiggleConfig? jiggle, 
    ScheduleSettings? scheduler, 
    SimulatedCapabilities? simulated, 
    UsbIdentitySettings? usbIdentity, 
  }) { 
    return AppSettings( 
      themeMode: themeMode ?? this.themeMode, 
      jiggle: jiggle ?? this.jiggle, 
      scheduler: scheduler ?? this.scheduler, 
      simulated: simulated ?? this.simulated, 
      usbIdentity: usbIdentity ?? this.usbIdentity, 
    ); 
  } 
  
  Map<String, dynamic> toJson() => <String, dynamic>{ 
    'themeMode': _themeModeToString(themeMode), 
    'jiggle': jiggle.toJson(), 
    'scheduler': scheduler.toJson(), 
    'simulated': simulated.toJson(), 
    'usbIdentity': usbIdentity.toJson(), 
  }; 

  factory AppSettings.fromJson(Map<String, dynamic> json) { 
    final themeRaw = json['themeMode'] as String?; 
    final jiggleRaw = json['jiggle']; 
    final schedulerRaw = json['scheduler']; 
    final simulatedRaw = json['simulated']; 
    final usbRaw = json['usbIdentity']; 
    
    return AppSettings( 
      themeMode: _themeModeFromString(themeRaw), 
      jiggle: jiggleRaw is Map<String, dynamic> ? JiggleConfig.fromJson(jiggleRaw) : JiggleConfig.defaults(), 
      scheduler: schedulerRaw is Map<String, dynamic> ? ScheduleSettings.fromJson(schedulerRaw) : ScheduleSettings.defaults(), 
      simulated: simulatedRaw is Map<String, dynamic> ? SimulatedCapabilities.fromJson(simulatedRaw) : SimulatedCapabilities.defaults(), 
      usbIdentity: usbRaw is Map<String, dynamic> ? UsbIdentitySettings.fromJson(usbRaw) : UsbIdentitySettings.defaults(), 
    ); 
  } 

  static String _themeModeToString(ThemeMode m) { 
    return switch (m) { 
      ThemeMode.system => 'system', 
      ThemeMode.light => 'light', 
      ThemeMode.dark => 'dark', 
    }; 
  } 

  static ThemeMode _themeModeFromString(String? v) { 
    return switch (v) { 
      'light' => ThemeMode.light, 
      'dark' => ThemeMode.dark, 
      _ => ThemeMode.system, 
    }; 
  } 
}
