import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  // Colores para modo claro
  static const Color lightScaffoldBg = Color(0xFFF4F2F2);
  static const Color lightCardBg = Colors.white;
  static const Color lightText = Colors.black;
  static const Color lightSecondaryText = Color(0xFF666666);

  // Colores para modo oscuro - Gris elegante
  static const Color darkScaffoldBg = Color(0xFF1C1C1E);
  static const Color darkCardBg = Color(0xFF2C2C2E);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkSecondaryText = Color(0xFFABABAB);
  static const Color darkBorder = Color(0xFF3A3A3C);

  // Color primario (se mantiene en ambos modos)
  static const Color primaryColor = Color(0xFF78BF32);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
    } catch (e) {
      // Si hay error, usar valor por defecto (modo claro)
      _isDarkMode = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      // Ignorar errores de persistencia
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      // Ignorar errores de persistencia
    }
    notifyListeners();
  }

  ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: lightScaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      cardColor: lightCardBg,
      dividerColor: Colors.grey.withOpacity(0.2),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffoldBg,
        foregroundColor: lightText,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: lightCardBg,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: darkScaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      cardColor: darkCardBg,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffoldBg,
        foregroundColor: darkText,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCardBg,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: darkCardBg,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // Métodos auxiliares para obtener colores según el tema actual
  Color get scaffoldBgColor => _isDarkMode ? darkScaffoldBg : lightScaffoldBg;
  Color get cardBgColor => _isDarkMode ? darkCardBg : lightCardBg;
  Color get textColor => _isDarkMode ? darkText : lightText;
  Color get secondaryTextColor =>
      _isDarkMode ? darkSecondaryText : lightSecondaryText;
  Color get borderColor =>
      _isDarkMode ? darkBorder : Colors.grey.withOpacity(0.3);
  Color get shadowColor => _isDarkMode
      ? Colors.black.withOpacity(0.3)
      : Colors.grey.withOpacity(0.2);
}
