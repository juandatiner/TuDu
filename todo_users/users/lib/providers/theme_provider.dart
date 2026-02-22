import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;
  bool _isInitialized = true; // Siempre inicializado en modo claro
  String? _userEmail;

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
    // Siempre iniciar en modo claro (para pantallas pre-Home)
    _isDarkMode = false;
    _isInitialized = true;
  }

  /// Inicializa el tema con el email del usuario para sincronizar con el backend
  /// Solo se debe llamar después del login (en HomeScreen)
  Future<void> initializeWithUser(String email) async {
    _userEmail = email;
    await _loadThemeFromBackend();
  }

  /// Limpia el email del usuario (para logout)
  /// Resetea a modo claro para las pantallas pre-Home
  void clearUser() {
    _userEmail = null;
    _isDarkMode = false;
    notifyListeners();
  }

  /// Carga el tema desde el backend si hay un usuario logueado
  Future<void> _loadThemeFromBackend() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      _isDarkMode = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '${Config.baseUrl}/users/theme/${Uri.encodeComponent(_userEmail!)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isDarkMode = data['dark_mode'] ?? false;

        // También guardar localmente como caché
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_themeKey, _isDarkMode);
        } catch (e) {
          // Ignorar errores de persistencia local
        }
      }
    } catch (e) {
      // Si hay error, intentar cargar desde caché local
      try {
        final prefs = await SharedPreferences.getInstance();
        _isDarkMode = prefs.getBool(_themeKey) ?? false;
      } catch (e2) {
        _isDarkMode = false;
      }
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;

    // Guardar localmente
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      // Ignorar errores de persistencia local
    }

    // Guardar en el backend si hay usuario
    await _saveThemeToBackend();

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;

    // Guardar localmente
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      // Ignorar errores de persistencia local
    }

    // Guardar en el backend si hay usuario
    await _saveThemeToBackend();

    notifyListeners();
  }

  /// Guarda el tema en el backend
  Future<void> _saveThemeToBackend() async {
    if (_userEmail == null || _userEmail!.isEmpty) return;

    try {
      await http.put(
        Uri.parse('${Config.baseUrl}/users/theme'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _userEmail,
          'dark_mode': _isDarkMode,
        }),
      );
    } catch (e) {
      // Ignorar errores de red - el tema se guardó localmente
      print('Error guardando tema en backend: $e');
    }
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
