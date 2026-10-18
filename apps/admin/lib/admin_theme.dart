import 'package:flutter/material.dart';

class AdminColors {
  static const ink = Color(0xFF24463A);
  static const inkDeep = Color(0xFF19352C);
  static const mintSoft = Color(0xFFDDEFE5);
  static const canvas = Color(0xFFF7F8F4);
  static const border = Color(0xFFE3E8E1);
  static const amber = Color(0xFFF2B866);
  static const coral = Color(0xFFE8846B);
  static const muted = Color(0xFF718078);
}


ThemeData buildAdminTheme() => ThemeData(
          useMaterial3: true,
          fontFamily: 'Vazirmatn',
          colorScheme: ColorScheme.fromSeed(seedColor: AdminColors.ink),
          scaffoldBackgroundColor: AdminColors.canvas,
          appBarTheme: const AppBarTheme(backgroundColor: AdminColors.canvas, surfaceTintColor: Colors.transparent, elevation: 0),
          navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AdminColors.mintSoft),
          cardTheme: const CardThemeData(
            elevation: 0, color: Colors.white, margin: EdgeInsets.zero, surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18)), side: BorderSide(color: AdminColors.border)),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true,
            labelStyle: TextStyle(fontSize: 13, color: AdminColors.muted, fontWeight: FontWeight.w500),
            helperStyle: TextStyle(fontSize: 11, color: AdminColors.muted, height: 1.5),
            errorStyle: TextStyle(fontSize: 11, height: 1.35),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.ink, width: 1.5)),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFFFFFDF8),
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: AdminColors.inkDeep,
            headerForegroundColor: Colors.white,
            weekdayStyle: const TextStyle(color: AdminColors.muted, fontWeight: FontWeight.w800),
            dayStyle: const TextStyle(fontWeight: FontWeight.w600),
            yearStyle: const TextStyle(fontWeight: FontWeight.w700),
            todayForegroundColor: WidgetStatePropertyAll(AdminColors.ink),
            todayBorder: const BorderSide(color: AdminColors.ink, width: 1),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? Colors.white : AdminColors.inkDeep),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? AdminColors.ink : null),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AdminColors.border),
            ),
            elevation: 10,
            shadowColor: AdminColors.ink.withValues(alpha: 0.16),
          ),
        );
