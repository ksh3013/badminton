import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFFEFF7F1);
  static const muted = Color(0xFF91A199);
  static const dim = Color(0xFF65736B);
  static const background = Color(0xFF0E1110);
  static const panel = Color(0xFF171D1A);
  static const panelRaised = Color(0xFF1C2520);
  static const line = Color(0xFF2B3730);
  static const green = Color(0xFF0B8F5B);
  static const greenBright = Color(0xFF19B874);
  static const lime = Color(0xFFC7F36B);
  static const red = Color(0xFFD64545);
  static const orange = Color(0xFFD98A13);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'Pretendard',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111613),
      border: _inputBorder(AppColors.line),
      enabledBorder: _inputBorder(AppColors.line),
      focusedBorder: _inputBorder(AppColors.greenBright),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: color),
);
