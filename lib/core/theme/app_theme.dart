import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';

class AppTheme {
  static ThemeData light({ColorScheme? dynamicScheme}) {
    final base = dynamicScheme != null
        ? ThemeData(useMaterial3: true, colorScheme: dynamicScheme)
        : ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E6AF2)),
          );

    final cs = base.colorScheme;
    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      // Flutter 3.24+ uses CardThemeData for ThemeData.cardTheme.
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        // side is provided via shape below for reliable borders across dynamic palettes
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusLg)),
          side: BorderSide(color: Color(0x00000000)),
        ),
        surfaceTintColor: Colors.transparent,
      ).copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppTokens.radiusLg)),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.primary, width: 2)),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant.withOpacity(0.5), thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      ),
      appBarTheme: base.appBarTheme.copyWith(surfaceTintColor: Colors.transparent),
    );
  }

  static ThemeData dark({ColorScheme? dynamicScheme}) {
    final base = dynamicScheme != null
        ? ThemeData(useMaterial3: true, colorScheme: dynamicScheme)
        : ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4E6AF2),
              brightness: Brightness.dark,
            ),
          );

    final cs = base.colorScheme;
    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      // Flutter 3.24+ uses CardThemeData for ThemeData.cardTheme.
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusLg)),
          side: BorderSide(color: Color(0x00000000)),
        ),
        surfaceTintColor: Colors.transparent,
      ).copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppTokens.radiusLg)),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: cs.primary, width: 2)),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant.withOpacity(0.5), thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      ),
      appBarTheme: base.appBarTheme.copyWith(surfaceTintColor: Colors.transparent),
    );
  }
}
