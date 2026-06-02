import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import '../core/routing/app_router.dart'; 
import '../core/theme/app_theme.dart'; 
import '../state/app_settings_controller.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../state/dynamic_color_controller.dart'; 

class AppRoot extends ConsumerWidget { 
  const AppRoot({super.key}); 

  @override 
  Widget build(BuildContext context, WidgetRef ref) { 
    final settingsAsync = ref.watch(appSettingsControllerProvider); 
    final themeMode = settingsAsync.asData?.value.themeMode ?? ThemeMode.system; 
    final router = ref.watch(appRouterProvider); 

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final enabled = ref.watch(dynamicColorsControllerProvider);
        return MaterialApp.router(
          debugShowCheckedModeBanner: kDebugMode,
          title: 'HIDWiggle',
          theme: AppTheme.light(dynamicScheme: enabled ? lightDynamic : null),
          darkTheme: AppTheme.dark(dynamicScheme: enabled ? darkDynamic : null),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    ); 
  }
}
