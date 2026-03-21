import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

/// Provider para manejar el idioma de la aplicación
/// Soporta español (es) e inglés (en)
/// Sincroniza con el backend para persistir la preferencia del usuario
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('es', 'CO');
  String? _userEmail;
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  bool get isSpanish => _locale.languageCode == 'es';
  bool get isEnglish => _locale.languageCode == 'en';

  /// Inicializa el idioma desde SharedPreferences (para uso antes del login)
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);

    if (languageCode != null) {
      _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Inicializa el idioma con el email del usuario para sincronizar con el backend
  /// Solo se debe llamar después del login (en HomeScreen)
  Future<void> initializeWithUser(String email) async {
    _userEmail = email;
    await _loadLanguageFromBackend();
  }

  /// Limpia el email del usuario (para logout)
  void clearUser() {
    _userEmail = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Carga el idioma desde el backend si hay un usuario logueado
  Future<void> _loadLanguageFromBackend() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      await loadLanguage();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '${Config.baseUrl}/users/language/${Uri.encodeComponent(_userEmail!)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final languageCode = data['language'] ?? 'es';
        _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');

        // También guardar localmente como caché
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_languageKey, languageCode);
        } catch (e) {
          // Ignorar errores de persistencia local
        }
      }
    } catch (e) {
      // Si hay error, intentar cargar desde caché local
      try {
        final prefs = await SharedPreferences.getInstance();
        final languageCode = prefs.getString(_languageKey);
        if (languageCode != null) {
          _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');
        }
      } catch (e2) {
        // Mantener el idioma por defecto
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Cambia el idioma de la aplicación
  Future<void> setLanguage(String languageCode) async {
    _locale = Locale(languageCode, languageCode == 'es' ? 'CO' : 'US');

    // Guardar localmente
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      // Ignorar errores de persistencia local
    }

    // Guardar en el backend si hay usuario
    await _saveLanguageToBackend();

    notifyListeners();
  }

  /// Guarda el idioma en el backend
  Future<void> _saveLanguageToBackend() async {
    if (_userEmail == null || _userEmail!.isEmpty) return;

    try {
      await http.put(
        Uri.parse('${Config.baseUrl}/users/language'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _userEmail,
          'language': _locale.languageCode,
        }),
      );
    } catch (e) {
      // Ignorar errores de red - el idioma se guardó localmente
      debugPrint('Error guardando idioma en backend: $e');
    }
  }

  /// Alterna entre español e inglés
  Future<void> toggleLanguage() async {
    if (isSpanish) {
      await setLanguage('en');
    } else {
      await setLanguage('es');
    }
  }

  /// Lista de idiomas soportados
  static const List<Locale> supportedLocales = [
    Locale('es', 'CO'),
    Locale('en', 'US'),
  ];

  /// Nombres de los idiomas para mostrar en la UI
  static const Map<String, String> languageNames = {
    'es': 'Español',
    'en': 'English',
  };

  /// Nombres nativos de los idiomas
  static const Map<String, String> nativeLanguageNames = {
    'es': 'Español (Colombia)',
    'en': 'English (US)',
  };
}
