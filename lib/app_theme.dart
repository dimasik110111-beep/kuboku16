import 'package:flutter/material.dart';
import 'ui_kit.dart';

ThemeData juniorTheme(bool light) {
  CupUi.light = light;
  final brightness = light ? Brightness.light : Brightness.dark;
  final text = ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: 'Manrope', bodyColor: CupUi.white, displayColor: CupUi.white);
  final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: CupUi.stroke));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: CupUi.background,
    colorScheme: ColorScheme.fromSeed(
            seedColor: CupUi.red, brightness: brightness)
        .copyWith(
            primary: light ? CupUi.red : const Color(0xFF77D6BC),
            onPrimary: light ? Colors.white : CupUi.navy,
            secondary: CupUi.teal,
            surface: CupUi.surface,
            onSurface: CupUi.white,
            error: light ? const Color(0xFFB13D3D) : const Color(0xFFFFA69E)),
    textTheme: text.copyWith(
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        titleLarge: text.titleLarge?.copyWith(
            fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.7),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    appBarTheme: AppBarTheme(
        backgroundColor: CupUi.surface,
        foregroundColor: CupUi.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
            fontFamily: 'Manrope',
            color: CupUi.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5)),
    dividerColor: CupUi.stroke,
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CupUi.surface,
        hintStyle: TextStyle(color: CupUi.muted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: CupUi.red, width: 1.5))),
    cardTheme: CardThemeData(
        color: CupUi.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: CupUi.stroke))),
    dialogTheme: DialogThemeData(
        backgroundColor: CupUi.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            fontFamily: 'Manrope',
            color: CupUi.white,
            fontSize: 22,
            fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(
            fontFamily: 'Manrope',
            color: CupUi.soft,
            fontSize: 14,
            height: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: CupUi.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: CupUi.surface,
        showDragHandle: true,
        dragHandleColor: CupUi.stroke,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: light ? CupUi.navy : CupUi.raised,
        contentTextStyle: const TextStyle(
            fontFamily: 'Manrope', color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: CupUi.red,
        linearTrackColor: CupUi.raised,
        circularTrackColor: CupUi.raised),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    tabBarTheme: TabBarThemeData(
        labelColor: light ? CupUi.red : CupUi.signal,
        unselectedLabelColor: CupUi.muted,
        indicatorColor: CupUi.red,
        dividerColor: CupUi.stroke,
        labelStyle: const TextStyle(
            fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(44, 48),
            backgroundColor: CupUi.red,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w800),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: light ? CupUi.red : CupUi.signal,
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 48),
            foregroundColor: CupUi.white,
            side: BorderSide(color: CupUi.stroke),
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            minimumSize: const Size(44, 44), foregroundColor: CupUi.soft)),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CupUi.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: CupUi.redMuted,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? CupUi.white
                : CupUi.muted))),
  );
}
