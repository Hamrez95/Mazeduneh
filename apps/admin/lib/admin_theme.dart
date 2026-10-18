import 'package:flutter/material.dart';

/// Semantic dark tokens shared by every admin screen. Keep future light palette
/// definitions here, rather than introducing page-specific colors.
class AdminColors {
  static const canvas = Color(0xFF25293C);
  static const surface = Color(0xFF2F3349);
  static const surfaceRaised = Color(0xFF363B54);
  static const border = Color(0xFF44485E);
  static const primary = Color(0xFF7367F0);
  static const primaryLight = Color(0xFFA89FFF);
  static const primarySoft = Color(0xFF3D3A64);
  static const text = Color(0xFFACABC1);
  static const heading = Color(0xFFCFCDE4);
  static const muted = Color(0xFFACABC1);
  static const subtle = Color(0xFF9998AF);
  static const success = Color(0xFF28C76F);
  static const successSoft = Color(0xFF2C4943);
  static const amber = Color(0xFFFF9F43);
  static const warningSoft = Color(0xFF51433D);
  static const coral = Color(0xFFEA5455);
  static const dangerSoft = Color(0xFF513B48);
  static const info = Color(0xFF00CFE8);
  static const infoSoft = Color(0xFF244957);
  // Compatibility names for existing domain components.
  static const ink = primaryLight;
  static const inkDeep = heading;
  static const mintSoft = primarySoft;
}

ThemeData buildAdminTheme() {
  const scheme = ColorScheme.dark(
    primary: AdminColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AdminColors.primarySoft,
    onPrimaryContainer: AdminColors.primaryLight,
    secondary: AdminColors.info,
    secondaryContainer: AdminColors.primarySoft,
    onSecondaryContainer: AdminColors.primaryLight,
    onSecondary: AdminColors.canvas,
    surface: AdminColors.surface,
    onSurface: AdminColors.text,
    onSurfaceVariant: AdminColors.muted,
    outline: AdminColors.border,
    error: AdminColors.coral,
    onError: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Vazirmatn',
  );
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );
  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
    borderSide: BorderSide(color: AdminColors.border),
  );
  final buttonStyle = ButtonStyle(
    shape: const WidgetStatePropertyAll(shape),
    minimumSize: const WidgetStatePropertyAll(Size(40, 38)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AdminColors.canvas,
    canvasColor: AdminColors.surface,
    dividerColor: AdminColors.border,
    dividerTheme: const DividerThemeData(
      color: AdminColors.border,
      thickness: 0.7,
    ),
    disabledColor: AdminColors.subtle,
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          headlineSmall: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: const TextStyle(fontSize: 15, height: 1.6),
          bodyMedium: const TextStyle(fontSize: 13, height: 1.6),
          bodySmall: const TextStyle(fontSize: 11, height: 1.5),
        )
        .apply(
          fontFamily: 'Vazirmatn',
          bodyColor: AdminColors.text,
          displayColor: AdminColors.heading,
        ),
    iconTheme: const IconThemeData(color: AdminColors.text, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.heading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AdminColors.surface,
      margin: EdgeInsets.zero,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AdminColors.surface,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AdminColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surface,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(color: AdminColors.text, fontSize: 13),
      hintStyle: TextStyle(color: AdminColors.subtle, fontSize: 13),
      helperStyle: TextStyle(
        color: AdminColors.muted,
        fontSize: 11,
        height: 1.5,
      ),
      errorStyle: TextStyle(color: AdminColors.coral, fontSize: 11),
      prefixIconColor: AdminColors.muted,
      suffixIconColor: AdminColors.muted,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AdminColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AdminColors.coral),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: const WidgetStatePropertyAll(AdminColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle.copyWith(
        foregroundColor: const WidgetStatePropertyAll(AdminColors.primaryLight),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AdminColors.border),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle.copyWith(
        foregroundColor: const WidgetStatePropertyAll(AdminColors.primaryLight),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AdminColors.primary,
      foregroundColor: Colors.white,
      shape: shape,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AdminColors.surfaceRaised,
      selectedColor: AdminColors.primarySoft,
      side: BorderSide.none,
      shape: shape,
      labelStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        color: AdminColors.text,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AdminColors.text,
      iconColor: AdminColors.muted,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AdminColors.surface),
      headingTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        color: AdminColors.heading,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        color: AdminColors.text,
        fontSize: 13,
      ),
      dividerThickness: 0.7,
      headingRowHeight: 48,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 84,
      horizontalMargin: 20,
      columnSpacing: 24,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AdminColors.surface,
      indicatorColor: AdminColors.primarySoft,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AdminColors.primaryLight,
      unselectedLabelColor: AdminColors.muted,
      indicatorColor: AdminColors.primary,
      dividerColor: AdminColors.border,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AdminColors.surfaceRaised,
      contentTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        color: AdminColors.heading,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        AdminColors.subtle.withValues(alpha: 0.5),
      ),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(5),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AdminColors.surfaceRaised,
      headerForegroundColor: AdminColors.heading,
      weekdayStyle: const TextStyle(
        color: AdminColors.muted,
        fontWeight: FontWeight.w500,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AdminColors.subtle
            : states.contains(WidgetState.selected)
            ? Colors.white
            : AdminColors.heading,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AdminColors.primary : null,
      ),
      todayForegroundColor: const WidgetStatePropertyAll(
        AdminColors.primaryLight,
      ),
      todayBorder: const BorderSide(color: AdminColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
